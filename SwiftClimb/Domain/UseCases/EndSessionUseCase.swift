import Foundation

/// End an active climbing session
protocol EndSessionUseCaseProtocol: Sendable {
    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws
}

// Stub implementation
final class EndSessionUseCase: EndSessionUseCaseProtocol, @unchecked Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // TODO: Implement use case
        // 1. Validate session exists and is active
        // 2. End session via service
        // 3. Trigger sync
        try await sessionService.endSession(
            sessionId: sessionId,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes
        )
    }
}
