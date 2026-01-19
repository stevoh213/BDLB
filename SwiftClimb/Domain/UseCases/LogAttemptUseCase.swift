import Foundation

/// Log an attempt on a climb
protocol LogAttemptUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt
}

// Stub implementation
final class LogAttemptUseCase: LogAttemptUseCaseProtocol, @unchecked Sendable {
    private let attemptService: AttemptServiceProtocol

    init(attemptService: AttemptServiceProtocol) {
        self.attemptService = attemptService
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt {
        // TODO: Implement use case
        // 1. Validate climb exists
        // 2. Calculate attempt number
        // 3. Create attempt via service (< 100ms target)
        // 4. Mark for sync
        return try await attemptService.logAttempt(
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            outcome: outcome,
            sendType: sendType
        )
    }
}
