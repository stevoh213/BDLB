import Foundation

/// Authentication-specific errors with user-friendly messages
enum AuthError: Error, LocalizedError, Sendable {
    case invalidCredentials
    case emailAlreadyRegistered
    case handleTaken
    case weakPassword
    case invalidEmail
    case networkError
    case serverError(String)
    case sessionExpired
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailAlreadyRegistered:
            return "An account with this email already exists. Please sign in instead."
        case .handleTaken:
            return "This handle is already taken. Please choose a different one."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters with a mix of letters and numbers."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError:
            return "Network connection failed. Please check your internet connection and try again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
