import Foundation

/// Tag tables operations
actor TagsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    // MARK: - Tag Definitions

    func fetchTechniqueTags() async throws -> [TagDTO] {
        // TODO: Fetch all technique tags
        return []
    }

    func fetchSkillTags() async throws -> [TagDTO] {
        // TODO: Fetch all skill tags
        return []
    }

    func fetchWallStyleTags() async throws -> [TagDTO] {
        // TODO: Fetch all wall style tags
        return []
    }

    // MARK: - Tag Impacts

    func upsertTechniqueImpact(_ dto: TagImpactDTO) async throws -> TagImpactDTO {
        // TODO: Insert or update technique impact
        fatalError("Not implemented")
    }

    func upsertSkillImpact(_ dto: TagImpactDTO) async throws -> TagImpactDTO {
        // TODO: Insert or update skill impact
        fatalError("Not implemented")
    }

    func upsertWallStyleImpact(_ dto: TagImpactDTO) async throws -> TagImpactDTO {
        // TODO: Insert or update wall style impact
        fatalError("Not implemented")
    }

    func fetchImpactsUpdatedSince(since: Date, userId: UUID) async throws -> [TagImpactDTO] {
        // TODO: Fetch impacts updated since date
        return []
    }
}

// MARK: - Data Transfer Objects

struct TagDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let category: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TagImpactDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let climbId: UUID
    let tagId: UUID
    let impact: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case climbId = "climb_id"
        case tagId = "tag_id"
        case impact
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
