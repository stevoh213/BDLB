import Foundation

/// Sessions table operations
///
/// `SessionsTable` provides typed operations for the `sessions` table in Supabase.
/// It wraps the generic SupabaseRepository with session-specific logic.
actor SessionsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    /// Upsert (insert or update) a session record
    func upsertSession(_ dto: SessionDTO) async throws -> SessionDTO {
        return try await repository.upsert(
            into: "sessions",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch sessions updated since a given date for incremental sync
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [SessionDTO] {
        return try await repository.selectUpdatedSince(
            from: "sessions",
            since: since,
            userId: userId
        )
    }

    /// Fetch a specific session by ID
    func fetchSession(id: UUID) async throws -> SessionDTO? {
        let sessions: [SessionDTO] = try await repository.select(
            from: "sessions",
            where: ["id": id.uuidString],
            limit: 1
        )
        return sessions.first
    }

    /// Soft delete a session
    func deleteSession(id: UUID) async throws {
        try await repository.delete(from: "sessions", id: id)
    }
}

// MARK: - Data Transfer Object

struct SessionDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    let endedAt: Date?
    let mentalReadiness: Int?
    let physicalReadiness: Int?
    let rpe: Int?
    let pumpLevel: Int?
    let notes: String?
    let isPrivate: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case mentalReadiness = "mental_readiness"
        case physicalReadiness = "physical_readiness"
        case rpe
        case pumpLevel = "pump_level"
        case notes
        case isPrivate = "is_private"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
