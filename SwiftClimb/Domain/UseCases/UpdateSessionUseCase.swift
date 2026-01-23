import Foundation

/// Update a completed session's details
protocol UpdateSessionUseCaseProtocol: Sendable {
    func execute(
        sessionId: UUID,
        startedAt: Date,
        endedAt: Date,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws
}

/// Implements the update session use case with offline-first persistence
final class UpdateSessionUseCase: UpdateSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(
        sessionId: UUID,
        startedAt: Date,
        endedAt: Date,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // Update session via service (validates and persists locally)
        try await sessionService.updateSession(
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: endedAt,
            discipline: discipline,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes
        )

        // Session is marked needsSync=true by service
        // SyncActor will pick it up and sync to Supabase in background
    }
}
