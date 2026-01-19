import Foundation

/// Owns Supabase auth token and request pipeline
actor SupabaseClientActor {
    private var currentSession: AuthSession?
    private var refreshTask: Task<Void, Error>?
    private let httpClient: HTTPClient
    private let config: SupabaseConfig
    private let keychainService: KeychainService

    init(
        config: SupabaseConfig = .shared,
        httpClient: HTTPClient = HTTPClient(),
        keychainService: KeychainService = KeychainService()
    ) {
        self.config = config
        self.httpClient = httpClient
        self.keychainService = keychainService
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws -> AuthSession {
        var urlComponents = URLComponents(url: config.authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = [
            "email": email,
            "password": password
        ]

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        do {
            let response: AuthResponse = try await httpClient.execute(request)
            let session = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn,
                user: AuthUser(
                    id: response.user.id,
                    email: response.user.email
                )
            )

            currentSession = session
            try await keychainService.saveSession(session)
            scheduleTokenRefresh(expiresIn: session.expiresIn)

            return session
        } catch let error as NetworkError {
            throw parseAuthError(error)
        }
    }

    func signUp(email: String, password: String, metadata: [String: String]) async throws -> AuthSession {
        let url = config.authURL.appendingPathComponent("signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        let body = SignUpRequest(
            email: email,
            password: password,
            data: metadata
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        do {
            let response: AuthResponse = try await httpClient.execute(request)
            let session = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn,
                user: AuthUser(
                    id: response.user.id,
                    email: response.user.email
                )
            )

            currentSession = session
            try await keychainService.saveSession(session)
            scheduleTokenRefresh(expiresIn: session.expiresIn)

            return session
        } catch let error as NetworkError {
            throw parseAuthError(error)
        }
    }

    func signOut() async {
        if let token = currentSession?.accessToken {
            let url = config.authURL.appendingPathComponent("logout")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            // Fire and forget - don't throw errors on logout
            _ = try? await httpClient.execute(request) as EmptyResponse
        }

        currentSession = nil
        try? await keychainService.deleteSession()
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshToken() async throws {
        guard let refreshToken = currentSession?.refreshToken else {
            throw AuthError.sessionExpired
        }

        var urlComponents = URLComponents(url: config.authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = [
            "refresh_token": refreshToken
        ]

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        do {
            let response: AuthResponse = try await httpClient.execute(request)
            let session = AuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn,
                user: AuthUser(
                    id: response.user.id,
                    email: response.user.email
                )
            )

            currentSession = session
            try await keychainService.saveSession(session)
            scheduleTokenRefresh(expiresIn: session.expiresIn)
        } catch let error as NetworkError {
            throw parseAuthError(error)
        }
    }

    /// Restore session from Keychain and refresh if needed
    func restoreSession() async throws -> AuthSession? {
        guard let session = try await keychainService.loadSession() else {
            return nil
        }

        // Check if token is expired or about to expire (within 5 minutes)
        let expirationDate = Date(timeIntervalSinceNow: TimeInterval(session.expiresIn))
        let fiveMinutesFromNow = Date(timeIntervalSinceNow: 300)

        if expirationDate < fiveMinutesFromNow {
            // Token is expired or about to expire, refresh it
            currentSession = session
            try await refreshToken()
            return currentSession
        } else {
            // Token is still valid
            currentSession = session
            scheduleTokenRefresh(expiresIn: session.expiresIn)
            return session
        }
    }

    // MARK: - Request Execution

    /// Execute a Supabase REST API request
    /// - Parameter supabaseRequest: The request to execute
    /// - Parameter requiresAuth: If true, requires a valid session token. If false, uses anon key only.
    /// - Returns: Decoded response
    func execute<T: Decodable>(_ supabaseRequest: SupabaseRequest, requiresAuth: Bool = true) async throws -> T {
        var urlComponents = URLComponents(url: config.restURL, resolvingAgainstBaseURL: true)!
        urlComponents.path += supabaseRequest.path

        if let queryParams = supabaseRequest.queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = supabaseRequest.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        // Add Prefer header for POST/PATCH/PUT to return the created/updated row
        if ["POST", "PATCH", "PUT"].contains(supabaseRequest.method) {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        // Add Bearer token if available (for authenticated requests)
        if let token = currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if requiresAuth {
            throw NetworkError.unauthorized
        }

        request.httpBody = supabaseRequest.body

        return try await httpClient.execute(request)
    }

    func getCurrentSession() -> AuthSession? {
        return currentSession
    }

    func getCurrentToken() -> String? {
        return currentSession?.accessToken
    }

    // MARK: - Private Helpers

    /// Parse Supabase error responses into AuthError
    private func parseAuthError(_ networkError: NetworkError) -> AuthError {
        switch networkError {
        case .httpError(let statusCode, let data):
            // Try to parse error message from response
            if let data = data,
               let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                let message = errorResponse.message.lowercased()

                if message.contains("invalid login credentials") || message.contains("invalid email or password") {
                    return .invalidCredentials
                } else if message.contains("user already registered") || message.contains("email already exists") {
                    return .emailAlreadyRegistered
                } else if message.contains("password") && (message.contains("weak") || message.contains("short")) {
                    return .weakPassword
                } else if message.contains("invalid email") {
                    return .invalidEmail
                } else {
                    return .serverError(errorResponse.message)
                }
            }

            // Fallback based on status code
            switch statusCode {
            case 400:
                return .invalidCredentials
            case 401:
                return .sessionExpired
            case 409:
                return .emailAlreadyRegistered
            default:
                return .serverError("HTTP \(statusCode)")
            }

        case .unauthorized:
            return .sessionExpired

        case .noConnection:
            return .networkError

        case .serverError(let message):
            return .serverError(message)

        default:
            return .unknown(networkError.localizedDescription)
        }
    }

    private func scheduleTokenRefresh(expiresIn: Int) {
        refreshTask?.cancel()

        // Refresh token 5 minutes before expiration
        let refreshDelay = max(0, TimeInterval(expiresIn) - 300)

        refreshTask = Task {
            try await Task.sleep(for: .seconds(refreshDelay))
            try await refreshToken()
        }
    }
}

// MARK: - Supporting Types

struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthUser
}

struct AuthUser: Codable, Sendable {
    let id: UUID
    let email: String?
}

struct SupabaseRequest: Sendable {
    let path: String
    let method: String
    let body: Data?
    let queryParams: [String: String]?

    init(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryParams: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryParams = queryParams
    }
}

// MARK: - Request/Response DTOs

private struct SignInRequest: Codable, Sendable {
    let email: String
    let password: String
    let grantType: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case grantType = "grant_type"
    }
}

