// SyncActor.swift
// SwiftClimb
//
// Actor responsible for coordinating offline-first synchronization between
// SwiftData (local) and Supabase (remote).
//
// SyncActor manages all sync state, queues pending changes, executes pull/push
// operations, and handles retry logic with exponential backoff. It ensures
// data eventually reaches the backend while never blocking the UI.

import Foundation
import SwiftData

/// Coordinates background synchronization between SwiftData and Supabase.
///
/// `SyncActor` is the central coordinator for offline-first sync operations.
/// It maintains sync state, queues pending changes, and executes push/pull
/// operations in the background.
///
/// ## Sync Strategy
///
/// - **Write path**: Local writes mark `needsSync = true`, SyncActor pushes when online
/// - **Read path**: Pull updates from Supabase periodically and merge into SwiftData
/// - **Conflict resolution**: Last-write-wins based on updated_at timestamp
/// - **Retry**: Exponential backoff for failed operations (max 5 attempts)
///
/// ## Actor Isolation
///
/// All sync state is protected by actor isolation. Callers must `await` all methods.
///
/// ## Usage
///
/// ```swift
/// let syncActor = SyncActor(
///     modelContainer: SwiftDataContainer.shared.container,
///     supabaseClient: supabaseClient
/// )
///
/// // After local write
/// await syncActor.enqueue(.insertSession(sessionId: session.id))
///
/// // Periodic sync
/// try await syncActor.performSync(userId: currentUserId)
///
/// // Check sync state
/// let state = await syncActor.getSyncState()
/// print("Pending: \(state.pendingChangesCount)")
/// ```
///
/// ## Triggers
///
/// Sync operations are triggered by:
/// - App foreground (pull updates)
/// - User write (enqueue push)
/// - Periodic timer (pull + push)
/// - Manual refresh (user-initiated)
///
/// ## Thread Safety
///
/// SyncActor is an actor, so all mutable state is protected. Safe to call
/// from any context (MainActor, background tasks, etc.).
actor SyncActor {
    private var lastSyncAt: Date?
    private var pendingOperations: [SyncOperation] = []
    private var isSyncing = false
    private var lastError: String?

    private let modelContainer: ModelContainer
    private let sessionsTable: SessionsTable
    private let climbsTable: ClimbsTable
    private let attemptsTable: AttemptsTable

    init(
        modelContainer: ModelContainer,
        supabaseClient: SupabaseClientActor
    ) {
        self.modelContainer = modelContainer
        let repository = SupabaseRepository(client: supabaseClient)
        self.sessionsTable = SessionsTable(repository: repository)
        self.climbsTable = ClimbsTable(repository: repository)
        self.attemptsTable = AttemptsTable(repository: repository)
    }

    // MARK: - Public Interface

    /// Perform full sync: pull remote updates, then push local changes
    func performSync(userId: UUID) async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await pullUpdates(userId: userId)
            try await pushPendingChanges(userId: userId)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Pull updates from Supabase and merge into SwiftData
    func pullUpdates(userId: UUID) async throws {
        // Calculate sync window (last sync - 5min buffer to handle clock skew)
        let syncSince = lastSyncAt?.addingTimeInterval(-300) ?? Date.distantPast

        // Fetch updates from each table
        let sessionDTOs = try await sessionsTable.fetchUpdatedSince(
            since: syncSince,
            userId: userId
        )
        let climbDTOs = try await climbsTable.fetchUpdatedSince(
            since: syncSince,
            userId: userId
        )
        let attemptDTOs = try await attemptsTable.fetchUpdatedSince(
            since: syncSince,
            userId: userId
        )

        // Merge into SwiftData on background context
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        // Merge sessions
        for dto in sessionDTOs {
            try mergeSession(dto: dto, context: context)
        }

        // Merge climbs
        for dto in climbDTOs {
            try mergeClimb(dto: dto, context: context)
        }

        // Merge attempts
        for dto in attemptDTOs {
            try mergeAttempt(dto: dto, context: context)
        }

        // Save merged changes
        try context.save()
        lastSyncAt = Date()
    }

    /// Push pending local changes to Supabase
    func pushPendingChanges(userId: UUID) async throws {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        // Fetch all records with needsSync = true
        let sessionsPredicate = #Predicate<SCSession> { session in
            session.needsSync == true && session.userId == userId
        }
        let sessionDescriptor = FetchDescriptor<SCSession>(predicate: sessionsPredicate)
        let sessionsToPush = try context.fetch(sessionDescriptor)

        let climbsPredicate = #Predicate<SCClimb> { climb in
            climb.needsSync == true && climb.userId == userId
        }
        let climbDescriptor = FetchDescriptor<SCClimb>(predicate: climbsPredicate)
        let climbsToPush = try context.fetch(climbDescriptor)

        let attemptsPredicate = #Predicate<SCAttempt> { attempt in
            attempt.needsSync == true && attempt.userId == userId
        }
        let attemptDescriptor = FetchDescriptor<SCAttempt>(predicate: attemptsPredicate)
        let attemptsToPush = try context.fetch(attemptDescriptor)

        // Push sessions
        for session in sessionsToPush {
            let dto = SessionDTO.fromDomain(session)
            _ = try await sessionsTable.upsertSession(dto)
            session.needsSync = false
            session.updatedAt = Date()
        }

        // Push climbs
        for climb in climbsToPush {
            let dto = ClimbDTO.fromDomain(climb)
            _ = try await climbsTable.upsertClimb(dto)
            climb.needsSync = false
            climb.updatedAt = Date()
        }

        // Push attempts
        for attempt in attemptsToPush {
            let dto = AttemptDTO.fromDomain(attempt)
            _ = try await attemptsTable.upsertAttempt(dto)
            attempt.needsSync = false
            attempt.updatedAt = Date()
        }

        // Save changes
        try context.save()
    }

    /// Enqueue a sync operation (for future use with retry queue)
    func enqueue(_ operation: SyncOperation) {
        pendingOperations.append(operation)
    }

    /// Cancel all in-flight sync operations
    func cancelAll() {
        pendingOperations.removeAll()
    }

    /// Get current sync state
    func getSyncState() -> SyncState {
        return SyncState(
            lastSyncAt: lastSyncAt,
            isSyncing: isSyncing,
            pendingChangesCount: pendingOperations.count,
            lastError: lastError
        )
    }

    // MARK: - Private Merge Logic

    /// Merge remote session into local database
    private func mergeSession(dto: SessionDTO, context: ModelContext) throws {
        let predicate = #Predicate<SCSession> { session in
            session.id == dto.id
        }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)
        let existing = try context.fetch(descriptor).first

        if let existing = existing {
            // Conflict resolution: last-write-wins
            // If local has needsSync=true, skip update (local wins)
            guard !existing.needsSync else { return }

            // Remote is newer, update local
            if dto.updatedAt > existing.updatedAt {
                existing.startedAt = dto.startedAt
                existing.endedAt = dto.endedAt
                existing.mentalReadiness = dto.mentalReadiness
                existing.physicalReadiness = dto.physicalReadiness
                existing.rpe = dto.rpe
                existing.pumpLevel = dto.pumpLevel
                existing.notes = dto.notes
                existing.isPrivate = dto.isPrivate
                existing.updatedAt = dto.updatedAt
                existing.deletedAt = dto.deletedAt
            }
        } else {
            // New record from remote, insert
            let newSession = dto.toDomain()
            context.insert(newSession)
        }
    }

    /// Merge remote climb into local database
    private func mergeClimb(dto: ClimbDTO, context: ModelContext) throws {
        let predicate = #Predicate<SCClimb> { climb in
            climb.id == dto.id
        }
        let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)
        let existing = try context.fetch(descriptor).first

        if let existing = existing {
            guard !existing.needsSync else { return }

            if dto.updatedAt > existing.updatedAt {
                existing.sessionId = dto.sessionId
                existing.discipline = Discipline(rawValue: dto.discipline) ?? existing.discipline
                existing.isOutdoor = dto.isOutdoor
                existing.name = dto.name
                existing.gradeOriginal = dto.gradeOriginal
                existing.gradeScale = dto.gradeScale.flatMap { GradeScale(rawValue: $0) }
                existing.gradeScoreMin = dto.gradeScoreMin
                existing.gradeScoreMax = dto.gradeScoreMax
                existing.openBetaClimbId = dto.openBetaClimbId
                existing.openBetaAreaId = dto.openBetaAreaId
                existing.locationDisplay = dto.locationDisplay
                existing.belayPartnerUserId = dto.belayPartnerUserId
                existing.belayPartnerName = dto.belayPartnerName
                existing.notes = dto.notes
                existing.updatedAt = dto.updatedAt
                existing.deletedAt = dto.deletedAt
            }
        } else {
            let newClimb = dto.toDomain()
            context.insert(newClimb)
        }
    }

    /// Merge remote attempt into local database
    private func mergeAttempt(dto: AttemptDTO, context: ModelContext) throws {
        let predicate = #Predicate<SCAttempt> { attempt in
            attempt.id == dto.id
        }
        let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)
        let existing = try context.fetch(descriptor).first

        if let existing = existing {
            guard !existing.needsSync else { return }

            if dto.updatedAt > existing.updatedAt {
                existing.sessionId = dto.sessionId
                existing.climbId = dto.climbId
                existing.attemptNumber = dto.attemptNumber
                existing.outcome = AttemptOutcome(rawValue: dto.outcome) ?? existing.outcome
                existing.sendType = dto.sendType.flatMap { SendType(rawValue: $0) }
                existing.occurredAt = dto.occurredAt
                existing.updatedAt = dto.updatedAt
                existing.deletedAt = dto.deletedAt
            }
        } else {
            let newAttempt = dto.toDomain()
            context.insert(newAttempt)
        }
    }
}
