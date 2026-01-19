import SwiftData
import Foundation

// MARK: - Tag Definitions

@Model
final class SCTechniqueTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship
    var impacts: [SCTechniqueImpact]

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        impacts: [SCTechniqueImpact] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.impacts = impacts
    }
}

@Model
final class SCSkillTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship
    var impacts: [SCSkillImpact]

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        impacts: [SCSkillImpact] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.impacts = impacts
    }
}

@Model
final class SCWallStyleTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship
    var impacts: [SCWallStyleImpact]

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        impacts: [SCWallStyleImpact] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.impacts = impacts
    }
}

// MARK: - Tag Impacts

@Model
final class SCTechniqueImpact {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var climbId: UUID
    var tagId: UUID
    var impact: TagImpact
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCClimb.techniqueImpacts)
    var climb: SCClimb?

    @Relationship(inverse: \SCTechniqueTag.impacts)
    var tag: SCTechniqueTag?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climb: SCClimb? = nil,
        tag: SCTechniqueTag? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.climbId = climbId
        self.tagId = tagId
        self.impact = impact
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.climb = climb
        self.tag = tag
        self.needsSync = needsSync
    }
}

@Model
final class SCSkillImpact {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var climbId: UUID
    var tagId: UUID
    var impact: TagImpact
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCClimb.skillImpacts)
    var climb: SCClimb?

    @Relationship(inverse: \SCSkillTag.impacts)
    var tag: SCSkillTag?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climb: SCClimb? = nil,
        tag: SCSkillTag? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.climbId = climbId
        self.tagId = tagId
        self.impact = impact
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.climb = climb
        self.tag = tag
        self.needsSync = needsSync
    }
}

@Model
final class SCWallStyleImpact {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var climbId: UUID
    var tagId: UUID
    var impact: TagImpact
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCClimb.wallStyleImpacts)
    var climb: SCClimb?

    @Relationship(inverse: \SCWallStyleTag.impacts)
    var tag: SCWallStyleTag?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climb: SCClimb? = nil,
        tag: SCWallStyleTag? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.climbId = climbId
        self.tagId = tagId
        self.impact = impact
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.climb = climb
        self.tag = tag
        self.needsSync = needsSync
    }
}
