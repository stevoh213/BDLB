import Foundation

/// Errors that can occur when toggling follow
enum ToggleFollowError: Error, LocalizedError, Sendable {
    case cannotFollowSelf
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .networkError(let message):
            return "Follow action failed: \(message)"
        case .unauthorized:
            return "You must be logged in to follow users"
        }
    }
}

/// Toggle follow relationship
///
/// Manages follow/unfollow actions between users.
protocol ToggleFollowUseCaseProtocol: Sendable {
    /// Toggles the follow relationship between two users
    /// - Parameters:
    ///   - followerId: The user performing the action (current user)
    ///   - followeeId: The user to follow/unfollow
    /// - Returns: The new follow state (true = now following, false = now not following)
    /// - Throws: ToggleFollowError if the operation fails
    func execute(followerId: UUID, followeeId: UUID) async throws -> Bool

    /// Checks if one user is following another
    /// - Parameters:
    ///   - followerId: The potential follower
    ///   - followeeId: The potential followee
    /// - Returns: true if followerId is following followeeId
    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool
}

/// Toggles follow relationship between users
///
/// `ToggleFollowUseCase` provides a convenient toggle interface for follow buttons.
/// It checks the current follow state and performs the opposite action.
///
/// ## Usage
///
/// ```swift
/// let useCase = ToggleFollowUseCase(socialService: socialService)
///
/// // Toggle follow state
/// let isNowFollowing = try await useCase.execute(
///     followerId: currentUserId,
///     followeeId: profileUserId
/// )
///
/// // Check state without toggling
/// let isFollowing = await useCase.isFollowing(
///     followerId: currentUserId,
///     followeeId: profileUserId
/// )
/// ```
final class ToggleFollowUseCase: ToggleFollowUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(followerId: UUID, followeeId: UUID) async throws -> Bool {
        // 1. Prevent self-follow at use case level
        guard followerId != followeeId else {
            throw ToggleFollowError.cannotFollowSelf
        }

        // 2. Check current state
        let isCurrentlyFollowing = await socialService.isFollowing(
            followerId: followerId,
            followeeId: followeeId
        )

        // 3. Toggle
        do {
            if isCurrentlyFollowing {
                try await socialService.unfollowUser(
                    followerId: followerId,
                    followeeId: followeeId
                )
                return false
            } else {
                try await socialService.followUser(
                    followerId: followerId,
                    followeeId: followeeId
                )
                return true
            }
        } catch let error as SocialError {
            switch error {
            case .cannotFollowSelf:
                throw ToggleFollowError.cannotFollowSelf
            case .unauthorized:
                throw ToggleFollowError.unauthorized
            case .networkError(let underlyingError):
                throw ToggleFollowError.networkError(underlyingError.localizedDescription)
            default:
                throw ToggleFollowError.networkError(error.localizedDescription)
            }
        }
    }

    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool {
        await socialService.isFollowing(followerId: followerId, followeeId: followeeId)
    }
}
