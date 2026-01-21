import Foundation

/// List completed sessions with pagination
protocol ListSessionsUseCaseProtocol: Sendable {
    /// Executes the list sessions use case
    /// - Parameters:
    ///   - userId: The user whose sessions to list
    ///   - limit: Maximum number of sessions to return (default: 20)
    ///   - offset: Number of sessions to skip for pagination (default: 0)
    /// - Returns: Array of session IDs, sorted by end date (most recent first)
    func execute(userId: UUID, limit: Int, offset: Int) async throws -> [UUID]
}

/// Implements the list sessions use case for retrieving session history
final class ListSessionsUseCase: ListSessionsUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(userId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [UUID] {
        return try await sessionService.getSessionHistory(
            userId: userId,
            limit: limit,
            offset: offset
        )
    }
}
