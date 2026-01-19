import Foundation

/// Social features (follow/feed/kudos/comments)
protocol SocialServiceProtocol: Sendable {
    func followUser(followerId: UUID, followeeId: UUID) async throws
    func unfollowUser(followerId: UUID, followeeId: UUID) async throws
    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool

    func createPost(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws -> SCPost

    func getFeed(userId: UUID, limit: Int) async -> [SCPost]

    func addKudos(postId: UUID, userId: UUID) async throws
    func removeKudos(postId: UUID, userId: UUID) async throws

    func addComment(postId: UUID, authorId: UUID, content: String) async throws -> SCComment
    func getComments(postId: UUID) async -> [SCComment]
}

// Stub implementation
final class SocialService: SocialServiceProtocol, @unchecked Sendable {
    func followUser(followerId: UUID, followeeId: UUID) async throws {
        // TODO: Implement follow
    }

    func unfollowUser(followerId: UUID, followeeId: UUID) async throws {
        // TODO: Implement unfollow
    }

    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool {
        // TODO: Implement following check
        return false
    }

    func createPost(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws -> SCPost {
        // TODO: Implement post creation
        fatalError("Not implemented")
    }

    func getFeed(userId: UUID, limit: Int) async -> [SCPost] {
        // TODO: Implement feed retrieval
        return []
    }

    func addKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement kudos addition
    }

    func removeKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement kudos removal
    }

    func addComment(postId: UUID, authorId: UUID, content: String) async throws -> SCComment {
        // TODO: Implement comment addition
        fatalError("Not implemented")
    }

    func getComments(postId: UUID) async -> [SCComment] {
        // TODO: Implement comment retrieval
        return []
    }
}
