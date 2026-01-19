import SwiftData
import Foundation

// MARK: - Post

@Model
final class SCPost {
    @Attribute(.unique) var id: UUID
    var authorId: UUID
    var sessionId: UUID?
    var climbId: UUID?
    var content: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade)
    var kudos: [SCKudos]

    @Relationship(deleteRule: .cascade)
    var comments: [SCComment]

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        authorId: UUID,
        sessionId: UUID? = nil,
        climbId: UUID? = nil,
        content: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        kudos: [SCKudos] = [],
        comments: [SCComment] = [],
        needsSync: Bool = true
    ) {
        self.id = id
        self.authorId = authorId
        self.sessionId = sessionId
        self.climbId = climbId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.kudos = kudos
        self.comments = comments
        self.needsSync = needsSync
    }
}

extension SCPost {
    var kudosCount: Int {
        return kudos.count
    }

    var commentCount: Int {
        return comments.count
    }
}

// MARK: - Follow

@Model
final class SCFollow {
    @Attribute(.unique) var id: UUID
    var followerId: UUID
    var followeeId: UUID
    var createdAt: Date
    var deletedAt: Date?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        followerId: UUID,
        followeeId: UUID,
        createdAt: Date = Date(),
        deletedAt: Date? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.followerId = followerId
        self.followeeId = followeeId
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.needsSync = needsSync
    }
}

// MARK: - Kudos

@Model
final class SCKudos {
    @Attribute(.unique) var id: UUID
    var postId: UUID
    var userId: UUID
    var createdAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCPost.kudos)
    var post: SCPost?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        postId: UUID,
        userId: UUID,
        createdAt: Date = Date(),
        deletedAt: Date? = nil,
        post: SCPost? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.post = post
        self.needsSync = needsSync
    }
}

// MARK: - Comment

@Model
final class SCComment {
    @Attribute(.unique) var id: UUID
    var postId: UUID
    var authorId: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCPost.comments)
    var post: SCPost?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        postId: UUID,
        authorId: UUID,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        post: SCPost? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.post = post
        self.needsSync = needsSync
    }
}
