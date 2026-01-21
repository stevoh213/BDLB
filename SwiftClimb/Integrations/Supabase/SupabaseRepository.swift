import Foundation

/// Generic CRUD operations for Supabase tables
///
/// `SupabaseRepository` provides a type-safe interface for interacting with
/// Supabase tables via the REST API. It handles request construction, JSON
/// encoding/decoding, and authentication via SupabaseClientActor.
///
/// ## Operations
///
/// - **select**: Query records with filters, ordering, and limits
/// - **insert**: Create new records
/// - **update**: Update existing records by ID
/// - **upsert**: Insert or update based on conflict
/// - **delete**: Soft delete via deleted_at timestamp
/// - **selectUpdatedSince**: Fetch records for incremental sync
///
/// ## Usage
///
/// ```swift
/// let repository = SupabaseRepository(client: supabaseClient)
///
/// // Fetch all sessions for user
/// let sessions: [SessionDTO] = try await repository.select(
///     from: "sessions",
///     where: ["user_id": userId.uuidString]
/// )
///
/// // Insert new session
/// let newSession: SessionDTO = try await repository.insert(
///     into: "sessions",
///     values: sessionDTO
/// )
/// ```
actor SupabaseRepository {
    private let _client: SupabaseClientActor

    /// Exposed client for direct request execution (used by table actors for complex queries)
    var client: SupabaseClientActor {
        _client
    }

    init(client: SupabaseClientActor) {
        self._client = client
    }

    // MARK: - CRUD Operations

    /// Select records from a table with optional filters
    func select<T: Decodable & Sendable>(
        from table: String,
        where conditions: [String: String]? = nil,
        orderBy: String? = nil,
        limit: Int? = nil,
        requiresAuth: Bool = true
    ) async throws -> [T] {
        var queryParams: [String: String] = [:]

        // Add select=* to get all columns
        queryParams["select"] = "*"

        // Build filter conditions
        if let conditions = conditions {
            for (key, value) in conditions {
                queryParams[key] = "eq.\(value)"
            }
        }

        // Add ordering
        if let orderBy = orderBy {
            queryParams["order"] = orderBy
        }

        // Add limit
        if let limit = limit {
            queryParams["limit"] = "\(limit)"
        }

        let request = SupabaseRequest(
            path: "/\(table)",
            method: "GET",
            queryParams: queryParams
        )

        return try await _client.execute(request, requiresAuth: requiresAuth)
    }

    /// Insert a new record into a table
    func insert<T: Encodable & Sendable, R: Decodable & Sendable>(
        into table: String,
        values: T
    ) async throws -> R {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let body = try encoder.encode(values)

        let request = SupabaseRequest(
            path: "/\(table)",
            method: "POST",
            body: body,
            queryParams: ["select": "*"]
        )

        // Supabase returns an array, take first element
        let result: [R] = try await _client.execute(request)
        guard let first = result.first else {
            throw NetworkError.serverError("Insert returned no data")
        }
        return first
    }

    /// Update an existing record by ID
    func update<T: Encodable & Sendable, R: Decodable & Sendable>(
        table: String,
        id: UUID,
        values: T
    ) async throws -> R {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let body = try encoder.encode(values)

        let request = SupabaseRequest(
            path: "/\(table)",
            method: "PATCH",
            body: body,
            queryParams: [
                "id": "eq.\(id.uuidString)",
                "select": "*"
            ]
        )

        // Supabase returns an array, take first element
        let result: [R] = try await _client.execute(request)
        guard let first = result.first else {
            throw NetworkError.serverError("Update returned no data")
        }
        return first
    }

    /// Upsert (insert or update) a record
    func upsert<T: Encodable & Sendable, R: Decodable & Sendable>(
        into table: String,
        values: T,
        onConflict: String = "id"
    ) async throws -> R {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let body = try encoder.encode(values)

        // Note: resolution=merge-duplicates is handled in SupabaseClientActor
        // via the Prefer header when on_conflict is present
        let request = SupabaseRequest(
            path: "/\(table)",
            method: "POST",
            body: body,
            queryParams: [
                "on_conflict": onConflict,
                "select": "*"
            ],
            isUpsert: true
        )

        print("[SupabaseRepository] Upserting to \(table), body size: \(body.count) bytes")

        // Supabase returns an array, take first element
        let result: [R] = try await _client.execute(request)
        guard let first = result.first else {
            throw NetworkError.serverError("Upsert returned no data")
        }
        print("[SupabaseRepository] Upsert to \(table) successful")
        return first
    }

    /// Soft delete a record (set deleted_at timestamp)
    func delete(
        from table: String,
        id: UUID
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let deleteBody = ["deleted_at": now]

        let encoder = JSONEncoder()
        let body = try encoder.encode(deleteBody)

        let request = SupabaseRequest(
            path: "/\(table)",
            method: "PATCH",
            body: body,
            queryParams: ["id": "eq.\(id.uuidString)"]
        )

        // Execute but ignore response
        let _: [EmptyResponse] = try await client.execute(request)
    }

    // MARK: - Sync Operations

    /// Fetch records updated since a timestamp for incremental sync
    func selectUpdatedSince<T: Decodable & Sendable>(
        from table: String,
        since: Date,
        userId: UUID
    ) async throws -> [T] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = formatter.string(from: since)

        let queryParams: [String: String] = [
            "select": "*",
            "user_id": "eq.\(userId.uuidString)",
            "updated_at": "gt.\(sinceString)",
            "order": "updated_at.asc"
        ]

        let request = SupabaseRequest(
            path: "/\(table)",
            method: "GET",
            queryParams: queryParams
        )

        return try await client.execute(request)
    }
}

// MARK: - Supporting Types

private struct EmptyResponse: Codable, Sendable {}
