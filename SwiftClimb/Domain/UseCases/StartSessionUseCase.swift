import Foundation

/// Start a new climbing session
protocol StartSessionUseCaseProtocol: Sendable {
    /// Executes the start session use case
    /// - Returns: The ID of the newly created session
    func execute(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID
}

/// Implements the start session use case with offline-first persistence
final class StartSessionUseCase: StartSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    init(
        sessionService: SessionServiceProtocol,
        liveActivityManager: LiveActivityManagerProtocol? = nil
    ) {
        self.sessionService = sessionService
        self.liveActivityManager = liveActivityManager
    }

    func execute(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID {
        let startedAt = Date()

        // 1. Create session via service (validates and persists locally)
        let sessionId = try await sessionService.createSession(
            userId: userId,
            discipline: discipline,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )

        // 2. Session is marked needsSync=true by service
        // 3. SyncActor will pick it up and sync to Supabase in background

        // 4. Start Live Activity for Lock Screen / Dynamic Island
        await liveActivityManager?.startActivity(
            sessionId: sessionId,
            discipline: discipline,
            startedAt: startedAt
        )

        return sessionId
    }
}
