import Foundation

/// Soft delete a single attempt
protocol DeleteAttemptUseCaseProtocol: Sendable {
    /// Executes the delete attempt use case
    /// - Parameters:
    ///   - attemptId: The ID of the attempt to delete
    ///   - sessionId: Optional session ID for Live Activity update
    func execute(attemptId: UUID, sessionId: UUID?) async throws
}

/// Implements the delete attempt use case with soft delete
final class DeleteAttemptUseCase: DeleteAttemptUseCaseProtocol, Sendable {
    private let attemptService: AttemptServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    init(
        attemptService: AttemptServiceProtocol,
        liveActivityManager: LiveActivityManagerProtocol? = nil
    ) {
        self.attemptService = attemptService
        self.liveActivityManager = liveActivityManager
    }

    func execute(attemptId: UUID, sessionId: UUID? = nil) async throws {
        // Soft delete attempt via service
        try await attemptService.deleteAttempt(attemptId: attemptId)

        // Attempt is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background

        // Update Live Activity with decremented attempt count
        if let sessionId = sessionId {
            await liveActivityManager?.decrementAttemptCount(sessionId: sessionId)
        }
    }
}
