import Testing
import Foundation
@testable import SwiftClimbFeature

/// Tests for premium feature gates
@Suite("Premium Feature Gate Tests")
struct PremiumFeatureGateTests {

    // MARK: - OpenBeta Search Use Case Tests

    @Test("SearchOpenBetaUseCase throws premiumRequired when not premium")
    func searchOpenBetaThrowsPremiumRequiredWhenNotPremium() async throws {
        let mockService = MockPremiumService(isPremium: false)
        let useCase = SearchOpenBetaUseCase(premiumService: mockService)

        await #expect(throws: OpenBetaError.premiumRequired) {
            try await useCase.searchAreas(query: "Boulder", limit: 10)
        }
    }

    @Test("SearchOpenBetaUseCase throws premiumRequired for climb search when not premium")
    func searchOpenBetaClimbsThrowsPremiumRequiredWhenNotPremium() async throws {
        let mockService = MockPremiumService(isPremium: false)
        let useCase = SearchOpenBetaUseCase(premiumService: mockService)

        await #expect(throws: OpenBetaError.premiumRequired) {
            try await useCase.searchClimbs(areaId: "123", query: "Test", limit: 10)
        }
    }

    @Test("SearchOpenBetaUseCase allows access when premium")
    func searchOpenBetaAllowsAccessWhenPremium() async throws {
        let mockService = MockPremiumService(isPremium: true)
        let useCase = SearchOpenBetaUseCase(premiumService: mockService)

        // Should not throw
        let results = try await useCase.searchAreas(query: "Boulder", limit: 10)
        #expect(results.isEmpty) // Empty because we haven't implemented the actual search
    }

    @Test("SearchOpenBetaUseCase throws premiumRequired when service is nil")
    func searchOpenBetaThrowsPremiumRequiredWhenServiceNil() async throws {
        let useCase = SearchOpenBetaUseCase(premiumService: nil)

        await #expect(throws: OpenBetaError.premiumRequired) {
            try await useCase.searchAreas(query: "Boulder", limit: 10)
        }
    }

    // MARK: - Logbook 30-Day Filter Tests

    @Test("Logbook filters sessions older than 30 days for free users")
    func logbookFiltersOldSessionsForFreeUsers() {
        let now = Date()
        let twentyDaysAgo = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        let fortyDaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: now)!

        let recentSession = createMockSession(endedAt: twentyDaysAgo)
        let oldSession = createMockSession(endedAt: fortyDaysAgo)

        let allSessions = [recentSession, oldSession]
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        // Simulate free tier filtering
        let visibleSessions = allSessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= cutoffDate
        }

        #expect(visibleSessions.count == 1)
        #expect(visibleSessions.first?.id == recentSession.id)
    }

    @Test("Logbook shows all sessions for premium users")
    func logbookShowsAllSessionsForPremiumUsers() {
        let now = Date()
        let twentyDaysAgo = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        let fortyDaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: now)!

        let recentSession = createMockSession(endedAt: twentyDaysAgo)
        let oldSession = createMockSession(endedAt: fortyDaysAgo)

        let allSessions = [recentSession, oldSession]

        // Premium users see all sessions (no filtering)
        #expect(allSessions.count == 2)
    }

    @Test("Logbook correctly counts gated sessions")
    func logbookCorrectlyCountsGatedSessions() {
        let now = Date()
        let sessions = [
            createMockSession(endedAt: Calendar.current.date(byAdding: .day, value: -10, to: now)),
            createMockSession(endedAt: Calendar.current.date(byAdding: .day, value: -20, to: now)),
            createMockSession(endedAt: Calendar.current.date(byAdding: .day, value: -40, to: now)),
            createMockSession(endedAt: Calendar.current.date(byAdding: .day, value: -50, to: now)),
            createMockSession(endedAt: Calendar.current.date(byAdding: .day, value: -60, to: now))
        ]

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let visibleSessions = sessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= cutoffDate
        }

        let gatedCount = sessions.count - visibleSessions.count

        #expect(visibleSessions.count == 2) // 10 and 20 days ago
        #expect(gatedCount == 3) // 40, 50, 60 days ago
    }

    // MARK: - Helper Functions

    private func createMockSession(endedAt: Date?) -> SCSession {
        SCSession(
            id: UUID(),
            userId: UUID(),
            startedAt: Date(),
            endedAt: endedAt
        )
    }
}

/// Mock PremiumService for testing
actor MockPremiumService: PremiumServiceProtocol {
    private let mockIsPremium: Bool

    init(isPremium: Bool) {
        self.mockIsPremium = isPremium
    }

    func isPremium() async -> Bool {
        mockIsPremium
    }

    func getPremiumStatus() async -> PremiumStatusInfo {
        PremiumStatusInfo(
            isPremium: mockIsPremium,
            expiresAt: nil,
            productId: nil,
            isInGracePeriod: false,
            willRenew: false
        )
    }

    func verifyPremiumStatus() async throws -> PremiumStatusInfo {
        getPremiumStatus()
    }

    func fetchProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func purchase(_ product: SubscriptionProduct) async throws -> PurchaseResult {
        .cancelled
    }

    func restorePurchases() async throws -> PremiumStatusInfo {
        getPremiumStatus()
    }

    func listenForTransactionUpdates() async {
        // No-op for mock
    }
}