private struct SignUpRequest: Codable, Sendable {
    let email: String
    let password: String
    let data: [String: String]?
}

private struct RefreshTokenRequest: Codable, Sendable {
    let refreshToken: String
    let grantType: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case grantType = "grant_type"
    }
}

private struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String?
    let user: AuthUserResponse

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

private struct AuthUserResponse: Codable, Sendable {
    let id: UUID
    let email: String?
    let emailConfirmedAt: String?
    let phone: String?
    let confirmedAt: String?
    let lastSignInAt: String?
    let role: String?
    let aud: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case phone
        case confirmedAt = "confirmed_at"
        case lastSignInAt = "last_sign_in_at"
        case role
        case aud
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct EmptyResponse: Codable, Sendable {}

private struct SupabaseErrorResponse: Codable, Sendable {
    let message: String
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case message = "msg"
        case error
        case errorDescription = "error_description"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try different message fields
        if let msg = try? container.decode(String.self, forKey: .message) {
            self.message = msg
        } else if let errorDesc = try? container.decode(String.self, forKey: .errorDescription) {
            self.message = errorDesc
        } else if let error = try? container.decode(String.self, forKey: .error) {
            self.message = error
        } else {
            self.message = "Unknown error"
        }

        self.error = try? container.decode(String.self, forKey: .error)
        self.errorDescription = try? container.decode(String.self, forKey: .errorDescription)
    }
}
