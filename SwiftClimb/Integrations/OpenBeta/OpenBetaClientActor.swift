import Foundation

/// OpenBeta GraphQL client with rate limiting
actor OpenBetaClientActor {
    private let graphQLClient: GraphQLClient
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5

    init(endpoint: URL) {
        self.graphQLClient = GraphQLClient(endpoint: endpoint)
    }

    // MARK: - Rate Limiting

    private func enforceRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastRequest)
            if elapsed < minRequestInterval {
                let waitTime = minRequestInterval - elapsed
                try await Task.sleep(for: .seconds(waitTime))
            }
        }
        lastRequestTime = Date()
    }

    // MARK: - Area Search

    func searchAreas(query: String, limit: Int = 10) async throws -> [OpenBetaArea] {
        try await enforceRateLimit()

        let queryString = OpenBetaQueries.searchAreas(query: query, limit: limit)
        let response: AreasResponse = try await graphQLClient.execute(
            query: queryString,
            variables: nil
        )

        return response.areas
    }

    // MARK: - Climb Search

    func searchClimbs(
        areaId: String,
        query: String?,
        limit: Int = 20
    ) async throws -> [OpenBetaClimb] {
        try await enforceRateLimit()

        let queryString = OpenBetaQueries.searchClimbs(
            areaId: areaId,
            query: query,
            limit: limit
        )
        let response: ClimbsResponse = try await graphQLClient.execute(
            query: queryString,
            variables: nil
        )

        return response.area.climbs
    }
}

// MARK: - Response Types

struct AreasResponse: Decodable {
    let areas: [OpenBetaArea]
}

struct ClimbsResponse: Decodable {
    let area: AreaWithClimbs
}

struct AreaWithClimbs: Decodable {
    let climbs: [OpenBetaClimb]
}
