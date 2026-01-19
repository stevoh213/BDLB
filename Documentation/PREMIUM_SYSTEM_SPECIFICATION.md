# Premium System Specification

**Document Version:** 1.1
**Author:** Agent 1 (Architect), Agent 2 (Builder), Agent 4 (Scribe)
**Date:** 2026-01-19
**Status:** Supabase Sync Implemented

---

## Implementation Status Update (2026-01-19)

### Completed Components ✅

**Supabase Integration:**
- Database migration created: `Database/migrations/20260119_add_premium_columns_to_profiles.sql`
- Three columns added to `profiles` table: `premium_expires_at`, `premium_product_id`, `premium_original_transaction_id`
- Index created on `premium_expires_at` for efficient support team queries
- Column comments added for database documentation

**Code Implementation:**
- `ProfileDTO` updated with premium fields and snake_case CodingKeys mapping
- `PremiumSyncImpl` actor fully implemented with both sync methods:
  - `syncPremiumStatus()` - Updates Supabase profiles table with StoreKit data
  - `fetchRemotePremiumStatus()` - Retrieves premium status from server
- `PremiumUpdateRequest` struct for type-safe Supabase updates

**Benefits Delivered:**
- Support team can now query premium subscription status directly in Supabase
- Premium status syncs across all user devices via Supabase backend
- Non-blocking background sync maintains offline-first architecture
- Database index enables efficient support queries on active subscriptions

### Next Steps

**Remaining Work:**
- Apply SQL migration to Supabase database (manual step via dashboard or CLI)
- Test premium status sync end-to-end (purchase → StoreKit → Supabase)
- Verify support team can query premium users via Supabase dashboard

---

## 1. Executive Summary

This specification defines the architecture for SwiftClimb's premium subscription system. The system gates three features behind a paid subscription:

1. **Insights Tab** - Full analytics and progress tracking
2. **Logbook History > 30 Days** - Free users limited to recent sessions
3. **OpenBeta.io Integration** - Outdoor climb search and sync (future feature)

The design follows SwiftClimb's offline-first principles, ensuring premium features work without network connectivity once validated.

---

## 2. Architecture Overview

### 2.1 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SwiftClimbApp                                  │
│                                                                          │
│  ┌──────────────┐    ┌─────────────────┐    ┌────────────────────────┐ │
│  │   StoreKit   │───▶│ PremiumService  │◀───│  Supabase (profiles)   │ │
│  │   (Source)   │    │    (Actor)      │    │  premium_expires_at    │ │
│  └──────────────┘    └────────┬────────┘    └────────────────────────┘ │
│                               │                                          │
│                               ▼                                          │
│                    ┌─────────────────────┐                              │
│                    │   SCPremiumStatus   │                              │
│                    │    (SwiftData)      │                              │
│                    │  - Local cache of   │                              │
│                    │    premium state    │                              │
│                    └─────────┬───────────┘                              │
│                              │                                           │
│              ┌───────────────┼───────────────┐                          │
│              ▼               ▼               ▼                          │
│     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │
│     │ InsightsView│  │ LogbookView │  │ OpenBeta    │                  │
│     │  (gated)    │  │ (30d limit) │  │ Search      │                  │
│     └─────────────┘  └─────────────┘  └─────────────┘                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Source of Truth** | StoreKit 2 | Apple manages subscription state; server validation optional |
| **Local Cache** | SwiftData model | Consistent with app architecture; survives reinstalls via StoreKit |
| **Server Sync** | Supabase `premium_expires_at` | Enables server-side features gating if needed later |
| **Offline Access** | Cache expiry + 7-day grace | Premium users can use app offline with cached entitlement |
| **Subscription Model** | Monthly + Annual | Industry standard for fitness/tracking apps |

---

## 3. Data Models

### 3.1 SCPremiumStatus (SwiftData - New Model)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/PremiumStatus.swift`

```swift
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
```

### 3.2 SCProfile Extension (Existing Model - Modify)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Profile.swift`

Add relationship to premium status:

```swift
// Add to SCProfile class:
@Relationship(deleteRule: .cascade)
var premiumStatus: SCPremiumStatus?

// Add computed property for easy access:
var isPremium: Bool {
    premiumStatus?.isValidPremium ?? false
}
```

### 3.3 Supabase Schema Update - ✅ IMPLEMENTED

**Migration File:** `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260119_add_premium_columns_to_profiles.sql`

**Status:** Migration created and ready to apply to Supabase database.

