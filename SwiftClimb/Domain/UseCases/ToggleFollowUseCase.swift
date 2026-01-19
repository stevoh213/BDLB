import Foundation

/// Toggle follow relationship
protocol ToggleFollowUseCaseProtocol: Sendable {
    func execute(followerId: UUID, followeeId: UUID) async throws
}

// Stub implementation
final class ToggleFollowUseCase: ToggleFollowUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(followerId: UUID, followeeId: UUID) async throws {
        // TODO: Implement use case
        // 1. Check if already following
        // 2. Toggle follow state
        // 3. Mark for sync
        let isFollowing = await socialService.isFollowing(
            followerId: followerId,
            followeeId: followeeId
        )

        if isFollowing {
            try await socialService.unfollowUser(
                followerId: followerId,
                followeeId: followeeId
            )
        } else {
            try await socialService.followUser(
                followerId: followerId,
                followeeId: followeeId
            )
        }
    }
}
