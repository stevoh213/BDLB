import Foundation

/// Errors that can occur during profile search
enum SearchProfilesError: Error, LocalizedError, Sendable {
    case queryTooShort(minLength: Int)
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .queryTooShort(let minLength):
            return "Search query must be at least \(minLength) characters"
        case .networkError(let message):
            return "Search failed: \(message)"
        case .unauthorized:
            return "You must be logged in to search profiles"
        }
    }
}

/// Searches for user profiles
///
/// Provides profile search functionality with query validation.
/// Requires minimum query length to prevent overly broad searches.
protocol SearchProfilesUseCaseProtocol: Sendable {
    /// Searches for profiles matching a query string
    /// - Parameters:
    ///   - query: Search string (minimum 2 characters)
    ///   - limit: Maximum results to return (default 20, max 50)
    /// - Returns: Array of matching profile search results
    /// - Throws: SearchProfilesError if query is invalid or search fails
    func execute(query: String, limit: Int) async throws -> [ProfileSearchResult]
}

/// Searches for user profiles by handle or display name
///
/// `SearchProfilesUseCase` validates search queries and delegates to ProfileService.
/// Search is a remote-only operation since we need to search across all users.
///
/// ## Query Requirements
///
/// - Minimum 2 characters
/// - Searches both handle and display name (case-insensitive)
/// - Only returns public profiles
///
/// ## Usage
///
/// ```swift
/// let useCase = SearchProfilesUseCase(profileService: profileService)
/// let results = try await useCase.execute(query: "alex", limit: 20)
/// ```
final class SearchProfilesUseCase: SearchProfilesUseCaseProtocol, @unchecked Sendable {
    private let profileService: ProfileServiceProtocol

    /// Minimum query length required
    static let minQueryLength = 2

    /// Maximum results that can be requested
    static let maxLimit = 50

    /// Default result limit
    static let defaultLimit = 20

    init(profileService: ProfileServiceProtocol) {
        self.profileService = profileService
    }

    func execute(query: String, limit: Int = defaultLimit) async throws -> [ProfileSearchResult] {
        // 1. Trim and validate query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= Self.minQueryLength else {
            throw SearchProfilesError.queryTooShort(minLength: Self.minQueryLength)
        }

        // 2. Enforce limit bounds
        let effectiveLimit = min(max(limit, 1), Self.maxLimit)

        // 3. Delegate to service
        do {
            return try await profileService.searchProfiles(
                query: trimmedQuery,
                limit: effectiveLimit
            )
        } catch let error as ProfileError {
            switch error {
            case .unauthorized:
                throw SearchProfilesError.unauthorized
            case .networkError(let underlyingError):
                throw SearchProfilesError.networkError(underlyingError.localizedDescription)
            default:
                throw SearchProfilesError.networkError(error.localizedDescription)
            }
        }
    }
}