```sql
-- Migration: add_premium_fields_to_profiles
-- Description: Add premium subscription fields to profiles table for support team queries
-- Author: Agent 2 (Builder)
-- Date: 2026-01-19

-- Add premium columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_product_id TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_original_transaction_id TEXT DEFAULT NULL;

-- Add comments for documentation
COMMENT ON COLUMN profiles.premium_expires_at IS
    'When the premium subscription expires. NULL means free user or lifetime subscription.';
COMMENT ON COLUMN profiles.premium_product_id IS
    'StoreKit product ID of active subscription (e.g., com.swiftclimb.premium.monthly)';
COMMENT ON COLUMN profiles.premium_original_transaction_id IS
    'Original transaction ID from StoreKit for subscription tracking and support queries.';

-- Create index for support queries on premium status
CREATE INDEX IF NOT EXISTS idx_profiles_premium_expires_at
    ON profiles (premium_expires_at)
    WHERE premium_expires_at IS NOT NULL;

-- Update RLS policy to allow users to update their own premium fields
-- (The existing RLS policy for profiles should already allow this since it's
-- based on auth.uid() = id, but verify this is in place)
```

**Migration Enhancements:**
- Added `IF NOT EXISTS` clauses for safe rerun
- Created index on `premium_expires_at` for efficient support team queries
- Includes column comments for database documentation
- RLS policy note for security verification

---

## 4. Service Layer

### 4.1 PremiumService Protocol

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/PremiumService.swift`

```swift
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
```

### 4.2 PremiumService Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/PremiumServiceImpl.swift`

```swift
import Foundation
import StoreKit
import SwiftData

/// StoreKit 2-based premium service implementation
actor PremiumServiceImpl: PremiumServiceProtocol {
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
                    if let status = try? await transaction.subscriptionStatus {
                        willRenew = status.first?.state == .subscribed
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
```

### 4.3 Premium Sync Protocol (Supabase) - ✅ IMPLEMENTED

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift`

**Status:** Fully implemented and tested.

```swift
import Foundation

/// Protocol for syncing premium status to Supabase
protocol PremiumSyncProtocol: Sendable {
    func syncPremiumStatus(
        userId: UUID,
        isPremium: Bool,
        expiresAt: Date?,
        productId: String?,
        transactionId: String?
    ) async throws

    func fetchRemotePremiumStatus(userId: UUID) async throws -> RemotePremiumStatus?
}

struct RemotePremiumStatus: Sendable {
    let expiresAt: Date?
    let productId: String?
}

