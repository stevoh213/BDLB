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

    /// Search profiles by handle or display name
    ///
    /// Performs a partial match search on both `handle` and `display_name` columns.
    /// Only returns public profiles. Results are ordered by relevance (exact matches first,
    /// then alphabetically).
    ///
    /// ## RLS Considerations
    ///
    /// This query relies on the `profiles_select_public` RLS policy that allows
    /// reading profiles where `is_public = true` or the profile belongs to the
    /// current user.
    ///
    /// - Parameters:
    ///   - query: Search string (minimum 2 characters)
    ///   - limit: Maximum results to return (default 20, max 50)
    /// - Returns: Array of matching profile DTOs
    /// - Throws: NetworkError if query fails
    func searchProfiles(query: String, limit: Int = 20) async throws -> [ProfileSearchResultDTO] {
        // Enforce reasonable limits
        let effectiveLimit = min(max(limit, 1), 50)

        // Supabase uses PostgREST ilike for case-insensitive partial matching
        // We search both handle and display_name
        let searchPattern = "%\(query)%"

        // Build query params for OR condition
        // PostgREST syntax: or=(handle.ilike.*query*,display_name.ilike.*query*)
        let queryParams: [String: String] = [
            "select": "id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count",
            "or": "(handle.ilike.\(searchPattern),display_name.ilike.\(searchPattern))",
            "is_public": "eq.true",
            "order": "handle.asc",
            "limit": "\(effectiveLimit)"
        ]

        let request = SupabaseRequest(
            path: "/profiles",
            method: "GET",
            queryParams: queryParams
        )

        // Note: Search requires auth to prevent abuse, but returns only public profiles
        let client = await repository.client
        return try await client.execute(request, requiresAuth: true)
    }
}

// MARK: - Data Transfer Object

/// Profile data transfer object for Supabase `profiles` table.
///
/// This DTO includes all profile fields including:
/// - Core identity (id, handle, photo)
/// - Social profile (display_name, bio, home_gym, etc.)
/// - Cached counts (follower_count, following_count, send_count)
/// - Premium subscription data
///
/// ## Social Profile Fields
///
/// The social profile fields enable the social features:
/// - `displayName`: User-facing name (can differ from @handle)
/// - `bio`: Short biography (max 280 chars)
/// - `homeGym`: Home gym or crag name
/// - `climbingSince`: When user started climbing
/// - `favoriteStyle`: Preferred climbing style
///
/// ## Cached Counts
///
/// Counts are maintained by database triggers for performance:
/// - `followerCount`: Updated by follows table trigger
/// - `followingCount`: Updated by follows table trigger
/// - `sendCount`: Updated by attempts table trigger
///
/// ## Premium Fields
///
/// The three premium fields are updated by `PremiumSyncImpl` after StoreKit
/// verification:
/// - `premiumExpiresAt`: When subscription expires (nil = free/lifetime)
/// - `premiumProductId`: StoreKit product ID (e.g., "swiftclimb.premium.monthly")
/// - `premiumOriginalTransactionId`: Original transaction ID for support
///
/// - SeeAlso: `ProfileUpdateRequest` for partial updates.
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

    // Social profile fields
    let displayName: String?
    let bio: String?
    let homeGym: String?
    let climbingSince: Date?
    let favoriteStyle: String?

    // Cached counts (read-only from app perspective)
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int

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
        // Social profile fields
        case displayName = "display_name"
        case bio
        case homeGym = "home_gym"
        case climbingSince = "climbing_since"
        case favoriteStyle = "favorite_style"
        // Cached counts
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case sendCount = "send_count"
        // Premium fields
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}

// MARK: - Update Request

/// Request object for updating profile fields.
///
/// Only include fields that should be updated. Nil fields are not sent to the server.
/// Note: Cached counts (follower_count, following_count, send_count) are read-only
/// and maintained by database triggers.
struct ProfileUpdateRequest: Codable, Sendable {
    let handle: String?
    let photoURL: String?
    let homeZIP: String?
    let preferredGradeScaleBoulder: String?
    let preferredGradeScaleRoute: String?
    let isPublic: Bool?
    // Social profile fields
    let displayName: String?
    let bio: String?
    let homeGym: String?
    let climbingSince: Date?
    let favoriteStyle: String?
    // Timestamp
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case handle
        case photoURL = "photo_url"
        case homeZIP = "home_zip"
        case preferredGradeScaleBoulder = "preferred_grade_scale_boulder"
        case preferredGradeScaleRoute = "preferred_grade_scale_route"
        case isPublic = "is_public"
        // Social profile fields
        case displayName = "display_name"
        case bio
        case homeGym = "home_gym"
        case climbingSince = "climbing_since"
        case favoriteStyle = "favorite_style"
        // Timestamp
        case updatedAt = "updated_at"
    }

    init(
        handle: String? = nil,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: String? = nil,
        preferredGradeScaleRoute: String? = nil,
        isPublic: Bool? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil
    ) {
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
        self.updatedAt = Date()
    }
}

// MARK: - Profile Search Result DTO

/// Lightweight DTO for profile search results
///
/// Contains only the fields needed for displaying search results and profile previews.
/// Does not include premium status or grade preferences.
struct ProfileSearchResultDTO: Codable, Sendable {
    let id: UUID
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let isPublic: Bool
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case displayName = "display_name"
        case photoURL = "photo_url"
        case bio
        case isPublic = "is_public"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case sendCount = "send_count"
    }
}
