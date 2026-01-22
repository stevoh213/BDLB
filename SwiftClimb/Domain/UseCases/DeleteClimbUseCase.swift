import Foundation

/// Soft delete a climb and all its attempts
protocol DeleteClimbUseCaseProtocol: Sendable {
    /// Executes the delete climb use case
    /// - Parameters:
    ///   - climbId: The ID of the climb to delete
    ///   - sessionId: Optional session ID for Live Activity update
    func execute(climbId: UUID, sessionId: UUID?) async throws
}

/// Implements the delete climb use case with cascade soft delete
final class DeleteClimbUseCase: DeleteClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    init(
        climbService: ClimbServiceProtocol,
        liveActivityManager: LiveActivityManagerProtocol? = nil
    ) {
        self.climbService = climbService
        self.liveActivityManager = liveActivityManager
    }

    func execute(climbId: UUID, sessionId: UUID? = nil) async throws {
        // Soft delete climb via service (also deletes attempts)
        try await climbService.deleteClimb(climbId: climbId)

        // Climb and attempts are marked needsSync=true by service
        // SyncActor will pick them up and sync to Supabase in background

        // Update Live Activity with new counts
        if let sessionId = sessionId, let liveActivityManager = liveActivityManager {
            let counts = try await climbService.getSessionCounts(sessionId: sessionId)
            await liveActivityManager.updateActivity(
                sessionId: sessionId,
                climbCount: counts.climbCount,
                attemptCount: counts.attemptCount
            )
        }
    }
}
