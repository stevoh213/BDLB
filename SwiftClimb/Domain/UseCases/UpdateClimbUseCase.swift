import Foundation

/// Update properties of an existing climb
protocol UpdateClimbUseCaseProtocol: Sendable {
    /// Executes the update climb use case
    func execute(
        climbId: UUID,
        name: String?,
        gradeString: String?,
        notes: String?,
        belayPartnerName: String?,
        locationDisplay: String?
    ) async throws
}

/// Implements the update climb use case with grade parsing
final class UpdateClimbUseCase: UpdateClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(
        climbId: UUID,
        name: String?,
        gradeString: String?,
        notes: String?,
        belayPartnerName: String?,
        locationDisplay: String?
    ) async throws {
        // Parse grade if provided
        var grade: Grade? = nil
        if let gradeString = gradeString {
            grade = Grade.parse(gradeString)
        }

        // Build updates struct
        let updates = ClimbUpdates(
            name: name,
            grade: grade,
            notes: notes,
            belayPartnerName: belayPartnerName,
            locationDisplay: locationDisplay
        )

        // Update climb via service (persists locally)
        try await climbService.updateClimb(climbId: climbId, updates: updates)

        // Climb is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background
    }
}
