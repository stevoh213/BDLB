import Foundation

/// Errors that can occur when retrieving followers
enum GetFollowersError: Error, LocalizedError, Sendable {
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Failed to load followers: \(message)"
        case .unauthorized:
            return "You must be logged in to view followers"
        }
    }
}

/// Retrieves followers for a user profile
///
/// Provides paginated access to a user's followers list.
protocol GetFollowersUseCaseProtocol: Sendable {
    /// Gets the list of users following a given user
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum results per page (default 20)
    ///   - offset: Pagination offset (default 0)
    /// - Returns: Array of profile search results representing followers
    /// - Throws: GetFollowersError if retrieval fails
    func execute(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]
}

/// Retrieves followers for a user profile with pagination
///
/// `GetFollowersUseCase` fetches the list of users who follow a given user.
/// This is a remote-only operation since we need the complete follower list
/// across all users in the system.
///
/// ## Pagination
///
/// Results are paginated with a default page size of 20. The offset parameter
/// specifies how many results to skip for subsequent pages.
///
/// ## Usage
///
/// ```swift
/// let useCase = GetFollowersUseCase(socialService: socialService)
///
/// // First page
/// let page1 = try await useCase.execute(userId: profileId, limit: 20, offset: 0)
///
/// // Second page
/// let page2 = try await useCase.execute(userId: profileId, limit: 20, offset: 20)
/// ```
final class GetFollowersUseCase: GetFollowersUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    /// Default page size
    static let defaultLimit = 20

    /// Maximum page size
    static let maxLimit = 50

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(
        userId: UUID,
        limit: Int = defaultLimit,
        offset: Int = 0
    ) async throws -> [ProfileSearchResult] {
        // Enforce limit bounds
        let effectiveLimit = min(max(limit, 1), Self.maxLimit)
        let effectiveOffset = max(offset, 0)

        do {
            return try await socialService.getFollowers(
                userId: userId,
                limit: effectiveLimit,
                offset: effectiveOffset
            )
        } catch let error as SocialError {
            switch error {
            case .unauthorized:
                throw GetFollowersError.unauthorized
            case .networkError(let underlyingError):
                throw GetFollowersError.networkError(underlyingError.localizedDescription)
            default:
                throw GetFollowersError.networkError(error.localizedDescription)
            }
        }
    }
}
