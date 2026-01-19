import Foundation

/// Climbs table operations
///
/// `ClimbsTable` provides typed operations for the `climbs` table in Supabase.
/// It wraps the generic SupabaseRepository with climb-specific logic.
actor ClimbsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    /// Upsert (insert or update) a climb record
    func upsertClimb(_ dto: ClimbDTO) async throws -> ClimbDTO {
        return try await repository.upsert(
            into: "climbs",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch climbs updated since a given date for incremental sync
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [ClimbDTO] {
        return try await repository.selectUpdatedSince(
            from: "climbs",
            since: since,
            userId: userId
        )
    }

    /// Fetch a specific climb by ID
    func fetchClimb(id: UUID) async throws -> ClimbDTO? {
        let climbs: [ClimbDTO] = try await repository.select(
            from: "climbs",
            where: ["id": id.uuidString],
            limit: 1
        )
        return climbs.first
    }

    /// Soft delete a climb
    func deleteClimb(id: UUID) async throws {
        try await repository.delete(from: "climbs", id: id)
    }
}

// MARK: - Data Transfer Object

struct ClimbDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let sessionId: UUID
    let discipline: String
    let isOutdoor: Bool
    let name: String?
    let gradeOriginal: String?
    let gradeScale: String?
    let gradeScoreMin: Int?
    let gradeScoreMax: Int?
    let openBetaClimbId: String?
    let openBetaAreaId: String?
    let locationDisplay: String?
    let belayPartnerUserId: UUID?
    let belayPartnerName: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case discipline
        case isOutdoor = "is_outdoor"
        case name
        case gradeOriginal = "grade_original"
        case gradeScale = "grade_scale"
        case gradeScoreMin = "grade_score_min"
        case gradeScoreMax = "grade_score_max"
        case openBetaClimbId = "openbeta_climb_id"
        case openBetaAreaId = "openbeta_area_id"
        case locationDisplay = "location_display"
        case belayPartnerUserId = "belay_partner_user_id"
        case belayPartnerName = "belay_partner_name"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
