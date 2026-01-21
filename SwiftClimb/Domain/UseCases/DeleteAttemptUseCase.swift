import Foundation

/// Soft delete a single attempt
protocol DeleteAttemptUseCaseProtocol: Sendable {
    /// Executes the delete attempt use case
    func execute(attemptId: UUID) async throws
}

/// Implements the delete attempt use case with soft delete
final class DeleteAttemptUseCase: DeleteAttemptUseCaseProtocol, Sendable {
    private let attemptService: AttemptServiceProtocol

    init(attemptService: AttemptServiceProtocol) {
        self.attemptService = attemptService
    }

    func execute(attemptId: UUID) async throws {
        // Soft delete attempt via service
        try await attemptService.deleteAttempt(attemptId: attemptId)

        // Attempt is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background
    }
}
