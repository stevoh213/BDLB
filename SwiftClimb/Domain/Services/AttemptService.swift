import Foundation

/// Attempt logging
protocol AttemptServiceProtocol: Sendable {
    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt

    func deleteAttempt(attemptId: UUID) async throws
    func getAttempts(climbId: UUID) async -> [SCAttempt]
}

// Stub implementation
final class AttemptService: AttemptServiceProtocol, @unchecked Sendable {
    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt {
        // TODO: Implement attempt logging
        fatalError("Not implemented")
    }

    func deleteAttempt(attemptId: UUID) async throws {
        // TODO: Implement attempt deletion
    }

    func getAttempts(climbId: UUID) async -> [SCAttempt] {
        // TODO: Implement attempt retrieval
        return []
    }
}
