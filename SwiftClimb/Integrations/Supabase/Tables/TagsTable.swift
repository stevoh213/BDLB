import Foundation

/// Tag tables operations for sync
actor TagsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    // MARK: - Technique Impacts

    /// Upsert (insert or update) a technique impact record
    func upsertTechniqueImpact(_ dto: TechniqueImpactDTO) async throws -> TechniqueImpactDTO {
        return try await repository.upsert(
            into: "technique_impacts",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch technique impacts updated since a given date for incremental sync
    func fetchTechniqueImpactsUpdatedSince(since: Date, userId: UUID) async throws -> [TechniqueImpactDTO] {
        return try await repository.selectUpdatedSince(
            from: "technique_impacts",
            since: since,
            userId: userId
        )
    }

    // MARK: - Skill Impacts

    /// Upsert (insert or update) a skill impact record
    func upsertSkillImpact(_ dto: SkillImpactDTO) async throws -> SkillImpactDTO {
        return try await repository.upsert(
            into: "skill_impacts",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch skill impacts updated since a given date for incremental sync
    func fetchSkillImpactsUpdatedSince(since: Date, userId: UUID) async throws -> [SkillImpactDTO] {
        return try await repository.selectUpdatedSince(
            from: "skill_impacts",
            since: since,
            userId: userId
        )
    }

    // MARK: - Wall Style Impacts

    /// Upsert (insert or update) a wall style impact record
    func upsertWallStyleImpact(_ dto: WallStyleImpactDTO) async throws -> WallStyleImpactDTO {
        return try await repository.upsert(
            into: "wall_style_impacts",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch wall style impacts updated since a given date for incremental sync
    func fetchWallStyleImpactsUpdatedSince(since: Date, userId: UUID) async throws -> [WallStyleImpactDTO] {
        return try await repository.selectUpdatedSince(
            from: "wall_style_impacts",
            since: since,
            userId: userId
        )
    }
}

// MARK: - Data Transfer Objects

struct TechniqueImpactDTO: Codable, Sendable {
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

struct SkillImpactDTO: Codable, Sendable {
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

struct WallStyleImpactDTO: Codable, Sendable {
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
