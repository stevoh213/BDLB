import Testing
import Foundation
import SwiftData
@testable import SwiftClimbFeature

/// Tests for PremiumServiceImpl
@Suite("Premium Service Tests")
struct PremiumServiceTests {

    // MARK: - Mock Setup

    /// Creates in-memory model container for testing
    @MainActor
    func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SCPremiumStatus.self,
            configurations: config
        )
    }

    // MARK: - isPremium Tests

    @Test("isPremium returns false when no cached status exists")
    @MainActor
    func isPremiumReturnsFalseWhenNoCachedStatus() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let isPremium = await service.isPremium()
        #expect(isPremium == false)
    }

    @Test("isPremium returns true when valid premium status exists")
    @MainActor
    func isPremiumReturnsTrueWhenValidPremiumExists() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        // Insert premium status
        let status = SCPremiumStatus(
            userId: userId,
            isPremium: true,
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days from now
            lastVerifiedAt: Date()
        )
        container.mainContext.insert(status)
        try container.mainContext.save()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let isPremium = await service.isPremium()
        #expect(isPremium == true)
    }

    @Test("isPremium returns false when subscription expired")
    @MainActor
    func isPremiumReturnsFalseWhenSubscriptionExpired() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        // Insert expired status
        let status = SCPremiumStatus(
            userId: userId,
            isPremium: true,
            expiresAt: Date().addingTimeInterval(-10 * 24 * 60 * 60), // 10 days ago
            lastVerifiedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60)
        )
        container.mainContext.insert(status)
        try container.mainContext.save()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let isPremium = await service.isPremium()
        #expect(isPremium == false)
    }

    @Test("isPremium returns true during grace period")
    @MainActor
    func isPremiumReturnsTrueDuringGracePeriod() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        // Expired 2 days ago, but last verified 2 days ago (within 7-day grace)
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let status = SCPremiumStatus(
            userId: userId,
            isPremium: true,
            expiresAt: twoDaysAgo,
            lastVerifiedAt: twoDaysAgo
        )
        container.mainContext.insert(status)
        try container.mainContext.save()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let isPremium = await service.isPremium()
        #expect(isPremium == true) // Still in grace period
    }

    @Test("isPremium returns true for lifetime subscription")
    @MainActor
    func isPremiumReturnsTrueForLifetimeSubscription() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        // Lifetime subscription has no expiry date
        let status = SCPremiumStatus(
            userId: userId,
            isPremium: true,
            expiresAt: nil, // No expiry = lifetime
            lastVerifiedAt: Date()
        )
        container.mainContext.insert(status)
        try container.mainContext.save()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let isPremium = await service.isPremium()
        #expect(isPremium == true)
    }

    // MARK: - getPremiumStatus Tests

    @Test("getPremiumStatus returns correct grace period status")
    @MainActor
    func getPremiumStatusReturnsCorrectGracePeriodStatus() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let status = SCPremiumStatus(
            userId: userId,
            isPremium: true,
            expiresAt: twoDaysAgo,
            lastVerifiedAt: twoDaysAgo,
            productId: "com.swiftclimb.premium.monthly"
        )
        container.mainContext.insert(status)
        try container.mainContext.save()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let info = await service.getPremiumStatus()
        #expect(info.isPremium == true)
        #expect(info.isInGracePeriod == true)
        #expect(info.productId == "com.swiftclimb.premium.monthly")
    }

    @Test("getPremiumStatus returns default when no status exists")
    @MainActor
    func getPremiumStatusReturnsDefaultWhenNoStatusExists() async throws {
        let container = try createTestContainer()
        let userId = UUID()

        let service = PremiumServiceImpl(
            modelContext: container.mainContext,
            userId: userId,
            supabaseSync: nil
        )

        let info = await service.getPremiumStatus()
        #expect(info.isPremium == false)
        #expect(info.isInGracePeriod == false)
        #expect(info.productId == nil)
        #expect(info.expiresAt == nil)
    }
}

/// Tests for SCPremiumStatus model
@Suite("Premium Status Model Tests")
struct PremiumStatusModelTests {

    @Test("isValidPremium returns false when not premium")
    func isValidPremiumReturnsFalseWhenNotPremium() {
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: false
        )
        #expect(status.isValidPremium == false)
    }

    @Test("isValidPremium returns true for active subscription")
    func isValidPremiumReturnsTrueForActiveSubscription() {
        let futureDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: true,
            expiresAt: futureDate
        )
        #expect(status.isValidPremium == true)
    }

    @Test("isValidPremium returns true for lifetime subscription")
    func isValidPremiumReturnsTrueForLifetimeSubscription() {
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: true,
            expiresAt: nil
        )
        #expect(status.isValidPremium == true)
    }

    @Test("isValidPremium returns false for expired subscription outside grace")
    func isValidPremiumReturnsFalseForExpiredSubscriptionOutsideGrace() {
        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: true,
            expiresAt: tenDaysAgo,
            lastVerifiedAt: tenDaysAgo
        )
        // Grace period is 7 days, so 10 days ago is expired
        #expect(status.isValidPremium == false)
    }

    @Test("isValidPremium returns true for expired subscription in grace period")
    func isValidPremiumReturnsTrueForExpiredSubscriptionInGracePeriod() {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: true,
            expiresAt: threeDaysAgo,
            lastVerifiedAt: threeDaysAgo
        )
        // Still within 7-day grace period
        #expect(status.isValidPremium == true)
    }

    @Test("offlineGraceExpiresAt is 7 days after lastVerifiedAt")
    func offlineGraceExpiresAtIs7DaysAfterLastVerified() {
        let now = Date()
        let status = SCPremiumStatus(
            userId: UUID(),
            isPremium: true,
            lastVerifiedAt: now
        )

        let expectedGraceExpiry = now.addingTimeInterval(7 * 24 * 60 * 60)
        let difference = abs(status.offlineGraceExpiresAt.timeIntervalSince(expectedGraceExpiry))

        // Allow 1 second tolerance for timing
        #expect(difference < 1.0)
    }
}

/// Mock sync implementation for testing
actor MockPremiumSync: PremiumSyncProtocol {
    private(set) var syncCalled = false
    private(set) var lastSyncUserId: UUID?
    private(set) var lastSyncIsPremium: Bool?

    func syncPremiumStatus(
        userId: UUID,
        isPremium: Bool,
        expiresAt: Date?,
        productId: String?,
        transactionId: String?
    ) async throws {
        syncCalled = true
        lastSyncUserId = userId
        lastSyncIsPremium = isPremium
    }

    func fetchRemotePremiumStatus(userId: UUID) async throws -> RemotePremiumStatus? {
        return nil
    }
}
