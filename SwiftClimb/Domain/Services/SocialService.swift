import Foundation
import SwiftData

/// Social features (follow/feed/kudos/comments)
protocol SocialServiceProtocol: Sendable {
    // MARK: - Follow/Unfollow Operations
    func followUser(followerId: UUID, followeeId: UUID) async throws
    func unfollowUser(followerId: UUID, followeeId: UUID) async throws
    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool

    // MARK: - Follower/Following Methods (Phase 2)

    /// Gets the list of users following a given user
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum number of results
    ///   - offset: Pagination offset
    /// - Returns: Array of profiles following this user
    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]

    /// Gets the list of users a given user is following
    /// - Parameters:
    ///   - userId: The user whose following list to retrieve
    ///   - limit: Maximum number of results
    ///   - offset: Pagination offset
    /// - Returns: Array of profiles this user follows
    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]

    /// Gets the follower and following counts for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Tuple of (followerCount, followingCount)
    func getFollowCounts(userId: UUID) async throws -> (followers: Int, following: Int)

    // MARK: - Post/Feed Operations (Stub - Phase 3+)
    func createPost(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws

    func getFeed(userId: UUID, limit: Int) async -> [UUID]

    // MARK: - Kudos Operations (Stub - Phase 3+)
    func addKudos(postId: UUID, userId: UUID) async throws
    func removeKudos(postId: UUID, userId: UUID) async throws

    // MARK: - Comment Operations (Stub - Phase 3+)
    func addComment(postId: UUID, authorId: UUID, content: String) async throws
    func getComments(postId: UUID) async -> [UUID]
}

/// Errors that can occur during social operations
enum SocialError: Error, LocalizedError, Sendable {
    case cannotFollowSelf
    case alreadyFollowing
    case notFollowing
    case postNotFound
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .alreadyFollowing:
            return "You are already following this user"
        case .notFollowing:
            return "You are not following this user"
        case .postNotFound:
            return "Post not found"
        case .unauthorized:
            return "Not authorized to perform this action"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Manages social features including follows, posts, kudos, and comments
///
/// `SocialServiceImpl` provides social functionality with offline-first semantics.
/// Follow actions are saved locally first, then synced to Supabase.
/// Follower/following lists are fetched from the remote server.
actor SocialServiceImpl: SocialServiceProtocol {
    private let modelContainer: ModelContainer
    private let followsTable: FollowsTable
    private let profilesTable: ProfilesTable

    init(
        modelContainer: ModelContainer,
        followsTable: FollowsTable,
        profilesTable: ProfilesTable
    ) {
        self.modelContainer = modelContainer
        self.followsTable = followsTable
        self.profilesTable = profilesTable
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Follow/Unfollow (Phase 2 Implementation)

    func followUser(followerId: UUID, followeeId: UUID) async throws {
        // 1. Prevent self-follow
        guard followerId != followeeId else {
            throw SocialError.cannotFollowSelf
        }

        // 2. Check if already following (locally first)
        let existingFollowId = await MainActor.run { () -> UUID? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return try? modelContext.fetch(descriptor).first?.id
        }

        if existingFollowId != nil {
            return // Already following
        }

        // 3. Check for soft-deleted follow to restore
        let deletedFollowId = await MainActor.run { () -> UUID? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt != nil
                }
            )
            return try? modelContext.fetch(descriptor).first?.id
        }

        // 4. Create or restore follow locally
        try await MainActor.run {
            if let deletedId = deletedFollowId {
                // Restore soft-deleted follow
                let descriptor = FetchDescriptor<SCFollow>(
                    predicate: #Predicate { $0.id == deletedId }
                )
                if let follow = try? modelContext.fetch(descriptor).first {
                    follow.deletedAt = nil
                    follow.needsSync = true
                }
            } else {
                // Create new follow
                let follow = SCFollow(
                    followerId: followerId,
                    followeeId: followeeId,
                    needsSync: true
                )
                modelContext.insert(follow)
            }
            try modelContext.save()
        }

        // 5. Sync to remote
        Task {
            try? await followsTable.createFollow(followerId: followerId, followeeId: followeeId)
        }
    }

    func unfollowUser(followerId: UUID, followeeId: UUID) async throws {
        // 1. Find follow locally
        let followId = await MainActor.run { () -> UUID? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return try? modelContext.fetch(descriptor).first?.id
        }

        guard let followId = followId else {
            return // Not following, nothing to do
        }

        // 2. Soft delete locally
        try await MainActor.run {
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate { $0.id == followId }
            )
            if let follow = try? modelContext.fetch(descriptor).first {
                follow.deletedAt = Date()
                follow.needsSync = true
                try modelContext.save()
            }
        }

        // 3. Sync to remote
        Task {
            try? await followsTable.deleteFollow(followerId: followerId, followeeId: followeeId)
        }
    }

    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool {
        // Check locally first
        let localResult = await MainActor.run { () -> Bool in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return (try? modelContext.fetch(descriptor).first) != nil
        }
        return localResult
    }

    // MARK: - New Follower/Following Methods (Phase 2 Implementation)

    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult] {
        // This is a remote-only operation - we need the full list across all users
        let results = try await followsTable.getFollowers(
            userId: userId,
            limit: limit,
            offset: offset
        )
        return results.map { dto in
            ProfileSearchResult(
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
        }
    }

    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult] {
        // This is a remote-only operation
        let results = try await followsTable.getFollowing(
            userId: userId,
            limit: limit,
            offset: offset
        )
        return results.map { dto in
            ProfileSearchResult(
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
        }
    }

    func getFollowCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        // Prefer local cached counts if available
        let localCounts = await MainActor.run { () -> (Int, Int)? in
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == userId }
            )
            guard let profile = try? modelContext.fetch(descriptor).first else {
                return nil
            }
            return (profile.followerCount, profile.followingCount)
        }

        if let counts = localCounts {
            return counts
        }

        // Fallback to remote
        guard let profileDTO = try await profilesTable.fetchProfile(userId: userId) else {
            return (0, 0)
        }
        return (profileDTO.followerCount, profileDTO.followingCount)
    }

    // MARK: - Existing Stub Methods (not implemented in Phase 2)

    func createPost(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws {
        // TODO: Implement in future phase
        fatalError("Not implemented")
    }

    func getFeed(userId: UUID, limit: Int) async -> [UUID] {
        // TODO: Implement in future phase
        return []
    }

    func addKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement in future phase
    }

    func removeKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement in future phase
    }

    func addComment(postId: UUID, authorId: UUID, content: String) async throws {
        // TODO: Implement in future phase
    }

    func getComments(postId: UUID) async -> [UUID] {
        // TODO: Implement in future phase
        return []
    }
}
