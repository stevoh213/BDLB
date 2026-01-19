import Foundation

/// Search OpenBeta for areas and climbs
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

// Stub implementation
final class SearchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol, @unchecked Sendable {
    func searchAreas(query: String, limit: Int) async throws -> [AreaSearchResult] {
        // TODO: Implement OpenBeta area search
        return []
    }

    func searchClimbs(areaId: String, query: String?, limit: Int) async throws -> [ClimbSearchResult] {
        // TODO: Implement OpenBeta climb search
        return []
    }
}
