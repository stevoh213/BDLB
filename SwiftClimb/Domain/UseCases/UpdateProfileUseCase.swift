import Foundation

/// Errors that can occur during profile update
enum UpdateProfileError: Error, LocalizedError, Sendable {
    case bioTooLong(maxLength: Int, actualLength: Int)
    case displayNameTooLong(maxLength: Int)
    case invalidHandle(reason: String)
    case handleAlreadyTaken
    case profileNotFound
    case notAuthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .bioTooLong(let maxLength, let actualLength):
            return "Bio is too long (\(actualLength)/\(maxLength) characters)"
        case .displayNameTooLong(let maxLength):
            return "Display name exceeds \(maxLength) characters"
        case .invalidHandle(let reason):
            return "Invalid handle: \(reason)"
        case .handleAlreadyTaken:
            return "This handle is already taken"
        case .profileNotFound:
            return "Profile not found"
        case .notAuthorized:
            return "You are not authorized to update this profile"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

/// Updates a user's profile
///
/// Handles validation of profile fields before delegating to ProfileService.
/// Views should use this use case rather than calling ProfileService directly.
protocol UpdateProfileUseCaseProtocol: Sendable {
    /// Updates a user's profile with the provided changes
    /// - Parameters:
    ///   - profileId: The profile's UUID
    ///   - displayName: New display name (nil to keep existing)
    ///   - bio: New bio text (nil to keep existing, max 280 chars)
    ///   - homeGym: New home gym name (nil to keep existing)
    ///   - climbingSince: New climbing start date (nil to keep existing)
    ///   - favoriteStyle: New favorite climbing style (nil to keep existing)
    ///   - isPublic: New visibility setting (nil to keep existing)
    ///   - handle: New handle (nil to keep existing, requires validation)
    /// - Throws: UpdateProfileError if validation fails or update fails
    func execute(
        profileId: UUID,
        displayName: String?,
        bio: String?,
        homeGym: String?,
        climbingSince: Date?,
        favoriteStyle: String?,
        isPublic: Bool?,
        handle: String?
    ) async throws
}

/// Updates a user's profile with validation
///
/// `UpdateProfileUseCase` provides input validation before delegating to ProfileService.
/// It ensures bio length limits, display name length, and handle format are validated
/// at the application layer before persisting changes.
///
/// ## Validation Rules
///
/// - **Bio**: Maximum 280 characters
/// - **Display Name**: Maximum 50 characters
/// - **Handle**: 3-30 characters, alphanumeric + underscores, starts with letter
///
/// ## Usage
///
/// ```swift
/// let useCase = UpdateProfileUseCase(profileService: profileService)
/// try await useCase.execute(
///     profileId: userId,
///     displayName: nil,
///     bio: "Climber from Colorado",
///     homeGym: "Movement Denver",
///     climbingSince: nil,
///     favoriteStyle: nil,
///     isPublic: nil,
///     handle: nil
/// )
/// ```
final class UpdateProfileUseCase: UpdateProfileUseCaseProtocol, @unchecked Sendable {
    private let profileService: ProfileServiceProtocol

    /// Maximum length for bio text
    static let maxBioLength = 280

    /// Maximum length for display name
    static let maxDisplayNameLength = 50

    init(profileService: ProfileServiceProtocol) {
        self.profileService = profileService
    }

    func execute(
        profileId: UUID,
        displayName: String?,
        bio: String?,
        homeGym: String?,
        climbingSince: Date?,
        favoriteStyle: String?,
        isPublic: Bool?,
        handle: String?
    ) async throws {
        // 1. Validate bio length
        if let bio = bio {
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedBio.count <= Self.maxBioLength else {
                throw UpdateProfileError.bioTooLong(
                    maxLength: Self.maxBioLength,
                    actualLength: trimmedBio.count
                )
            }
        }

        // 2. Validate display name length
        if let displayName = displayName {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.count <= Self.maxDisplayNameLength else {
                throw UpdateProfileError.displayNameTooLong(maxLength: Self.maxDisplayNameLength)
            }
        }

        // 3. Validate handle format if provided
        if let handle = handle {
            guard isValidHandleFormat(handle) else {
                throw UpdateProfileError.invalidHandle(
                    reason: "Must be 3-30 characters, start with a letter, and contain only letters, numbers, and underscores"
                )
            }
        }

        // 4. Build updates struct with trimmed values
        let updates = ProfileUpdates(
            handle: handle,
            isPublic: isPublic,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio?.trimmingCharacters(in: .whitespacesAndNewlines),
            homeGym: homeGym?.trimmingCharacters(in: .whitespacesAndNewlines),
            climbingSince: climbingSince,
            favoriteStyle: favoriteStyle
        )

        // 5. Delegate to service (handles offline-first save + handle availability check)
        do {
            try await profileService.updateProfile(profileId: profileId, updates: updates)
        } catch let error as ProfileError {
            // Transform service errors to use case errors for cleaner view handling
            switch error {
            case .profileNotFound:
                throw UpdateProfileError.profileNotFound
            case .handleAlreadyTaken:
                throw UpdateProfileError.handleAlreadyTaken
            case .invalidHandle:
                throw UpdateProfileError.invalidHandle(reason: "Invalid format")
            case .bioTooLong(let maxLength):
                throw UpdateProfileError.bioTooLong(maxLength: maxLength, actualLength: bio?.count ?? 0)
            case .unauthorized:
                throw UpdateProfileError.notAuthorized
            case .saveFailed(let message):
                throw UpdateProfileError.networkError(message)
            case .networkError(let underlyingError):
                throw UpdateProfileError.networkError(underlyingError.localizedDescription)
            }
        }
    }

    // MARK: - Private Helpers

    private func isValidHandleFormat(_ handle: String) -> Bool {
        // Handle rules: 3-30 chars, alphanumeric + underscores, starts with letter
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]{2,29}$"
        return handle.range(of: pattern, options: .regularExpression) != nil
    }
}
