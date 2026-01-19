import Foundation
import StoreKit

/// Premium subscription management service
///
/// Handles all premium-related operations including:
/// - Checking current premium status
/// - Processing purchases via StoreKit 2
/// - Restoring purchases
/// - Syncing status to Supabase
protocol PremiumServiceProtocol: Sendable {
    /// Check if user has valid premium access (uses local cache)
    func isPremium() async -> Bool

    /// Get detailed premium status
    func getPremiumStatus() async -> PremiumStatusInfo

    /// Verify premium status with StoreKit (network call)
    func verifyPremiumStatus() async throws -> PremiumStatusInfo

    /// Fetch available subscription products
    func fetchProducts() async throws -> [SubscriptionProduct]

    /// Purchase a subscription
    func purchase(_ product: SubscriptionProduct) async throws -> PurchaseResult

    /// Restore previous purchases
    func restorePurchases() async throws -> PremiumStatusInfo

    /// Listen for subscription status changes
    func listenForTransactionUpdates() async
}

/// Premium status information
struct PremiumStatusInfo: Sendable {
    let isPremium: Bool
    let expiresAt: Date?
    let productId: String?
    let isInGracePeriod: Bool
    let willRenew: Bool
}

/// Available subscription product
struct SubscriptionProduct: Sendable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let price: Decimal
    let subscriptionPeriod: SubscriptionPeriod
}

enum SubscriptionPeriod: Sendable {
    case monthly
    case annual
}

enum PurchaseResult: Sendable {
    case success(PremiumStatusInfo)
    case pending
    case cancelled
    case failed(Error)
}
