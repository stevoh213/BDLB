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

    /// Checks if a username (handle) is available for registration.
    ///
    /// This method queries the `profiles` table to determine if a given
    /// handle is already in use by another user. It's designed to be called
    /// during the sign-up flow before the user is authenticated.
    ///
    /// ## Row Level Security (RLS)
    ///
    /// This query requires a special RLS policy on the `profiles` table that
    /// permits unauthenticated SELECT queries filtered by `handle`. This is
    /// safe because:
    /// - Only allows reading `handle` existence (not full profile data)
    /// - Doesn't expose sensitive information
    /// - Required for real-time username availability feedback
    ///
    /// ## Implementation
    ///
    /// The check performs a simple SELECT with a `handle` filter and returns:
    /// - `true` if no profile with that handle exists (available)
    /// - `false` if a profile with that handle exists (taken)
    ///
    /// - Parameter handle: The username to check for availability
    /// - Returns: `true` if available, `false` if taken
    /// - Throws: `NetworkError` if the query fails
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

/// Profile data transfer object for Supabase `profiles` table.
///
/// This DTO includes all profile fields plus premium subscription data.
/// Premium fields are synced from StoreKit 2 to enable:
/// - Cross-device premium status visibility
/// - Support team subscription queries
/// - Server-side analytics
///
/// ## Premium Fields
///
/// The three premium fields are updated by `PremiumSyncImpl` after StoreKit
/// verification:
/// - `premiumExpiresAt`: When subscription expires (nil = free/lifetime)
/// - `premiumProductId`: StoreKit product ID (e.g., "swiftclimb.premium.monthly")
/// - `premiumOriginalTransactionId`: Original transaction ID for support
///
/// - SeeAlso: `PremiumSyncImpl` for the sync implementation.
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

    // Premium subscription fields (synced from StoreKit 2)

    /// When the premium subscription expires.
    ///
    /// - nil: User is on free tier or has lifetime subscription
    /// - Past date: Subscription has expired
    /// - Future date: Active subscription until this date
    let premiumExpiresAt: Date?

    /// StoreKit product identifier for active subscription.
    ///
    /// Examples: "swiftclimb.premium.monthly", "swiftclimb.premium.annual"
    let premiumProductId: String?

    /// Original transaction ID from StoreKit.
    ///
    /// Used by support team to look up subscription details in App Store Connect.
    let premiumOriginalTransactionId: String?

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
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
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
