import Foundation

/// Protocol for syncing premium subscription status to Supabase.
///
/// This protocol defines operations for synchronizing premium subscription data
/// from StoreKit 2 to the Supabase backend. This enables:
/// - Cross-device premium status visibility
/// - Support team access to subscription data
/// - Server-side premium feature gating (future)
///
/// ## Architecture
///
/// The sync occurs **non-blocking** after StoreKit verification to maintain
/// the offline-first architecture. Premium status is always determined locally
/// via StoreKit first, with Supabase serving as a secondary source for:
/// - Multi-device consistency
/// - Support team queries
/// - Analytics
///
/// ## Sync Flow
///
/// ```
/// StoreKit 2 Verification
///        ↓
/// Update Local Cache (SCPremiumStatus)
///        ↓
/// Non-blocking: syncPremiumStatus() → Supabase
/// ```
///
/// - Note: All methods are actor-isolated for thread safety.
/// - SeeAlso: `PremiumServiceImpl` for the StoreKit integration.
protocol PremiumSyncProtocol: Sendable {
    /// Syncs premium subscription status to Supabase profiles table.
    ///
    /// Updates the user's profile record with current subscription information
    /// from StoreKit. This operation is non-blocking and failures do not affect
    /// local premium status.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier.
    ///   - isPremium: Whether the user currently has premium access.
    ///   - expiresAt: When the subscription expires (nil for lifetime).
    ///   - productId: StoreKit product identifier (e.g., "swiftclimb.premium.monthly").
    ///   - transactionId: Original transaction ID from StoreKit for support queries.
    ///
    /// - Throws: `NetworkError` if the Supabase update fails.
    ///
    /// - Note: Called non-blocking from `PremiumServiceImpl.verifyPremiumStatus()`.
    func syncPremiumStatus(
        userId: UUID,
        isPremium: Bool,
        expiresAt: Date?,
        productId: String?,
        transactionId: String?
    ) async throws

    /// Fetches premium status from Supabase backend.
    ///
    /// Retrieves subscription data stored in the profiles table. This is typically
    /// used for:
    /// - Conflict resolution during sync
    /// - Recovery when local cache is missing
    /// - Support team queries
    ///
    /// - Parameter userId: The user's unique identifier.
    ///
    /// - Returns: Remote premium status if found, nil if user has no profile.
    ///
    /// - Throws: `NetworkError` if the query fails.
    func fetchRemotePremiumStatus(userId: UUID) async throws -> RemotePremiumStatus?
}

/// Remote premium subscription status from Supabase.
///
/// Represents subscription data stored in the `profiles` table, excluding
/// local-only fields like grace period and last verification time.
struct RemotePremiumStatus: Sendable {
    /// When the subscription expires (nil = free user or lifetime).
    let expiresAt: Date?

    /// StoreKit product identifier (e.g., "swiftclimb.premium.monthly").
    let productId: String?
}

/// Supabase implementation of premium subscription sync.
///
/// This actor handles all communication with the Supabase backend for
/// premium subscription data. It updates the `profiles` table with
/// StoreKit subscription information.
///
/// ## Database Schema
///
/// Updates three columns in the `profiles` table:
/// - `premium_expires_at` (TIMESTAMPTZ) - Subscription expiry date
/// - `premium_product_id` (TEXT) - StoreKit product ID
/// - `premium_original_transaction_id` (TEXT) - Original transaction ID
///
/// ## Usage
///
/// ```swift
/// let sync = PremiumSyncImpl(repository: supabaseRepository)
///
/// // Sync after StoreKit verification
/// try await sync.syncPremiumStatus(
///     userId: userId,
///     isPremium: true,
///     expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
///     productId: "swiftclimb.premium.monthly",
///     transactionId: "1234567890"
/// )
///
/// // Fetch remote status
/// if let remoteStatus = try await sync.fetchRemotePremiumStatus(userId: userId) {
///     print("Remote expiry: \(remoteStatus.expiresAt)")
/// }
/// ```
///
/// - Note: All operations are actor-isolated for thread safety.
actor PremiumSyncImpl: PremiumSyncProtocol {
    private let repository: SupabaseRepository

    /// Creates a premium sync implementation.
    ///
    /// - Parameter repository: The Supabase repository for database operations.
    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    func syncPremiumStatus(
        userId: UUID,
        isPremium: Bool,
        expiresAt: Date?,
        productId: String?,
        transactionId: String?
    ) async throws {
        let updates = PremiumUpdateRequest(
            premiumExpiresAt: expiresAt,
            premiumProductId: productId,
            premiumOriginalTransactionId: transactionId
        )

        // Update profiles table with current subscription info
        let _: ProfileDTO = try await repository.update(
            table: "profiles",
            id: userId,
            values: updates
        )
    }

    func fetchRemotePremiumStatus(userId: UUID) async throws -> RemotePremiumStatus? {
        let profiles: [ProfileDTO] = try await repository.select(
            from: "profiles",
            where: ["id": userId.uuidString],
            limit: 1
        )

        guard let profile = profiles.first else { return nil }

        return RemotePremiumStatus(
            expiresAt: profile.premiumExpiresAt,
            productId: profile.premiumProductId
        )
    }
}

/// Request payload for updating premium fields in Supabase profiles table.
///
/// This struct maps Swift camelCase properties to PostgreSQL snake_case columns
/// via the `CodingKeys` enum. It only includes premium-related fields that can
/// be updated independently from the rest of the profile.
///
/// ## Database Mapping
///
/// - `premiumExpiresAt` → `premium_expires_at` (TIMESTAMPTZ)
/// - `premiumProductId` → `premium_product_id` (TEXT)
/// - `premiumOriginalTransactionId` → `premium_original_transaction_id` (TEXT)
///
/// - Note: All fields are optional to support partial updates.
struct PremiumUpdateRequest: Codable, Sendable {
    /// When the subscription expires (nil = free user or lifetime).
    let premiumExpiresAt: Date?

    /// StoreKit product identifier.
    let premiumProductId: String?

    /// Original transaction ID for support queries.
    let premiumOriginalTransactionId: String?

    enum CodingKeys: String, CodingKey {
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}
