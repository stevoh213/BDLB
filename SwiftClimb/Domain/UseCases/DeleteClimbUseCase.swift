import Foundation

/// Soft delete a climb and all its attempts
protocol DeleteClimbUseCaseProtocol: Sendable {
    /// Executes the delete climb use case
    func execute(climbId: UUID) async throws
}

/// Implements the delete climb use case with cascade soft delete
final class DeleteClimbUseCase: DeleteClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(climbId: UUID) async throws {
        // Soft delete climb via service (also deletes attempts)
        try await climbService.deleteClimb(climbId: climbId)

        // Climb and attempts are marked needsSync=true by service
        // SyncActor will pick them up and sync to Supabase in background
    }
}
