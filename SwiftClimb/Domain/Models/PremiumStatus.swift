import SwiftData
import Foundation

/// Local cache of premium subscription status.
///
/// This model stores the user's premium entitlement locally for offline access.
/// The source of truth is StoreKit 2, but this cache enables:
/// - Instant premium status checks without async StoreKit calls
/// - Offline premium access with grace period
/// - UI responsiveness (no loading states for premium checks)
///
/// ## Sync Strategy
///
/// 1. On app launch: Verify with StoreKit, update cache
/// 2. On purchase: Immediately update cache, sync to Supabase
/// 3. On subscription change notification: Re-verify and update
/// 4. Offline: Trust cache if within grace period
@Model
final class SCPremiumStatus {
    @Attribute(.unique) var id: UUID
    var userId: UUID

    /// Whether user currently has premium access
    var isPremium: Bool

    /// When the current subscription expires (nil if lifetime or free)
    var expiresAt: Date?

    /// Last time we verified with StoreKit
    var lastVerifiedAt: Date

    /// Original transaction ID from StoreKit (for server validation)
    var originalTransactionId: String?

    /// Product ID of active subscription
    var productId: String?

    /// Grace period for offline access (7 days after last verification)
    var offlineGraceExpiresAt: Date

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        isPremium: Bool = false,
        expiresAt: Date? = nil,
        lastVerifiedAt: Date = Date(),
        originalTransactionId: String? = nil,
        productId: String? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.isPremium = isPremium
        self.expiresAt = expiresAt
        self.lastVerifiedAt = lastVerifiedAt
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.offlineGraceExpiresAt = lastVerifiedAt.addingTimeInterval(7 * 24 * 60 * 60)
        self.needsSync = needsSync
    }
}

extension SCPremiumStatus {
    /// Check if premium is valid considering expiry and grace period
    var isValidPremium: Bool {
        guard isPremium else { return false }

        // If no expiry, it's a lifetime purchase
        guard let expiresAt = expiresAt else { return true }

        // Check if subscription is still active
        if expiresAt > Date() {
            return true
        }

        // Check offline grace period
        return offlineGraceExpiresAt > Date()
    }
}
