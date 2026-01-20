import Foundation

/// Errors that can occur when fetching a profile
enum FetchProfileError: Error, LocalizedError, Sendable {
    case profileNotFound
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .networkError(let message):
            return "Failed to load profile: \(message)"
        case .unauthorized:
            return "You must be logged in to view profiles"
        }
    }
}

/// Fetches a remote profile by ID
///
/// Used by OtherProfileView to load profile data from Supabase
/// when viewing another user's profile.
protocol FetchProfileUseCaseProtocol: Sendable {
    /// Fetches a profile from the remote server
    /// - Parameter profileId: The profile's UUID
    /// - Returns: The profile data as a search result
    /// - Throws: FetchProfileError if the fetch fails
    func execute(profileId: UUID) async throws -> ProfileSearchResult
}

/// Fetches a remote profile by ID
///
/// `FetchProfileUseCase` retrieves profile data from Supabase for viewing
/// other users' profiles. This is a remote-only operation since the profile
/// may not exist in local SwiftData.
///
/// ## Usage
///
/// ```swift
/// let useCase = FetchProfileUseCase(profileService: profileService)
/// let profile = try await useCase.execute(profileId: userId)
/// ```
final class FetchProfileUseCase: FetchProfileUseCaseProtocol, @unchecked Sendable {
    private let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol) {
        self.profileService = profileService
    }

    func execute(profileId: UUID) async throws -> ProfileSearchResult {
        do {
            guard let dto = try await profileService.fetchRemoteProfile(profileId: profileId) else {
                throw FetchProfileError.profileNotFound
            }

            return ProfileSearchResult(
                id: dto.id,
                handle: dto.handle,
                displayName: dto.displayName,
                photoURL: dto.photoURL,
                bio: dto.bio,
                isPublic: dto.isPublic,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount
            )
        } catch let error as ProfileError {
            switch error {
            case .profileNotFound:
                throw FetchProfileError.profileNotFound
            case .unauthorized:
                throw FetchProfileError.unauthorized
            case .networkError(let underlyingError):
                throw FetchProfileError.networkError(underlyingError.localizedDescription)
            default:
                throw FetchProfileError.networkError(error.localizedDescription)
            }
        }
    }
}
