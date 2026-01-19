import Foundation

/// Add a climb to a session
protocol AddClimbUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?
    ) async throws -> SCClimb
}

// Stub implementation
final class AddClimbUseCase: AddClimbUseCaseProtocol, @unchecked Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?
    ) async throws -> SCClimb {
        // TODO: Implement use case
        // 1. Validate session exists and is active
        // 2. Create climb via service
        // 3. Mark for sync
        return try await climbService.createClimb(
            userId: userId,
            sessionId: sessionId,
            discipline: discipline,
            isOutdoor: isOutdoor,
            name: name,
            grade: grade
        )
    }
}
