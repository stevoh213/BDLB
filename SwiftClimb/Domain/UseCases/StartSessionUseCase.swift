import Foundation

/// Start a new climbing session
protocol StartSessionUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession
}

// Stub implementation
final class StartSessionUseCase: StartSessionUseCaseProtocol, @unchecked Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession {
        // TODO: Implement use case
        // 1. Validate no active session exists
        // 2. Create session via service
        // 3. Mark for sync
        return try await sessionService.createSession(
            userId: userId,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )
    }
}
