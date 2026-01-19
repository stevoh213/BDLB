import Foundation

/// GraphQL request/response handling
actor GraphQLClient {
    private let httpClient: HTTPClient
    private let endpoint: URL

    init(endpoint: URL, httpClient: HTTPClient = HTTPClient()) {
        self.endpoint = endpoint
        self.httpClient = httpClient
    }

    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil
    ) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,
            "variables": variables ?? [:]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw NetworkError.encodingError(error)
        }

        let response: GraphQLResponse<T> = try await httpClient.execute(request)

        if let errors = response.errors, !errors.isEmpty {
            let errorMessage = errors.map { $0.message }.joined(separator: ", ")
            throw NetworkError.serverError(errorMessage)
        }

        guard let data = response.data else {
            throw NetworkError.invalidResponse
        }

        return data
    }
}

// MARK: - Supporting Types

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
    let locations: [Location]?
    let path: [String]?

    struct Location: Decodable {
        let line: Int
        let column: Int
    }
}
