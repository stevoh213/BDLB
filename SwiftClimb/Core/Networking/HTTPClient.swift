import Foundation

/// Base HTTP client with retry and exponential backoff
actor HTTPClient {
    private let session: URLSession
    private let maxRetries: Int
    private let baseDelay: TimeInterval

    init(
        session: URLSession = .shared,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0
    ) {
        self.session = session
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    func execute<T: Decodable>(
        _ request: URLRequest,
        retryCount: Int = 0
    ) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if retryCount < maxRetries {
                let delay = calculateDelay(retryCount: retryCount)
                try await Task.sleep(for: .seconds(delay))
                return try await execute(request, retryCount: retryCount + 1)
            }
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("[HTTPClient] HTTP \(httpResponse.statusCode) for \(request.url?.path ?? "unknown")")
            if let dataString = String(data: data, encoding: .utf8) {
                print("[HTTPClient] Error response: \(dataString)")
            }
            #endif
            if shouldRetry(statusCode: httpResponse.statusCode) && retryCount < maxRetries {
                let delay = calculateDelay(retryCount: retryCount)
                try await Task.sleep(for: .seconds(delay))
                return try await execute(request, retryCount: retryCount + 1)
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first (Supabase format)
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractional.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            let formatterStandard = ISO8601DateFormatter()
            formatterStandard.formatOptions = [.withInternetDateTime]
            if let date = formatterStandard.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            #if DEBUG
            print("❌ Decoding error: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("📦 Response data: \(dataString)")
            }
            #endif
            throw NetworkError.decodingError(error)
        }
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        // Retry on server errors and rate limiting
        return statusCode >= 500 || statusCode == 429
    }

    private func calculateDelay(retryCount: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = baseDelay * pow(2.0, Double(retryCount))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay
        return exponentialDelay + jitter
    }
}
