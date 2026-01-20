import Foundation

/// Storage operations for file uploads (profile photos, etc.)
protocol StorageServiceProtocol: Sendable {
    /// Uploads a profile photo to storage
    /// - Parameters:
    ///   - imageData: The image data to upload (JPEG or PNG)
    ///   - userId: The user's ID (used for path organization)
    /// - Returns: The public URL of the uploaded image
    /// - Throws: StorageError if upload fails
    func uploadProfilePhoto(imageData: Data, userId: UUID) async throws -> String

    /// Deletes a profile photo from storage
    /// - Parameter path: The storage path of the file to delete
    /// - Throws: StorageError if deletion fails
    func deleteProfilePhoto(path: String) async throws

    /// Generates a public URL for a stored file
    /// - Parameter path: The storage path of the file
    /// - Returns: The public URL string
    func getPublicURL(path: String) -> String
}

/// Errors that can occur during storage operations
enum StorageError: Error, LocalizedError, Sendable {
    case uploadFailed(String)
    case deleteFailed(String)
    case invalidImageData
    case fileTooLarge(maxSizeMB: Int)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let message):
            return "Failed to upload file: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete file: \(message)"
        case .invalidImageData:
            return "Invalid image data provided"
        case .fileTooLarge(let maxSizeMB):
            return "File exceeds maximum size of \(maxSizeMB)MB"
        case .unauthorized:
            return "Not authorized to perform storage operation"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Manages file uploads to Supabase Storage
///
/// `StorageServiceImpl` provides methods for uploading and managing profile photos
/// in the `avatars` bucket on Supabase Storage. It uses the REST API directly
/// rather than the Supabase Swift SDK to maintain consistency with the existing
/// codebase patterns.
///
/// ## Storage Structure
///
/// Profile photos are stored in the `avatars` bucket with the following path pattern:
/// ```
/// avatars/{userId}/{timestamp}_{uuid}.jpg
/// ```
///
/// This structure:
/// - Organizes photos by user for easy management
/// - Uses timestamps to prevent CDN caching issues when photos are updated
/// - Uses UUIDs to ensure uniqueness
///
/// ## Usage
///
/// ```swift
/// let storageService = StorageServiceImpl(
///     config: .shared,
///     httpClient: HTTPClient()
/// )
///
/// let photoURL = try await storageService.uploadProfilePhoto(
///     imageData: imageData,
///     userId: userId
/// )
/// ```
actor StorageServiceImpl: StorageServiceProtocol {
    private let config: SupabaseConfig
    private let httpClient: HTTPClient
    private let supabaseClient: SupabaseClientActor

    /// Maximum file size in bytes (5MB)
    private let maxFileSizeBytes = 5 * 1024 * 1024

    /// Storage bucket name for avatars
    private let bucketName = "avatars"

    init(
        config: SupabaseConfig = .shared,
        httpClient: HTTPClient = HTTPClient(),
        supabaseClient: SupabaseClientActor
    ) {
        self.config = config
        self.httpClient = httpClient
        self.supabaseClient = supabaseClient
    }

    func uploadProfilePhoto(imageData: Data, userId: UUID) async throws -> String {
        // 1. Validate image data
        guard !imageData.isEmpty else {
            throw StorageError.invalidImageData
        }

        // 2. Check file size
        guard imageData.count <= maxFileSizeBytes else {
            throw StorageError.fileTooLarge(maxSizeMB: 5)
        }

        // 3. Get auth token
        guard let token = await supabaseClient.getCurrentToken() else {
            throw StorageError.unauthorized
        }

        // 4. Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let uniqueId = UUID().uuidString.prefix(8)
        let filename = "\(timestamp)_\(uniqueId).jpg"
        let path = "\(userId.uuidString)/\(filename)"

        // 5. Build request
        let uploadURL = config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert") // Allow overwrite
        request.httpBody = imageData

        // 6. Execute upload
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw StorageError.uploadFailed("Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw StorageError.uploadFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            // 7. Return public URL
            return getPublicURL(path: path)
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.networkError(error)
        }
    }

    func deleteProfilePhoto(path: String) async throws {
        guard let token = await supabaseClient.getCurrentToken() else {
            throw StorageError.unauthorized
        }

        let deleteURL = config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw StorageError.deleteFailed("Invalid response")
            }

            // 404 is acceptable - file may already be deleted
            guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw StorageError.deleteFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.networkError(error)
        }
    }

    nonisolated func getPublicURL(path: String) -> String {
        // Format: {project_url}/storage/v1/object/public/{bucket}/{path}
        return config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent("public")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)
            .absoluteString
    }
}
