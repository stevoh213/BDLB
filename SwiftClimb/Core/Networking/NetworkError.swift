import Foundation

enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case serverError(String)
    case timeout
    case noConnection
    case rateLimitExceeded
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let message):
            return "Server error: \(message)"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No internet connection"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
