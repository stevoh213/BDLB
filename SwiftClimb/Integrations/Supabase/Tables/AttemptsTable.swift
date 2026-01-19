import Foundation

/// Attempts table operations
///
/// `AttemptsTable` provides typed operations for the `attempts` table in Supabase.
/// It wraps the generic SupabaseRepository with attempt-specific logic.
actor AttemptsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    /// Upsert (insert or update) an attempt record
    func upsertAttempt(_ dto: AttemptDTO) async throws -> AttemptDTO {
        return try await repository.upsert(
            into: "attempts",
            values: dto,
            onConflict: "id"
        )
    }

    /// Fetch attempts updated since a given date for incremental sync
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [AttemptDTO] {
        return try await repository.selectUpdatedSince(
            from: "attempts",
            since: since,
            userId: userId
        )
    }

    /// Fetch a specific attempt by ID
    func fetchAttempt(id: UUID) async throws -> AttemptDTO? {
        let attempts: [AttemptDTO] = try await repository.select(
            from: "attempts",
            where: ["id": id.uuidString],
            limit: 1
        )
        return attempts.first
    }

    /// Soft delete an attempt
    func deleteAttempt(id: UUID) async throws {
        try await repository.delete(from: "attempts", id: id)
    }
}

// MARK: - Data Transfer Object

struct AttemptDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let sessionId: UUID
    let climbId: UUID
    let attemptNumber: Int
    let outcome: String
    let sendType: String?
    let occurredAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case climbId = "climb_id"
        case attemptNumber = "attempt_number"
        case outcome
        case sendType = "send_type"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