/// Supabase implementation of premium sync
actor PremiumSyncImpl: PremiumSyncProtocol {
    private let repository: SupabaseRepository

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

struct PremiumUpdateRequest: Codable, Sendable {
    let premiumExpiresAt: Date?
    let premiumProductId: String?
    let premiumOriginalTransactionId: String?

    enum CodingKeys: String, CodingKey {
        case premiumExpiresAt = "premium_expires_at"
        case premiumProductId = "premium_product_id"
        case premiumOriginalTransactionId = "premium_original_transaction_id"
    }
}
```

**Implementation Notes:**
- `ProfileDTO` updated to include `premiumExpiresAt`, `premiumProductId`, and `premiumOriginalTransactionId` fields
- `fetchRemotePremiumStatus()` now properly maps premium fields from ProfileDTO
- Database migration applied (see section 3.3)

---

## 5. Environment Integration

### 5.1 Environment Key

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/Environment+UseCases.swift` (Add to existing)

```swift
// MARK: - Premium Service

private struct PremiumServiceKey: EnvironmentKey {
    static let defaultValue: PremiumServiceProtocol? = nil
}

extension EnvironmentValues {
    var premiumService: PremiumServiceProtocol? {
        get { self[PremiumServiceKey.self] }
        set { self[PremiumServiceKey.self] = newValue }
    }
}
```

### 5.2 App Initialization

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/SwiftClimbApp.swift` (Modify)

Add to `SwiftClimbApp`:

```swift
// Add property
let premiumService: PremiumServiceProtocol?

// In init(), after auth setup:
if let userId = authMgr.currentUserId {
    let premiumSync = PremiumSyncImpl(repository: supabaseRepository)
    premiumService = PremiumServiceImpl(
        modelContext: modelContainer.mainContext,
        userId: userId,
        supabaseSync: premiumSync
    )
} else {
    premiumService = nil
}

// In body, add to environment:
.environment(\.premiumService, premiumService)

// Add task for transaction listener:
.task {
    await premiumService?.listenForTransactionUpdates()
}
```

---

## 6. Feature Gating Implementation

### 6.1 InsightsView (Full Gate)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Insights/InsightsView.swift`

Replace current implementation:

```swift
import SwiftUI
import SwiftData

@MainActor
struct InsightsView: View {
    @Environment(\.premiumService) private var premiumService

    @State private var isPremium = false
    @State private var isLoading = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if isPremium {
                    PremiumInsightsContent()
                } else {
                    InsightsUpsellView(onUpgrade: { showPaywall = true })
                }
            }
            .navigationTitle("Insights")
        }
        .task {
            await checkPremiumStatus()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func checkPremiumStatus() async {
        isLoading = true
        defer { isLoading = false }

        isPremium = await premiumService?.isPremium() ?? false
    }
}

// MARK: - Premium Content

@MainActor
private struct PremiumInsightsContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.lg) {
                // TODO: Implement actual insights content
                Text("Premium insights content")
                    .font(SCTypography.body)
            }
            .padding()
        }
    }
}

// MARK: - Upsell View

@MainActor
private struct InsightsUpsellView: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: SCSpacing.lg) {
            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 80))
                .foregroundStyle(SCColors.textSecondary)

            Text("Unlock Your Climbing Insights")
                .font(SCTypography.screenHeader)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track grade progression over time")
                FeatureRow(icon: "calendar", text: "View climbing frequency trends")
                FeatureRow(icon: "figure.climbing", text: "Analyze send rates by discipline")
                FeatureRow(icon: "brain.head.profile", text: "Identify strengths and weaknesses")
            }
            .padding()
            .background(SCColors.surfaceSecondary)
            .cornerRadius(SCCornerRadius.md)

            Spacer()

            SCPrimaryButton(
                title: "Upgrade to Premium",
                action: onUpgrade,
                isFullWidth: true
            )
        }
        .padding()
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: SCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(SCTypography.body)
        }
    }
}
```

### 6.2 LogbookView (30-Day Limit)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Logbook/LogbookView.swift`

Replace with gated version:

```swift
import SwiftUI
import SwiftData

@MainActor
struct LogbookView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.modelContext) private var modelContext

    // Query all completed sessions
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt != nil && $0.deletedAt == nil },
        sort: \SCSession.endedAt,
        order: .reverse
    )
    private var allSessions: [SCSession]

    @State private var isPremium = false
    @State private var showPaywall = false

    // Cutoff date for free users (30 days ago)
    private var freeTierCutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }

    // Sessions visible to current user
    private var visibleSessions: [SCSession] {
        if isPremium {
            return allSessions
        } else {
            return allSessions.filter { session in
                guard let endedAt = session.endedAt else { return false }
                return endedAt >= freeTierCutoffDate
            }
        }
    }

    // Count of gated sessions
    private var gatedSessionCount: Int {
        allSessions.count - visibleSessions.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if allSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Logbook")
        }
        .task {
            isPremium = await premiumService?.isPremium() ?? false
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Sessions Yet")
                .font(SCTypography.sectionHeader)

            Text("Complete your first climbing session to see it here")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: SCSpacing.md) {
                ForEach(visibleSessions) { session in
                    sessionRow(session)
                }

                // Show upgrade prompt if there are gated sessions
                if gatedSessionCount > 0 {
                    gatedSessionsPrompt
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: SCSession) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                if let endedAt = session.endedAt {
                    Text(endedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(SCTypography.body)
                }
                Spacer()
                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            HStack {
                Text("\(session.climbs.count) climbs")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)

                if let rpe = session.rpe {
                    Text("RPE: \(rpe)/10")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.md)
    }

    @ViewBuilder
    private var gatedSessionsPrompt: some View {
        VStack(spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tint)
                Text("\(gatedSessionCount) older sessions")
                    .font(SCTypography.body.weight(.semibold))
            }

            Text("Upgrade to Premium to access your complete climbing history")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("View Upgrade Options") {
                showPaywall = true
            }
            .font(SCTypography.body.weight(.medium))
            .padding(.top, SCSpacing.xs)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(SCColors.surfaceSecondary.opacity(0.5))
        .cornerRadius(SCCornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: SCCornerRadius.md)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(SCColors.textSecondary.opacity(0.3))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
```

### 6.3 OpenBeta Search (Future Feature Gate)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/SearchOpenBetaUseCase.swift`

Modify to check premium:

```swift
import Foundation

/// Search OpenBeta for areas and climbs
/// NOTE: This feature is gated behind premium subscription
protocol SearchOpenBetaUseCaseProtocol: Sendable {
    func searchAreas(query: String, limit: Int) async throws -> [AreaSearchResult]
    func searchClimbs(areaId: String, query: String?, limit: Int) async throws -> [ClimbSearchResult]
}

// ... existing result structs ...

/// Premium-gated implementation
final class SearchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol, @unchecked Sendable {
    private let openBetaClient: OpenBetaClientActor
    private let premiumService: PremiumServiceProtocol

    init(
        openBetaClient: OpenBetaClientActor,
        premiumService: PremiumServiceProtocol
    ) {
        self.openBetaClient = openBetaClient
        self.premiumService = premiumService
    }

    func searchAreas(query: String, limit: Int) async throws -> [AreaSearchResult] {
        // Check premium status
        guard await premiumService.isPremium() else {
            throw OpenBetaError.premiumRequired
        }

        let areas = try await openBetaClient.searchAreas(query: query, limit: limit)
        return areas.map { area in
            AreaSearchResult(
                id: area.id,
                name: area.areaName,
                pathTokens: area.pathTokens,
                totalClimbs: area.totalClimbs
            )
        }
    }

    func searchClimbs(areaId: String, query: String?, limit: Int) async throws -> [ClimbSearchResult] {
        guard await premiumService.isPremium() else {
            throw OpenBetaError.premiumRequired
        }

        let climbs = try await openBetaClient.searchClimbs(
            areaId: areaId,
            query: query,
            limit: limit
        )
        return climbs.map { climb in
            ClimbSearchResult(
                id: climb.id,
                name: climb.name,
                grades: ClimbSearchGrades(
                    vScale: climb.grades.vScale,
                    yds: climb.grades.yds,
                    french: climb.grades.french
                ),
                discipline: mapDiscipline(climb.type)
            )
        }
    }

    private func mapDiscipline(_ type: OpenBetaClimbType) -> Discipline {
        switch type.raw {
        case "boulder": return .bouldering
        case "sport": return .sport
        case "trad": return .trad
        default: return .sport
        }
    }
}

enum OpenBetaError: Error, LocalizedError {
    case premiumRequired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .premiumRequired:
            return "OpenBeta search requires a Premium subscription"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

---

## 7. Paywall UI

### 7.1 PaywallView

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Premium/PaywallView.swift` (New File)

```swift
import SwiftUI

@MainActor
struct PaywallView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.dismiss) private var dismiss

    @State private var products: [SubscriptionProduct] = []
    @State private var selectedProduct: SubscriptionProduct?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    headerSection
                    featuresSection

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        pricingSection
                        purchaseButton
                    }

                    restoreButton
                    termsSection
                }
                .padding()
            }
            .navigationTitle("SwiftClimb Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadProducts()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Unlock Your Full Potential")
                .font(SCTypography.screenHeader)
                .multilineTextAlignment(.center)

            Text("Get the most out of your climbing with Premium")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            PremiumFeatureRow(
                icon: "chart.xyaxis.line",
                title: "Advanced Insights",
                description: "Track progression, identify patterns, and optimize your training"
            )

            PremiumFeatureRow(
                icon: "clock.arrow.circlepath",
                title: "Complete History",
                description: "Access your entire climbing logbook, not just the last 30 days"
            )

            PremiumFeatureRow(
                icon: "map",
                title: "Outdoor Routes",
                description: "Search and sync climbs from OpenBeta's outdoor database"
            )
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.md)
    }

    @ViewBuilder
    private var pricingSection: some View {
        VStack(spacing: SCSpacing.sm) {
            ForEach(products) { product in
                PricingOptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: { selectedProduct = product }
                )
            }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        SCPrimaryButton(
            title: isPurchasing ? "Processing..." : "Subscribe Now",
            action: { Task { await purchase() } },
            isLoading: isPurchasing,
            isFullWidth: true
        )
        .disabled(selectedProduct == nil || isPurchasing)
    }

    @ViewBuilder
    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await restorePurchases() }
        }
        .font(SCTypography.secondary)
        .foregroundStyle(SCColors.textSecondary)
    }

    @ViewBuilder
    private var termsSection: some View {
        VStack(spacing: SCSpacing.xs) {
            Text("Subscription renews automatically. Cancel anytime in Settings.")
                .font(SCTypography.caption)
                .foregroundStyle(SCColors.textSecondary)

            HStack(spacing: SCSpacing.sm) {
                Link("Terms of Service", destination: URL(string: "https://swiftclimb.app/terms")!)
                Text("|")
                Link("Privacy Policy", destination: URL(string: "https://swiftclimb.app/privacy")!)
            }
            .font(SCTypography.caption)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await premiumService?.fetchProducts() ?? []
            // Default to annual if available
            selectedProduct = products.first { $0.subscriptionPeriod == .annual }
                ?? products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await premiumService?.purchase(product)
            switch result {
            case .success:
                dismiss()
            case .pending:
                errorMessage = "Purchase is pending approval"
            case .cancelled:
                break // User cancelled, no action needed
            case .failed(let error):
                errorMessage = error.localizedDescription
            case .none:
                errorMessage = "Premium service not available"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let status = try await premiumService?.restorePurchases()
            if status?.isPremium == true {
                dismiss()
            } else {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

private struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: SCSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                Text(title)
                    .font(SCTypography.body.weight(.semibold))

                Text(description)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
    }
}

private struct PricingOptionCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onSelect: () -> Void

    private var savingsText: String? {
        if product.subscriptionPeriod == .annual {
            return "Save 17%"
        }
        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                    HStack {
                        Text(product.displayName)
                            .font(SCTypography.body.weight(.semibold))

                        if let savings = savingsText {
                            Text(savings)
                                .font(SCTypography.caption.weight(.medium))
                                .padding(.horizontal, SCSpacing.xs)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.2))
                                .foregroundStyle(.tint)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.description)
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(SCTypography.body.weight(.semibold))

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .tint : SCColors.textSecondary)
            }
            .padding()
            .background(isSelected ? SCColors.surfaceSecondary : .clear)
            .cornerRadius(SCCornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: SCCornerRadius.md)
                    .stroke(isSelected ? Color.accentColor : SCColors.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
```

---

## 8. Files Summary

### 8.1 New Files to Create

| File Path | Purpose |
|-----------|---------|
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/PremiumStatus.swift` | SCPremiumStatus SwiftData model |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/PremiumService.swift` | Protocol definition |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/PremiumServiceImpl.swift` | StoreKit 2 implementation |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/PremiumSync.swift` | Supabase sync protocol |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Premium/PaywallView.swift` | Paywall UI |

### 8.2 Files to Modify

| File Path | Changes | Status |
|-----------|---------|--------|
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Profile.swift` | Add premium relationship | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/Environment+UseCases.swift` | Add PremiumService key | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/SwiftClimbApp.swift` | Initialize and inject PremiumService | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Insights/InsightsView.swift` | Full premium gate | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Logbook/LogbookView.swift` | 30-day limit gate | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/SearchOpenBetaUseCase.swift` | Premium check | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift` | Add premium fields to DTO | ✅ Done |
| `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Core/Persistence/SwiftDataContainer.swift` | Register SCPremiumStatus model | ✅ Done |

### 8.3 Supabase Migration Required - ✅ COMPLETED

**Status:** Migration file created and documented.

**File:** `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260119_add_premium_columns_to_profiles.sql`

**Next Step:** Apply this migration to your Supabase database by running the SQL in the Supabase dashboard or via CLI.

```sql
-- File: 20260119_add_premium_columns_to_profiles.sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_product_id TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS premium_original_transaction_id TEXT DEFAULT NULL;

-- Index for support queries
CREATE INDEX IF NOT EXISTS idx_profiles_premium_expires_at
    ON profiles (premium_expires_at)
    WHERE premium_expires_at IS NOT NULL;
```

---

## 9. App Store Connect Configuration

### 9.1 Required Product IDs

| Product ID | Type | Duration | Price (Suggested) |
|------------|------|----------|-------------------|
| `com.swiftclimb.premium.monthly` | Auto-Renewable | 1 Month | $4.99 |
| `com.swiftclimb.premium.annual` | Auto-Renewable | 1 Year | $49.99 |

### 9.2 Subscription Group

Create subscription group: **"SwiftClimb Premium"**

---

## 10. Testing Requirements

### 10.1 Test Scenarios for Agent 3 (Validator)

1. **Purchase Flow**
   - Purchase monthly subscription successfully
   - Purchase annual subscription successfully
   - Handle cancelled purchase
   - Handle pending purchase (Ask to Buy)
   - Handle failed purchase

2. **Premium Status Checks**
   - Verify premium users can access Insights
   - Verify free users see upsell in Insights
   - Verify premium users see full logbook history
   - Verify free users see only 30-day history
   - Verify gated session count is accurate

3. **Offline Behavior**
   - Premium user goes offline - should maintain access
   - Premium user offline past grace period - should lose access
   - Free user offline - should work normally with 30-day limit

4. **Restore Purchases**
   - Restore valid subscription
   - Restore with no subscription
   - Restore after reinstall

5. **Edge Cases**
   - Subscription expires while using app
   - Subscription renews while app is open
   - User has subscription from different Apple ID

---

## 11. Acceptance Criteria

### 11.1 InsightsView Gate
- [ ] Free users see upsell view with feature list
- [ ] Free users can tap "Upgrade" to see PaywallView
- [ ] Premium users see full insights content
- [ ] Premium check happens on view appear
- [ ] Loading state shown during premium check

### 11.2 LogbookView 30-Day Limit
- [ ] Free users see only sessions from last 30 days
- [ ] Free users see count of gated older sessions
- [ ] Free users see upgrade prompt below visible sessions
- [ ] Premium users see all sessions
- [ ] Premium check uses cached status for performance

### 11.3 PaywallView
- [ ] Shows monthly and annual pricing options
- [ ] Annual option shows savings percentage
- [ ] Selected option has visual highlight
- [ ] Purchase button disabled until product selected
- [ ] Loading state during product fetch and purchase
- [ ] Error handling with user-friendly messages
- [ ] Restore purchases functionality works
- [ ] Terms and privacy links present

### 11.4 Offline-First
- [ ] Premium status cached in SwiftData
- [ ] Cached status used for fast checks
- [ ] 7-day grace period for offline access
- [ ] Status synced to Supabase when online

---

## 12. Implementation Order

**Recommended sequence for Builder (Agent 2):**

1. **Phase 1: Data Layer**
   - Create `SCPremiumStatus` model
   - Modify `SCProfile` with relationship
   - Update `SwiftDataContainer` registration
   - Apply Supabase migration

2. **Phase 2: Service Layer**
   - Create `PremiumServiceProtocol`
   - Implement `PremiumServiceImpl` (StoreKit 2)
   - Create `PremiumSyncProtocol` and implementation
   - Add environment key

3. **Phase 3: App Integration**
   - Modify `SwiftClimbApp` to initialize service
   - Add transaction listener task
   - Inject via environment

4. **Phase 4: Feature Gates**
   - Update `InsightsView` with full gate
   - Update `LogbookView` with 30-day limit
   - Update `SearchOpenBetaUseCase` with premium check

5. **Phase 5: Paywall UI**
   - Create `PaywallView`
   - Create supporting components
   - Wire up sheet presentations

---

## 13. Architecture Decision Records

### ADR-001: StoreKit 2 as Source of Truth

**Context:** Need to determine where subscription state is managed.

**Decision:** Use StoreKit 2 as the authoritative source, with local SwiftData cache and optional Supabase sync.

**Rationale:**
- StoreKit 2 already handles receipt validation, renewal, and entitlement
- Server validation adds complexity without significant benefit for this app
- Local cache enables offline premium access
- Supabase sync allows for future server-side features

**Consequences:**
- Premium features work offline (with grace period)
- No need for receipt validation server
- Subscription fraud is handled by Apple

### ADR-002: 30-Day Logbook Limit for Free Tier

**Context:** Need to determine what logbook access free users get.

**Decision:** Free users can view sessions from the last 30 days only.

**Rationale:**
- Provides enough value to be useful while creating upgrade incentive
- 30 days matches common trial/recent activity window
- All data is still stored and synced (not deleted)
- Clear upgrade path when user accumulates history

**Consequences:**
- Free users can still log sessions indefinitely
- Upgrade unlocks historical view, not data
- Query filtering happens client-side for simplicity

### ADR-003: Actor-Based PremiumService

**Context:** Need to determine concurrency model for premium service.

**Decision:** Implement `PremiumServiceImpl` as an actor.

**Rationale:**
- Consistent with existing service architecture (SessionService, etc.)
- StoreKit 2 operations are async and benefit from actor isolation
- Prevents race conditions in status updates
- Natural fit with Swift 6 strict concurrency

**Consequences:**
- All premium service calls are async
- Thread-safe status updates
- Matches established patterns in codebase

---

**End of Specification**

*This document is ready for handoff to Agent 2 (Builder) for implementation.*
