import Foundation

/// Update properties of an existing climb including tag impacts
protocol UpdateClimbUseCaseProtocol: Sendable {
    /// Executes the update climb use case with full edit data
    func execute(
        userId: UUID,
        climbId: UUID,
        data: ClimbEditData
    ) async throws
}

/// Implements the update climb use case with grade parsing and tag impact updates
final class UpdateClimbUseCase: UpdateClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let tagService: TagServiceProtocol

    init(climbService: ClimbServiceProtocol, tagService: TagServiceProtocol) {
        self.climbService = climbService
        self.tagService = tagService
    }

    func execute(
        userId: UUID,
        climbId: UUID,
        data: ClimbEditData
    ) async throws {
        // Parse grade
        let grade = Grade.parse(data.gradeString)

        // Build updates struct for basic climb properties
        let updates = ClimbUpdates(
            name: data.name,
            grade: grade,
            notes: data.notes
        )

        // Update climb via service (persists locally)
        try await climbService.updateClimb(climbId: climbId, updates: updates)

        // Update tag impacts (this replaces all existing impacts)
        try await tagService.setHoldTypeImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.holdTypeImpacts
        )

        try await tagService.setSkillImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.skillImpacts
        )

        // Climb is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background
    }
}
