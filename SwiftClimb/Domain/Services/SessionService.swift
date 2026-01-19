import Foundation

/// Session lifecycle management
protocol SessionServiceProtocol: Sendable {
    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession

    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws

    func getActiveSession(userId: UUID) async -> SCSession?
    func getSessionHistory(userId: UUID, limit: Int) async -> [SCSession]
}

// Stub implementation
final class SessionService: SessionServiceProtocol, @unchecked Sendable {
    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession {
        // TODO: Implement session creation
        fatalError("Not implemented")
    }

    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // TODO: Implement session ending
    }

    func getActiveSession(userId: UUID) async -> SCSession? {
        // TODO: Implement active session retrieval
        return nil
    }

    func getSessionHistory(userId: UUID, limit: Int) async -> [SCSession] {
        // TODO: Implement session history retrieval
        return []
    }
}
