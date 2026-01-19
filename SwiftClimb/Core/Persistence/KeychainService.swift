import Foundation
import Security

/// Actor for secure Keychain operations
/// Stores and retrieves authentication session data using iOS Keychain
actor KeychainService {
    private let serviceName: String

    init(serviceName: String = "com.swiftclimb.auth") {
        self.serviceName = serviceName
    }

    // MARK: - Session Storage

    /// Save authentication session to Keychain
    func saveSession(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "auth_session",
            kSecValueData as String: data
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    /// Load authentication session from Keychain
    func loadSession() throws -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "auth_session",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw KeychainError.decodingFailed(error)
        }
    }

    /// Delete authentication session from Keychain
    func deleteSession() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "auth_session"
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success if deleted or item didn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: Error, LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case invalidData
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .invalidData:
            return "Invalid data retrieved from Keychain"
        case .decodingFailed(let error):
            return "Failed to decode Keychain data: \(error.localizedDescription)"
        }
    }
}
