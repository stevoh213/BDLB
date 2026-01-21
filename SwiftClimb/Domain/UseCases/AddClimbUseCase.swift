import Foundation

/// Add a climb to an active session
protocol AddClimbUseCaseProtocol: Sendable {
    /// Executes the add climb use case
    /// - Returns: The ID of the newly created climb
    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        gradeString: String,
        gradeScale: GradeScale,
        name: String?,
        isOutdoor: Bool,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> UUID
}

/// Implements the add climb use case with grade parsing and validation
final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        gradeString: String,
        gradeScale: GradeScale,
        name: String?,
        isOutdoor: Bool = false,
        openBetaClimbId: String? = nil,
        openBetaAreaId: String? = nil,
        locationDisplay: String? = nil
    ) async throws -> UUID {
        // Parse grade from string
        guard let grade = Grade.parse(gradeString) else {
            throw ClimbError.invalidGrade(gradeString)
        }

        // Create climb via service (validates and persists locally)
        let climbId = try await climbService.createClimb(
            userId: userId,
            sessionId: sessionId,
            discipline: discipline,
            isOutdoor: isOutdoor,
            name: name,
            grade: grade,
            openBetaClimbId: openBetaClimbId,
            openBetaAreaId: openBetaAreaId,
            locationDisplay: locationDisplay
        )

        // Climb is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background

        return climbId
    }
}
