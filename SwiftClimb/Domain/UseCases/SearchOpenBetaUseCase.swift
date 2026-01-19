import Foundation

/// Search OpenBeta for areas and climbs
/// NOTE: This feature is gated behind premium subscription
protocol SearchOpenBetaUseCaseProtocol: Sendable {
    func searchAreas(query: String, limit: Int) async throws -> [AreaSearchResult]
    func searchClimbs(areaId: String, query: String?, limit: Int) async throws -> [ClimbSearchResult]
}

struct AreaSearchResult: Sendable {
    let id: String
    let name: String
    let pathTokens: [String]
    let totalClimbs: Int
}

struct ClimbSearchResult: Sendable {
    let id: String
    let name: String
    let grades: ClimbSearchGrades
    let discipline: Discipline
}

struct ClimbSearchGrades: Sendable {
    let vScale: String?
    let yds: String?
    let french: String?
}

// Premium-gated implementation
final class SearchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol, @unchecked Sendable {
    private let premiumService: PremiumServiceProtocol?

    init(premiumService: PremiumServiceProtocol? = nil) {
        self.premiumService = premiumService
    }

    func searchAreas(query: String, limit: Int) async throws -> [AreaSearchResult] {
        // Check premium status
        guard await premiumService?.isPremium() == true else {
            throw OpenBetaError.premiumRequired
        }

        // TODO: Implement OpenBeta area search
        return []
    }

    func searchClimbs(areaId: String, query: String?, limit: Int) async throws -> [ClimbSearchResult] {
        // Check premium status
        guard await premiumService?.isPremium() == true else {
            throw OpenBetaError.premiumRequired
        }

        // TODO: Implement OpenBeta climb search
        return []
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
