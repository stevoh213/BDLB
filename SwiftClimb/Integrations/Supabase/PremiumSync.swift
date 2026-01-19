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

        guard profiles.first != nil else { return nil }

        // Note: Requires ProfileDTO to include premium fields
        return nil // TODO: Map from ProfileDTO once fields added
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
