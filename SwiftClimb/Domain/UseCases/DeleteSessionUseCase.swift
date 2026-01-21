import Foundation

/// Soft delete a session
protocol DeleteSessionUseCaseProtocol: Sendable {
    /// Executes the delete session use case
    /// - Parameter sessionId: The ID of the session to soft delete
    func execute(sessionId: UUID) async throws
}

/// Implements the delete session use case with offline-first persistence
final class DeleteSessionUseCase: DeleteSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(sessionId: UUID) async throws {
        // 1. Soft delete via service (marks deletedAt and needsSync)
        try await sessionService.deleteSession(sessionId: sessionId)

        // 2. Session is marked needsSync=true by service
        // 3. SyncActor will pick it up and sync to Supabase in background
    }
}
