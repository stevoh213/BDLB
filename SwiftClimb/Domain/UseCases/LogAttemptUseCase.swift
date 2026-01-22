import Foundation

/// Log a climb attempt with auto-inferred send type
protocol LogAttemptUseCaseProtocol: Sendable {
    /// Executes the log attempt use case
    /// - Returns: The ID of the newly created attempt
    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        discipline: Discipline,
        sendTypeOverride: SendType?
    ) async throws -> UUID
}

/// Implements the log attempt use case with send type inference
final class LogAttemptUseCase: LogAttemptUseCaseProtocol, Sendable {
    private let attemptService: AttemptServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    init(
        attemptService: AttemptServiceProtocol,
        liveActivityManager: LiveActivityManagerProtocol? = nil
    ) {
        self.attemptService = attemptService
        self.liveActivityManager = liveActivityManager
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        discipline: Discipline,
        sendTypeOverride: SendType? = nil
    ) async throws -> UUID {
        // Determine send type for successful sends
        var sendType: SendType? = nil

        if outcome == .send {
            if let override = sendTypeOverride {
                // User provided explicit send type
                sendType = override
            } else {
                // Auto-infer based on attempt history:
                // - First attempt = flash
                // - Subsequent attempts = redpoint
                sendType = try await attemptService.inferSendType(
                    climbId: climbId,
                    discipline: discipline
                )
            }
        }

        // Log attempt via service (validates and persists locally)
        let attemptId = try await attemptService.logAttempt(
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            outcome: outcome,
            sendType: sendType
        )

        // Attempt is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background

        // Update Live Activity with incremented attempt count
        await liveActivityManager?.incrementAttemptCount(sessionId: sessionId)

        return attemptId
    }
}
