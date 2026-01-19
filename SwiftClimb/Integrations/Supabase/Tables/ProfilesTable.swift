import Foundation

/// Profiles table operations
actor ProfilesTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    /// Fetch profile by user ID
    func fetchProfile(userId: UUID) async throws -> ProfileDTO? {
        let profiles: [ProfileDTO] = try await repository.select(
            from: "profiles",
            where: ["id": userId.uuidString],
            limit: 1
        )
        return profiles.first
    }

    /// Create a new profile
    func createProfile(_ dto: ProfileDTO) async throws -> ProfileDTO {
        return try await repository.insert(
            into: "profiles",
            values: dto
        )
    }

    /// Upsert (insert or update) a profile
    func upsertProfile(_ dto: ProfileDTO) async throws -> ProfileDTO {
        return try await repository.upsert(
            into: "profiles",
            values: dto,
            onConflict: "id"
        )
    }

    /// Update specific fields of a profile
    func updateProfile(userId: UUID, updates: ProfileUpdateRequest) async throws -> ProfileDTO {
        return try await repository.update(
            table: "profiles",
            id: userId,
            values: updates
        )
    }

    /// Check if a handle is available (not taken by another user)
    /// Note: This is called before auth, so it uses unauthenticated access
    func checkHandleAvailable(handle: String) async throws -> Bool {
        let profiles: [ProfileDTO] = try await repository.select(
            from: "profiles",
            where: ["handle": handle],
            limit: 1,
            requiresAuth: false  // Allow check before user is authenticated
        )
        return profiles.isEmpty
    }

    /// Fetch profiles updated since a specific date
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [ProfileDTO] {
        return try await repository.selectUpdatedSince(
            from: "profiles",
            since: since,
            userId: userId
        )
    }
}

// MARK: - Data Transfer Object

struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let handle: String
    let photoURL: String?
    let homeZIP: String?
    let preferredGradeScaleBoulder: String
    let preferredGradeScaleRoute: String
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case photoURL = "photo_url"
        case homeZIP = "home_zip"
        case preferredGradeScaleBoulder = "preferred_grade_scale_boulder"
        case preferredGradeScaleRoute = "preferred_grade_scale_route"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Update Request

struct ProfileUpdateRequest: Codable, Sendable {
    let handle: String?
    let photoURL: String?
    let homeZIP: String?
    let preferredGradeScaleBoulder: String?
    let preferredGradeScaleRoute: String?
    let isPublic: Bool?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case handle
        case photoURL = "photo_url"
        case homeZIP = "home_zip"
        case preferredGradeScaleBoulder = "preferred_grade_scale_boulder"
        case preferredGradeScaleRoute = "preferred_grade_scale_route"
        case isPublic = "is_public"
        case updatedAt = "updated_at"
    }

    init(
        handle: String? = nil,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: String? = nil,
        preferredGradeScaleRoute: String? = nil,
        isPublic: Bool? = nil
    ) {
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.updatedAt = Date()
    }
}
