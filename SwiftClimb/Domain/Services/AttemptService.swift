import Foundation
import SwiftData

// MARK: - Errors

enum AttemptError: LocalizedError {
    case climbNotFound
    case attemptNotFound
    case invalidAttemptNumber
    case sendTypeRequiredForSend

    var errorDescription: String? {
        switch self {
        case .climbNotFound:
            return "Climb not found"
        case .attemptNotFound:
            return "Attempt not found"
        case .invalidAttemptNumber:
            return "Invalid attempt number"
        case .sendTypeRequiredForSend:
            return "Send type is required for successful sends"
        }
    }
}

// MARK: - Protocol

protocol AttemptServiceProtocol: Sendable {
    /// Log a new attempt on a climb
    /// Performance target: < 100ms
    /// Returns the UUID of the created attempt
    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> UUID

    /// Soft delete an attempt
    func deleteAttempt(attemptId: UUID) async throws

    /// Infer send type based on attempt history
    func inferSendType(climbId: UUID, discipline: Discipline) async throws -> SendType
}

// MARK: - Implementation

actor AttemptService: AttemptServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> UUID {
        // Validate: sends require send type
        if outcome == .send && sendType == nil {
            throw AttemptError.sendTypeRequiredForSend
        }

        return try await MainActor.run {
            // Verify climb exists
            let climbPredicate = #Predicate<SCClimb> { $0.id == climbId }
            let climbDescriptor = FetchDescriptor<SCClimb>(predicate: climbPredicate)

            guard let climb = try modelContext.fetch(climbDescriptor).first else {
                throw AttemptError.climbNotFound
            }

            // Calculate next attempt number
            let existingAttempts = climb.attempts.filter { $0.deletedAt == nil }
            let attemptNumber = existingAttempts.count + 1

            // Create attempt
            let attempt = SCAttempt(
                userId: userId,
                sessionId: sessionId,
                climbId: climbId,
                attemptNumber: attemptNumber,
                outcome: outcome,
                sendType: sendType,
                occurredAt: Date(),
                climb: climb,
                needsSync: true
            )

            modelContext.insert(attempt)
            climb.attempts.append(attempt)
            climb.updatedAt = Date()
            climb.needsSync = true

            try modelContext.save()

            return attempt.id
        }
    }

    func deleteAttempt(attemptId: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> { $0.id == attemptId }
            let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)

            guard let attempt = try modelContext.fetch(descriptor).first else {
                throw AttemptError.attemptNotFound
            }

            // Soft delete
            let now = Date()
            attempt.deletedAt = now
            attempt.updatedAt = now
            attempt.needsSync = true

            // Update climb
            if let climb = attempt.climb {
                climb.updatedAt = now
                climb.needsSync = true
            }

            try modelContext.save()
        }
    }

    func inferSendType(climbId: UUID, discipline: Discipline) async throws -> SendType {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)
            let attempts = try modelContext.fetch(descriptor)

            // If no previous attempts, it's a flash (first try with beta)
            // For bouldering, flash is standard. For routes, could be onsight
            // but we default to flash (safer assumption - user saw others try it)
            if attempts.isEmpty {
                return .flash
            }

            // If there are previous attempts, it's a redpoint
            return .redpoint
        }
    }
}
