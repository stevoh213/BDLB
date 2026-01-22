import Foundation
import SwiftData

// MARK: - Errors

enum ClimbError: LocalizedError {
    case sessionNotFound
    case sessionNotActive
    case climbNotFound
    case invalidGrade(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .sessionNotActive:
            return "Cannot add climb to ended session"
        case .climbNotFound:
            return "Climb not found"
        case .invalidGrade(let grade):
            return "Invalid grade: \(grade)"
        }
    }
}

// MARK: - Protocol

/// Counts of climbs and attempts for a session (used for Live Activity updates)
struct SessionCounts: Sendable {
    let climbCount: Int
    let attemptCount: Int
}

protocol ClimbServiceProtocol: Sendable {
    /// Create a new climb in a session
    /// Returns the UUID of the created climb
    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?,
        notes: String?
    ) async throws -> UUID

    /// Update climb properties
    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws

    /// Soft delete a climb
    func deleteClimb(climbId: UUID) async throws

    /// Get current climb and attempt counts for a session
    func getSessionCounts(sessionId: UUID) async throws -> SessionCounts
}

struct ClimbUpdates: Sendable {
    var name: String?
    var grade: Grade?
    var notes: String?
    var belayPartnerName: String?
    var locationDisplay: String?

    init(
        name: String? = nil,
        grade: Grade? = nil,
        notes: String? = nil,
        belayPartnerName: String? = nil,
        locationDisplay: String? = nil
    ) {
        self.name = name
        self.grade = grade
        self.notes = notes
        self.belayPartnerName = belayPartnerName
        self.locationDisplay = locationDisplay
    }
}

// MARK: - Implementation

actor ClimbService: ClimbServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?,
        notes: String?
    ) async throws -> UUID {
        try await MainActor.run {
            // Verify session exists and is active
            let sessionPredicate = #Predicate<SCSession> { $0.id == sessionId }
            let sessionDescriptor = FetchDescriptor<SCSession>(predicate: sessionPredicate)

            guard let session = try modelContext.fetch(sessionDescriptor).first else {
                throw ClimbError.sessionNotFound
            }

            guard session.endedAt == nil else {
                throw ClimbError.sessionNotActive
            }

            // Create climb
            let climb = SCClimb(
                userId: userId,
                sessionId: sessionId,
                discipline: discipline,
                isOutdoor: isOutdoor,
                name: name,
                gradeOriginal: grade?.original,
                gradeScale: grade?.scale,
                gradeScoreMin: grade?.scoreMin,
                gradeScoreMax: grade?.scoreMax,
                openBetaClimbId: openBetaClimbId,
                openBetaAreaId: openBetaAreaId,
                locationDisplay: locationDisplay,
                notes: notes,
                session: session,
                needsSync: true
            )

            modelContext.insert(climb)
            session.climbs.append(climb)
            session.updatedAt = Date()
            session.needsSync = true

            try modelContext.save()

            return climb.id
        }
    }

    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> { $0.id == climbId }
            let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)

            guard let climb = try modelContext.fetch(descriptor).first else {
                throw ClimbError.climbNotFound
            }

            // Apply updates
            if let name = updates.name {
                climb.name = name
            }
            if let grade = updates.grade {
                climb.gradeOriginal = grade.original
                climb.gradeScale = grade.scale
                climb.gradeScoreMin = grade.scoreMin
                climb.gradeScoreMax = grade.scoreMax
            }
            if let notes = updates.notes {
                climb.notes = notes
            }
            if let belayPartner = updates.belayPartnerName {
                climb.belayPartnerName = belayPartner
            }
            if let location = updates.locationDisplay {
                climb.locationDisplay = location
            }

            climb.updatedAt = Date()
            climb.needsSync = true

            try modelContext.save()
        }
    }

    func deleteClimb(climbId: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> { $0.id == climbId }
            let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)

            guard let climb = try modelContext.fetch(descriptor).first else {
                throw ClimbError.climbNotFound
            }

            // Soft delete
            let now = Date()
            climb.deletedAt = now
            climb.updatedAt = now
            climb.needsSync = true

            // Also soft delete all attempts
            for attempt in climb.attempts {
                attempt.deletedAt = now
                attempt.updatedAt = now
                attempt.needsSync = true
            }

            try modelContext.save()
        }
    }

    func getSessionCounts(sessionId: UUID) async throws -> SessionCounts {
        try await MainActor.run {
            let sessionPredicate = #Predicate<SCSession> { $0.id == sessionId }
            let sessionDescriptor = FetchDescriptor<SCSession>(predicate: sessionPredicate)

            guard let session = try modelContext.fetch(sessionDescriptor).first else {
                throw ClimbError.sessionNotFound
            }

            // Count non-deleted climbs
            let climbCount = session.climbs.filter { $0.deletedAt == nil }.count

            // Count non-deleted attempts across all non-deleted climbs
            let attemptCount = session.climbs
                .filter { $0.deletedAt == nil }
                .flatMap { $0.attempts }
                .filter { $0.deletedAt == nil }
                .count

            return SessionCounts(climbCount: climbCount, attemptCount: attemptCount)
        }
    }
}
