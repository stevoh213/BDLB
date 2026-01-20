import Foundation
import UIKit

/// Errors that can occur during profile photo upload
enum UploadProfilePhotoError: Error, LocalizedError, Sendable {
    case compressionFailed
    case imageTooLarge(maxSizeMB: Int)
    case uploadFailed(String)
    case profileUpdateFailed(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .imageTooLarge(let maxSizeMB):
            return "Image exceeds maximum size of \(maxSizeMB)MB after compression"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .profileUpdateFailed(let message):
            return "Failed to update profile: \(message)"
        case .unauthorized:
            return "You must be logged in to upload a photo"
        }
    }
}

/// Uploads a profile photo
///
/// Handles image compression, upload to storage, and profile update.
/// Coordinates between StorageService and ProfileService.
protocol UploadProfilePhotoUseCaseProtocol: Sendable {
    /// Uploads a profile photo and updates the profile
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's UUID (for storage path)
    ///   - profileId: The profile to update with the new URL
    /// - Returns: The public URL of the uploaded photo
    /// - Throws: UploadProfilePhotoError if compression, upload, or profile update fails
    func execute(image: UIImage, userId: UUID, profileId: UUID) async throws -> String
}

/// Uploads a profile photo with compression
///
/// `UploadProfilePhotoUseCase` coordinates the following steps:
/// 1. Compress the image to JPEG with progressive quality reduction
/// 2. Upload to Supabase Storage via StorageService
/// 3. Update the profile's photoURL via ProfileService
///
/// ## Image Compression
///
/// The use case attempts to compress images to under 5MB using progressive
/// quality reduction starting at 0.8 and decreasing by 0.1 until either:
/// - The image is under the size limit
/// - Quality reaches 0.1 (minimum)
///
/// ## Usage
///
/// ```swift
/// let useCase = UploadProfilePhotoUseCase(
///     storageService: storageService,
///     profileService: profileService
/// )
/// let url = try await useCase.execute(
///     image: selectedImage,
///     userId: currentUserId,
///     profileId: currentUserId
/// )
/// ```
final class UploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol, @unchecked Sendable {
    private let storageService: StorageServiceProtocol
    private let profileService: ProfileServiceProtocol

    /// Maximum file size in bytes (5MB)
    static let maxFileSizeBytes = 5 * 1024 * 1024

    /// Initial JPEG compression quality
    static let initialCompressionQuality: CGFloat = 0.8

    /// Minimum JPEG compression quality
    static let minimumCompressionQuality: CGFloat = 0.1

    /// Quality reduction step for each compression attempt
    static let qualityReductionStep: CGFloat = 0.1

    init(
        storageService: StorageServiceProtocol,
        profileService: ProfileServiceProtocol
    ) {
        self.storageService = storageService
        self.profileService = profileService
    }

    func execute(image: UIImage, userId: UUID, profileId: UUID) async throws -> String {
        // 1. Compress image to JPEG
        guard let compressedData = compressImage(image) else {
            throw UploadProfilePhotoError.compressionFailed
        }

        // 2. Verify size after compression
        guard compressedData.count <= Self.maxFileSizeBytes else {
            throw UploadProfilePhotoError.imageTooLarge(maxSizeMB: 5)
        }

        // 3. Upload to storage
        let photoURL: String
        do {
            photoURL = try await storageService.uploadProfilePhoto(
                imageData: compressedData,
                userId: userId
            )
        } catch let error as StorageError {
            switch error {
            case .unauthorized:
                throw UploadProfilePhotoError.unauthorized
            case .fileTooLarge(let maxSizeMB):
                throw UploadProfilePhotoError.imageTooLarge(maxSizeMB: maxSizeMB)
            default:
                throw UploadProfilePhotoError.uploadFailed(error.localizedDescription)
            }
        }

        // 4. Update profile with new photo URL
        do {
            let updates = ProfileUpdates(photoURL: photoURL)
            try await profileService.updateProfile(profileId: profileId, updates: updates)
        } catch {
            // Photo is uploaded but profile update failed
            // Log this but return the URL so the view can retry the profile update
            throw UploadProfilePhotoError.profileUpdateFailed(error.localizedDescription)
        }

        return photoURL
    }

    // MARK: - Private Helpers

    /// Compresses a UIImage to JPEG with progressive quality reduction
    /// - Parameter image: The image to compress
    /// - Returns: JPEG data under the size limit, or nil if compression fails
    private func compressImage(_ image: UIImage) -> Data? {
        var quality = Self.initialCompressionQuality

        // Try progressively lower quality until we're under the size limit
        while quality >= Self.minimumCompressionQuality {
            if let data = image.jpegData(compressionQuality: quality) {
                if data.count <= Self.maxFileSizeBytes {
                    return data
                }
            }
            quality -= Self.qualityReductionStep
        }

        // Final attempt at minimum quality
        return image.jpegData(compressionQuality: Self.minimumCompressionQuality)
    }
}
