import Foundation
import SwiftData

// MARK: - Errors

/// Errors that can occur during session operations
enum SessionError: LocalizedError {
    case sessionAlreadyActive
    case sessionNotFound
    case sessionNotActive
    case invalidReadinessValue(Int)
    case invalidRPEValue(Int)
    case invalidPumpLevelValue(Int)
    case endTimeBeforeStartTime

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Cannot start a new session while one is active"
        case .sessionNotFound:
            return "Session not found"
        case .sessionNotActive:
            return "Session is not active"
        case .invalidReadinessValue(let value):
            return "Readiness must be between 1 and 5, got \(value)"
        case .invalidRPEValue(let value):
            return "RPE must be between 1 and 10, got \(value)"
        case .invalidPumpLevelValue(let value):
            return "Pump level must be between 1 and 5, got \(value)"
        case .endTimeBeforeStartTime:
            return "End time must be after start time"
        }
    }
}

// MARK: - Protocol

/// Session lifecycle management protocol
///
/// Defines operations for creating, ending, and managing climbing sessions.
/// All implementations must be Sendable for safe concurrent access.
///
/// ## Usage
///
/// ```swift
/// let sessionService = SessionService(modelContainer: container)
/// let sessionId = try await sessionService.createSession(
///     userId: currentUserId,
///     mentalReadiness: 4,
///     physicalReadiness: 5
/// )
/// ```
protocol SessionServiceProtocol: Sendable {
    /// Create a new climbing session
    ///
    /// Creates a session in local SwiftData storage with optional readiness metrics.
    /// The session is immediately active (no `endedAt` timestamp).
    ///
    /// - Parameters:
    ///   - userId: The ID of the user starting the session
    ///   - mentalReadiness: Optional mental readiness score (1-5 scale)
    ///   - physicalReadiness: Optional physical readiness score (1-5 scale)
    ///
    /// - Returns: The UUID of the newly created session
    ///
    /// - Throws:
    ///   - `SessionError.sessionAlreadyActive` if user already has an active session
    ///   - `SessionError.invalidReadinessValue` if readiness is outside 1-5 range
    ///
    /// - Note: Only one session can be active per user at a time
    func createSession(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID

    /// End an active session with feedback
    ///
    /// Sets the `endedAt` timestamp and captures post-session metrics.
    /// All metrics are optional and validated before persistence.
    ///
    /// - Parameters:
    ///   - sessionId: The UUID of the session to end
    ///   - rpe: Optional Rate of Perceived Exertion (1-10 scale)
    ///   - pumpLevel: Optional pump level (1-5 scale)
    ///   - notes: Optional free-form text notes
    ///
    /// - Throws:
    ///   - `SessionError.sessionNotFound` if session ID is invalid
    ///   - `SessionError.sessionNotActive` if session already ended
    ///   - `SessionError.invalidRPEValue` if RPE is outside 1-10 range
    ///   - `SessionError.invalidPumpLevelValue` if pump level is outside 1-5 range
    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws

    /// Get the active session ID for a user (if any)
    ///
    /// Returns the session ID if the user has an active session, or nil otherwise.
    /// Active means `endedAt == nil` and `deletedAt == nil`.
    ///
    /// - Parameter userId: The user ID to query
    /// - Returns: The active session UUID, or nil if no active session exists
    func getActiveSessionId(userId: UUID) async throws -> UUID?

    /// Get session history with pagination
    ///
    /// Returns completed sessions (where `endedAt != nil`) for a user,
    /// sorted by end date in descending order (newest first).
    ///
    /// - Parameters:
    ///   - userId: The user ID to query
    ///   - limit: Maximum number of sessions to return
    ///   - offset: Number of sessions to skip (for pagination)
    ///
    /// - Returns: Array of session UUIDs, ordered by end date (newest first)
    func getSessionHistory(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [UUID]

    /// Soft delete a session
    ///
    /// Sets the `deletedAt` timestamp instead of physically removing the record.
    /// This allows sync to propagate the delete to Supabase.
    ///
    /// - Parameter sessionId: The UUID of the session to delete
    ///
    /// - Throws: `SessionError.sessionNotFound` if session ID is invalid
    ///
    /// - Note: Deleted sessions are filtered out of all queries via predicates
    func deleteSession(sessionId: UUID) async throws

    /// Update session notes (can be done during active session)
    ///
    /// Allows updating notes on both active and completed sessions.
    /// Sets `needsSync = true` to queue for background sync.
    ///
    /// - Parameters:
    ///   - sessionId: The UUID of the session to update
    ///   - notes: The new notes text, or nil to clear notes
    ///
    /// - Throws: `SessionError.sessionNotFound` if session ID is invalid
    func updateSessionNotes(sessionId: UUID, notes: String?) async throws
}

// MARK: - Implementation

/// Actor-based implementation of SessionServiceProtocol providing thread-safe session operations
///
/// `SessionService` uses Swift actors to ensure thread-safe access to SwiftData.
/// All database operations are performed on the main actor using `MainActor.run`.
///
/// ## Concurrency Model
///
/// - Actor isolation prevents concurrent access to shared state
/// - `@MainActor` used for ModelContext access (required by SwiftData)
/// - All methods are async and properly isolated
///
/// ## Validation Strategy
///
/// All input values are validated before persistence:
/// - Readiness: 1-5 or nil
/// - RPE: 1-10 or nil
/// - Pump level: 1-5 or nil
///
/// ## Sync Strategy
///
/// All mutations set `needsSync = true` on affected entities.
/// The SyncActor polls for changes and syncs to Supabase in the background.
///
/// ## Example
///
/// ```swift
/// let service = SessionService(modelContainer: container)
///
/// // Create session
/// let sessionId = try await service.createSession(
///     userId: myUserId,
///     mentalReadiness: 4,
///     physicalReadiness: 5
/// )
///
/// // End session later
/// try await service.endSession(
///     sessionId: sessionId,
///     rpe: 7,
///     pumpLevel: 3,
///     notes: "Great endurance day!"
/// )
/// ```
actor SessionService: SessionServiceProtocol {
    private let modelContainer: ModelContainer

    /// Creates a new SessionService with the given ModelContainer
    ///
    /// - Parameter modelContainer: The SwiftData container for persistence
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Provides access to the main ModelContext for SwiftData operations
    ///
    /// SwiftData requires ModelContext operations to run on the main actor.
    /// This computed property provides safe access to the container's main context.
    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func createSession(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID {
        // Validate readiness values
        if let mental = mentalReadiness, !(1...5).contains(mental) {
            throw SessionError.invalidReadinessValue(mental)
        }
        if let physical = physicalReadiness, !(1...5).contains(physical) {
            throw SessionError.invalidReadinessValue(physical)
        }

        return try await MainActor.run {
            // Check for existing active session
            let predicate = #Predicate<SCSession> { session in
                session.userId == userId &&
                session.endedAt == nil &&
                session.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

            if let _ = try modelContext.fetch(descriptor).first {
                throw SessionError.sessionAlreadyActive
            }

            // Create new session
            let session = SCSession(
                userId: userId,
                discipline: discipline,
                startedAt: Date(),
                mentalReadiness: mentalReadiness,
                physicalReadiness: physicalReadiness,
                needsSync: true
            )

            modelContext.insert(session)
            try modelContext.save()

            return session.id
        }
    }

    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // Validate values
        if let rpe = rpe, !(1...10).contains(rpe) {
            throw SessionError.invalidRPEValue(rpe)
        }
        if let pump = pumpLevel, !(1...5).contains(pump) {
            throw SessionError.invalidPumpLevelValue(pump)
        }

        try await MainActor.run {
            // Fetch session
            let predicate = #Predicate<SCSession> { $0.id == sessionId }
            let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

            guard let session = try modelContext.fetch(descriptor).first else {
                throw SessionError.sessionNotFound
            }

            guard session.endedAt == nil else {
                throw SessionError.sessionNotActive
            }

            // Update session
            let now = Date()
            session.endedAt = now
            session.rpe = rpe
            session.pumpLevel = pumpLevel
            session.notes = notes
            session.updatedAt = now
            session.needsSync = true

            try modelContext.save()
        }
    }

    func getActiveSessionId(userId: UUID) async throws -> UUID? {
        await MainActor.run {
            let predicate = #Predicate<SCSession> { session in
                session.userId == userId &&
                session.endedAt == nil &&
                session.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

            return try? modelContext.fetch(descriptor).first?.id
        }
    }

    func getSessionHistory(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [UUID] {
        try await MainActor.run {
            let predicate = #Predicate<SCSession> { session in
                session.userId == userId &&
                session.endedAt != nil &&
                session.deletedAt == nil
            }

            var descriptor = FetchDescriptor<SCSession>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            descriptor.fetchOffset = offset

            let sessions = try modelContext.fetch(descriptor)
            return sessions.map { $0.id }
        }
    }

    func deleteSession(sessionId: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCSession> { $0.id == sessionId }
            let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

            guard let session = try modelContext.fetch(descriptor).first else {
                throw SessionError.sessionNotFound
            }

            // Soft delete
            let now = Date()
            session.deletedAt = now
            session.updatedAt = now
            session.needsSync = true

            try modelContext.save()
        }
    }

    func updateSessionNotes(sessionId: UUID, notes: String?) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCSession> { $0.id == sessionId }
            let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

            guard let session = try modelContext.fetch(descriptor).first else {
                throw SessionError.sessionNotFound
            }

            session.notes = notes
            session.updatedAt = Date()
            session.needsSync = true

            try modelContext.save()
        }
    }
}
