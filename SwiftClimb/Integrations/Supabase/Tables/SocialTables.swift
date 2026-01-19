import Foundation

/// Social tables operations (follows, posts, kudos, comments)
actor SocialTables {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    // MARK: - Follows

    func upsertFollow(_ dto: FollowDTO) async throws -> FollowDTO {
        // TODO: Insert or update follow relationship
        fatalError("Not implemented")
    }

    func fetchFollows(userId: UUID) async throws -> [FollowDTO] {
        // TODO: Fetch user follows
        return []
    }

    // MARK: - Posts

    func upsertPost(_ dto: PostDTO) async throws -> PostDTO {
        // TODO: Insert or update post
        fatalError("Not implemented")
    }

    func fetchFeed(userId: UUID, limit: Int) async throws -> [PostDTO] {
        // TODO: Fetch feed posts
        return []
    }

    // MARK: - Kudos

    func upsertKudos(_ dto: KudosDTO) async throws -> KudosDTO {
        // TODO: Insert or update kudos
        fatalError("Not implemented")
    }

    // MARK: - Comments

    func upsertComment(_ dto: CommentDTO) async throws -> CommentDTO {
        // TODO: Insert or update comment
        fatalError("Not implemented")
    }

    func fetchComments(postId: UUID) async throws -> [CommentDTO] {
        // TODO: Fetch post comments
        return []
    }
}

// MARK: - Data Transfer Objects

struct FollowDTO: Codable, Sendable {
    let id: UUID
    let followerId: UUID
    let followeeId: UUID
    let createdAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followeeId = "followee_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

struct PostDTO: Codable, Sendable {
    let id: UUID
    let authorId: UUID
    let sessionId: UUID?
    let climbId: UUID?
    let content: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case sessionId = "session_id"
        case climbId = "climb_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct KudosDTO: Codable, Sendable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let createdAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

struct CommentDTO: Codable, Sendable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
