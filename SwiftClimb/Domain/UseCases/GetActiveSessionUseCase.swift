import Foundation

/// Get the currently active session for a user
protocol GetActiveSessionUseCaseProtocol: Sendable {
    /// Executes the get active session use case
    /// - Returns: The ID of the active session, or nil if no session is active
    func execute(userId: UUID) async throws -> UUID?
}

/// Implements the get active session use case
final class GetActiveSessionUseCase: GetActiveSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(userId: UUID) async throws -> UUID? {
        return try await sessionService.getActiveSessionId(userId: userId)
    }
}
