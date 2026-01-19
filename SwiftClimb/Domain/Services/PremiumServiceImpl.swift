import Foundation
import StoreKit
import SwiftData

/// StoreKit 2-based premium service implementation
///
/// Uses @MainActor isolation because it interacts with SwiftData's ModelContext,
/// which is MainActor-isolated. StoreKit 2 operations are async and work fine
/// from MainActor context.
@MainActor
final class PremiumServiceImpl: PremiumServiceProtocol {
    private let modelContext: ModelContext
    private let userId: UUID
    private let supabaseSync: PremiumSyncProtocol?

    // Product identifiers
    static let monthlyProductId = "com.swiftclimb.premium.monthly"
    static let annualProductId = "com.swiftclimb.premium.annual"

    init(
        modelContext: ModelContext,
        userId: UUID,
        supabaseSync: PremiumSyncProtocol? = nil
    ) {
        self.modelContext = modelContext
        self.userId = userId
        self.supabaseSync = supabaseSync
    }

    // MARK: - Status Checks

    func isPremium() async -> Bool {
        // Fast path: check local cache
        if let cachedStatus = try? await getCachedStatus() {
            return cachedStatus.isValidPremium
        }
        return false
    }

    func getPremiumStatus() async -> PremiumStatusInfo {
        if let cached = try? await getCachedStatus() {
            return PremiumStatusInfo(
                isPremium: cached.isValidPremium,
                expiresAt: cached.expiresAt,
                productId: cached.productId,
                isInGracePeriod: cached.isPremium &&
                    (cached.expiresAt ?? .distantFuture) < Date() &&
                    cached.offlineGraceExpiresAt > Date(),
                willRenew: false // Would need StoreKit check
            )
        }
        return PremiumStatusInfo(
            isPremium: false,
            expiresAt: nil,
            productId: nil,
            isInGracePeriod: false,
            willRenew: false
        )
    }

    func verifyPremiumStatus() async throws -> PremiumStatusInfo {
        // Check StoreKit for current entitlements
        var isPremium = false
        var expiresAt: Date?
        var productId: String?
        var transactionId: String?
        var willRenew = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlyProductId ||
                   transaction.productID == Self.annualProductId {
                    isPremium = true
                    expiresAt = transaction.expirationDate
                    productId = transaction.productID
                    transactionId = String(transaction.originalID)

                    // Check renewal status
                    if let status = await transaction.subscriptionStatus {
                        willRenew = status.state == .subscribed
                    }
                }
            }
        }

        // Update local cache
        try await updateCachedStatus(
            isPremium: isPremium,
            expiresAt: expiresAt,
            productId: productId,
            transactionId: transactionId
        )

        // Sync to Supabase (non-blocking)
        if let sync = supabaseSync {
            Task {
                try? await sync.syncPremiumStatus(
                    userId: userId,
                    isPremium: isPremium,
                    expiresAt: expiresAt,
                    productId: productId,
                    transactionId: transactionId
                )
            }
        }

        return PremiumStatusInfo(
            isPremium: isPremium,
            expiresAt: expiresAt,
            productId: productId,
            isInGracePeriod: false,
            willRenew: willRenew
        )
    }

    // MARK: - Products & Purchase

    func fetchProducts() async throws -> [SubscriptionProduct] {
        let productIds = [Self.monthlyProductId, Self.annualProductId]
        let storeProducts = try await Product.products(for: productIds)

        return storeProducts.compactMap { product -> SubscriptionProduct? in
            guard let subscription = product.subscription else { return nil }

            let period: SubscriptionPeriod = subscription.subscriptionPeriod.unit == .month
                ? .monthly : .annual

            return SubscriptionProduct(
                id: product.id,
                displayName: product.displayName,
                description: product.description,
                displayPrice: product.displayPrice,
                price: product.price,
                subscriptionPeriod: period
            )
        }
    }

    func purchase(_ product: SubscriptionProduct) async throws -> PurchaseResult {
        let storeProducts = try await Product.products(for: [product.id])
        guard let storeProduct = storeProducts.first else {
            throw PremiumError.productNotFound
        }

        let result = try await storeProduct.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                let status = try await verifyPremiumStatus()
                return .success(status)
            case .unverified:
                throw PremiumError.verificationFailed
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw PremiumError.unknownResult
        }
    }

    func restorePurchases() async throws -> PremiumStatusInfo {
        try await AppStore.sync()
        return try await verifyPremiumStatus()
    }

    // MARK: - Transaction Listener

    func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                _ = try? await verifyPremiumStatus()
            }
        }
    }

    // MARK: - Private Helpers

    private func getCachedStatus() async throws -> SCPremiumStatus? {
        let descriptor = FetchDescriptor<SCPremiumStatus>(
            predicate: #Predicate { $0.userId == userId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func updateCachedStatus(
        isPremium: Bool,
        expiresAt: Date?,
        productId: String?,
        transactionId: String?
    ) async throws {
        let now = Date()

        if let existing = try await getCachedStatus() {
            existing.isPremium = isPremium
            existing.expiresAt = expiresAt
            existing.productId = productId
            existing.originalTransactionId = transactionId
            existing.lastVerifiedAt = now
            existing.offlineGraceExpiresAt = now.addingTimeInterval(7 * 24 * 60 * 60)
            existing.needsSync = true
        } else {
            let status = SCPremiumStatus(
                userId: userId,
                isPremium: isPremium,
                expiresAt: expiresAt,
                lastVerifiedAt: now,
                originalTransactionId: transactionId,
                productId: productId
            )
            modelContext.insert(status)
        }

        try modelContext.save()
    }
}

// MARK: - Errors

enum PremiumError: Error, LocalizedError {
    case productNotFound
    case verificationFailed
    case unknownResult
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .verificationFailed:
            return "Purchase verification failed"
        case .unknownResult:
            return "Unknown purchase result"
        case .notAuthenticated:
            return "Please sign in to manage your subscription"
        }
    }
}
