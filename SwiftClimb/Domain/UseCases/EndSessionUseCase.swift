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

/// Implements the end session use case with offline-first persistence
final class EndSessionUseCase: EndSessionUseCaseProtocol, Sendable {
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
        // 1. End session via service (validates and persists locally)
        try await sessionService.endSession(
            sessionId: sessionId,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes
        )

        // 2. Session is marked needsSync=true by service
        // 3. SyncActor will pick it up and sync to Supabase in background
    }
}
