import Foundation

/// Follows table operations
///
/// `FollowsTable` provides typed operations for the `follows` table in Supabase.
/// It manages follower/following relationships and retrieves lists with joined profile data.
///
/// ## Table Structure
///
/// ```sql
/// follows (
///     id UUID PRIMARY KEY,
///     follower_id UUID REFERENCES profiles(id),
///     followee_id UUID REFERENCES profiles(id),
///     created_at TIMESTAMPTZ,
///     deleted_at TIMESTAMPTZ  -- soft delete
/// )
/// ```
///
/// ## Follower Count Updates
///
/// The `follower_count` and `following_count` fields on `profiles` are automatically
/// updated by database triggers when follows are created, soft-deleted, or restored.
actor FollowsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    // MARK: - Follow Operations

    /// Creates a new follow relationship
    ///
    /// If a soft-deleted follow exists, it will be restored instead of creating a duplicate.
    ///
    /// - Parameters:
    ///   - followerId: The user who is following
    ///   - followeeId: The user being followed
    /// - Throws: NetworkError if operation fails
    func createFollow(followerId: UUID, followeeId: UUID) async throws {
        // Try to find existing soft-deleted follow first
        let existing = try await findExistingFollow(followerId: followerId, followeeId: followeeId)

        if let existing = existing {
            // Restore the soft-deleted follow
            let restoreRequest = FollowRestoreRequest(deletedAt: nil)
            let _: FollowDTO = try await repository.update(
                table: "follows",
                id: existing.id,
                values: restoreRequest
            )
        } else {
            // Create new follow
            let dto = FollowDTO(
                id: UUID(),
                followerId: followerId,
                followeeId: followeeId,
                createdAt: Date(),
                deletedAt: nil
            )
            let _: FollowDTO = try await repository.insert(
                into: "follows",
                values: dto
            )
        }
    }

    /// Soft-deletes a follow relationship
    ///
    /// - Parameters:
    ///   - followerId: The user who is unfollowing
    ///   - followeeId: The user being unfollowed
    /// - Throws: NetworkError if operation fails
    func deleteFollow(followerId: UUID, followeeId: UUID) async throws {
        // Find the follow relationship
        let existing = try await findExistingFollow(followerId: followerId, followeeId: followeeId)

        guard let follow = existing, follow.deletedAt == nil else {
            return // Not following or already deleted
        }

        // Soft delete
        try await repository.delete(from: "follows", id: follow.id)
    }

    /// Checks if a follow relationship exists
    ///
    /// - Parameters:
    ///   - followerId: The potential follower
    ///   - followeeId: The potential followee
    /// - Returns: true if an active follow exists
    func checkIsFollowing(followerId: UUID, followeeId: UUID) async throws -> Bool {
        let queryParams: [String: String] = [
            "select": "id",
            "follower_id": "eq.\(followerId.uuidString)",
            "followee_id": "eq.\(followeeId.uuidString)",
            "deleted_at": "is.null",
            "limit": "1"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let client = await repository.client
        let results: [FollowDTO] = try await client.execute(request)
        return !results.isEmpty
    }

    // MARK: - Follower/Following Lists

    /// Gets the list of profiles following a user
    ///
    /// Returns profiles that have an active (non-deleted) follow relationship
    /// where the specified user is the followee.
    ///
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum results
    ///   - offset: Pagination offset
    /// - Returns: Array of profile DTOs
    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResultDTO] {
        // Use a view or RPC for joined query
        // PostgREST query: select profiles joined via follows
        let queryParams: [String: String] = [
            "select": "follower:follower_id(id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count)",
            "followee_id": "eq.\(userId.uuidString)",
            "deleted_at": "is.null",
            "order": "created_at.desc",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let client = await repository.client
        let results: [FollowWithProfileDTO] = try await client.execute(request)
        return results.compactMap { $0.follower }
    }

    /// Gets the list of profiles a user is following
    ///
    /// Returns profiles that have an active (non-deleted) follow relationship
    /// where the specified user is the follower.
    ///
    /// - Parameters:
    ///   - userId: The user whose following list to retrieve
    ///   - limit: Maximum results
    ///   - offset: Pagination offset
    /// - Returns: Array of profile DTOs
    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResultDTO] {
        let queryParams: [String: String] = [
            "select": "followee:followee_id(id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count)",
            "follower_id": "eq.\(userId.uuidString)",
            "deleted_at": "is.null",
            "order": "created_at.desc",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let client = await repository.client
        let results: [FollowWithProfileDTO] = try await client.execute(request)
        return results.compactMap { $0.followee }
    }

    // MARK: - Sync Operations

    /// Fetch follows updated since a given date for incremental sync
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [FollowDTO] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = formatter.string(from: since)

        let queryParams: [String: String] = [
            "select": "*",
            "or": "(follower_id.eq.\(userId.uuidString),followee_id.eq.\(userId.uuidString))",
            "updated_at": "gt.\(sinceString)",
            "order": "updated_at.asc"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let client = await repository.client
        return try await client.execute(request)
    }

    // MARK: - Private Helpers

    private func findExistingFollow(followerId: UUID, followeeId: UUID) async throws -> FollowDTO? {
        let queryParams: [String: String] = [
            "select": "*",
            "follower_id": "eq.\(followerId.uuidString)",
            "followee_id": "eq.\(followeeId.uuidString)",
            "limit": "1"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let client = await repository.client
        let results: [FollowDTO] = try await client.execute(request)
        return results.first
    }
}

// MARK: - Data Transfer Objects

/// DTO for restoring a soft-deleted follow
private struct FollowRestoreRequest: Codable, Sendable {
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

/// DTO for follow with joined profile data (followers query)
struct FollowWithProfileDTO: Codable, Sendable {
    let follower: ProfileSearchResultDTO?
    let followee: ProfileSearchResultDTO?
}
