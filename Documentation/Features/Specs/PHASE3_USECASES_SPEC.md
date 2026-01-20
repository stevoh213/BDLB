# Phase 3: Use Cases Specification

> **Feature**: Social Profile Feature - Phase 3
> **Status**: Ready for Implementation
> **Author**: Agent 1 (The Architect)
> **Created**: 2026-01-19
> **Master Document**: [SOCIAL_PROFILE_FEATURE.md](../SOCIAL_PROFILE_FEATURE.md)

---

## Table of Contents
1. [Overview](#overview)
2. [UpdateProfileUseCase](#updateprofileusecase)
3. [SearchProfilesUseCase](#searchprofilesusecase)
4. [UploadProfilePhotoUseCase](#uploadprofilephotousecase)
5. [GetFollowersUseCase](#getfollowersusecase)
6. [GetFollowingUseCase](#getfollowingusecase)
7. [ToggleFollowUseCase Updates](#togglefollowusecase-updates)
8. [Environment Keys](#environment-keys)
9. [Acceptance Criteria](#acceptance-criteria)
10. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose
Create the application layer use cases that orchestrate business logic for the social profile system. Use cases provide a clean interface between SwiftUI views and domain services, handling validation, error transformation, and cross-cutting concerns.

### Scope
This phase covers Tasks 3.1 through 3.6 from the master document:
- [ ] 3.1 Create UpdateProfileUseCase
- [ ] 3.2 Create SearchProfilesUseCase
- [ ] 3.3 Create UploadProfilePhotoUseCase
- [ ] 3.4 Create GetFollowersUseCase
- [ ] 3.5 Create GetFollowingUseCase
- [ ] 3.6 Update existing ToggleFollowUseCase if needed

### Dependencies
- Phase 2 must be complete:
  - `ProfileServiceImpl` actor with `updateProfile`, `searchProfiles` methods
  - `SocialServiceImpl` actor with `getFollowers`, `getFollowing` methods
  - `StorageServiceImpl` actor with `uploadProfilePhoto` method

### Design Patterns

All use cases follow the established SwiftClimb patterns:

```swift
// Protocol + Implementation pattern
protocol SomeUseCaseProtocol: Sendable {
    func execute(...) async throws -> SomeResult
}

final class SomeUseCase: SomeUseCaseProtocol, @unchecked Sendable {
    private let service: SomeServiceProtocol

    init(service: SomeServiceProtocol) {
        self.service = service
    }

    func execute(...) async throws -> SomeResult {
        // Orchestration logic
    }
}
```

**Key Patterns:**
- `final class` with `@unchecked Sendable` (services are actors, so thread-safe)
- Protocol-based for testability and dependency injection
- Single `execute(...)` method for simple use cases
- Multiple named methods for use cases with several operations
- Inject dependencies via constructor

---

## UpdateProfileUseCase

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/UpdateProfileUseCase.swift`

### Purpose
Orchestrates profile update operations with input validation, handling bio length limits, handle format validation, and coordinating the offline-first save pattern.

### Protocol Definition

```swift
import Foundation

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
```

### Error Type

```swift
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
```

### Implementation

```swift
import Foundation

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
```

---

## SearchProfilesUseCase

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/SearchProfilesUseCase.swift`

### Purpose
Orchestrates profile search with query validation, minimum query length enforcement, and result limiting.

### Protocol Definition

```swift
import Foundation

/// Searches for user profiles
///
/// Provides profile search functionality with query validation.
/// Requires minimum query length to prevent overly broad searches.
protocol SearchProfilesUseCaseProtocol: Sendable {
    /// Searches for profiles matching a query string
    /// - Parameters:
    ///   - query: Search string (minimum 2 characters)
    ///   - limit: Maximum results to return (default 20, max 50)
    /// - Returns: Array of matching profile search results
    /// - Throws: SearchProfilesError if query is invalid or search fails
    func execute(query: String, limit: Int) async throws -> [ProfileSearchResult]
}
```

### Error Type

```swift
/// Errors that can occur during profile search
enum SearchProfilesError: Error, LocalizedError, Sendable {
    case queryTooShort(minLength: Int)
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .queryTooShort(let minLength):
            return "Search query must be at least \(minLength) characters"
        case .networkError(let message):
            return "Search failed: \(message)"
        case .unauthorized:
            return "You must be logged in to search profiles"
        }
    }
}
```

### Implementation

```swift
import Foundation

/// Searches for user profiles by handle or display name
///
/// `SearchProfilesUseCase` validates search queries and delegates to ProfileService.
/// Search is a remote-only operation since we need to search across all users.
///
/// ## Query Requirements
///
/// - Minimum 2 characters
/// - Searches both handle and display name (case-insensitive)
/// - Only returns public profiles
///
/// ## Usage
///
/// ```swift
/// let useCase = SearchProfilesUseCase(profileService: profileService)
/// let results = try await useCase.execute(query: "alex", limit: 20)
/// ```
final class SearchProfilesUseCase: SearchProfilesUseCaseProtocol, @unchecked Sendable {
    private let profileService: ProfileServiceProtocol

    /// Minimum query length required
    static let minQueryLength = 2

    /// Maximum results that can be requested
    static let maxLimit = 50

    /// Default result limit
    static let defaultLimit = 20

    init(profileService: ProfileServiceProtocol) {
        self.profileService = profileService
    }

    func execute(query: String, limit: Int = defaultLimit) async throws -> [ProfileSearchResult] {
        // 1. Trim and validate query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= Self.minQueryLength else {
            throw SearchProfilesError.queryTooShort(minLength: Self.minQueryLength)
        }

        // 2. Enforce limit bounds
        let effectiveLimit = min(max(limit, 1), Self.maxLimit)

        // 3. Delegate to service
        do {
            return try await profileService.searchProfiles(
                query: trimmedQuery,
                limit: effectiveLimit
            )
        } catch let error as ProfileError {
            switch error {
            case .unauthorized:
                throw SearchProfilesError.unauthorized
            case .networkError(let underlyingError):
                throw SearchProfilesError.networkError(underlyingError.localizedDescription)
            default:
                throw SearchProfilesError.networkError(error.localizedDescription)
            }
        }
    }
}
```

---

## UploadProfilePhotoUseCase

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/UploadProfilePhotoUseCase.swift`

### Purpose
Orchestrates profile photo upload including image compression, upload to storage, and updating the profile with the new photo URL.

### Protocol Definition

```swift
import Foundation
import UIKit

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
```

### Error Type

```swift
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
```

### Implementation

```swift
import Foundation
import UIKit

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
```

---

## GetFollowersUseCase

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/GetFollowersUseCase.swift`

### Purpose
Retrieves the list of users following a given user with pagination support.

### Protocol Definition

```swift
import Foundation

/// Retrieves followers for a user profile
///
/// Provides paginated access to a user's followers list.
protocol GetFollowersUseCaseProtocol: Sendable {
    /// Gets the list of users following a given user
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum results per page (default 20)
    ///   - offset: Pagination offset (default 0)
    /// - Returns: Array of profile search results representing followers
    /// - Throws: GetFollowersError if retrieval fails
    func execute(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]
}
```

### Error Type

```swift
/// Errors that can occur when retrieving followers
enum GetFollowersError: Error, LocalizedError, Sendable {
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Failed to load followers: \(message)"
        case .unauthorized:
            return "You must be logged in to view followers"
        }
    }
}
```

### Implementation

```swift
import Foundation

/// Retrieves followers for a user profile with pagination
///
/// `GetFollowersUseCase` fetches the list of users who follow a given user.
/// This is a remote-only operation since we need the complete follower list
/// across all users in the system.
///
/// ## Pagination
///
/// Results are paginated with a default page size of 20. The offset parameter
/// specifies how many results to skip for subsequent pages.
///
/// ## Usage
///
/// ```swift
/// let useCase = GetFollowersUseCase(socialService: socialService)
///
/// // First page
/// let page1 = try await useCase.execute(userId: profileId, limit: 20, offset: 0)
///
/// // Second page
/// let page2 = try await useCase.execute(userId: profileId, limit: 20, offset: 20)
/// ```
final class GetFollowersUseCase: GetFollowersUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    /// Default page size
    static let defaultLimit = 20

    /// Maximum page size
    static let maxLimit = 50

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(
        userId: UUID,
        limit: Int = defaultLimit,
        offset: Int = 0
    ) async throws -> [ProfileSearchResult] {
        // Enforce limit bounds
        let effectiveLimit = min(max(limit, 1), Self.maxLimit)
        let effectiveOffset = max(offset, 0)

        do {
            return try await socialService.getFollowers(
                userId: userId,
                limit: effectiveLimit,
                offset: effectiveOffset
            )
        } catch let error as SocialError {
            switch error {
            case .unauthorized:
                throw GetFollowersError.unauthorized
            case .networkError(let underlyingError):
                throw GetFollowersError.networkError(underlyingError.localizedDescription)
            default:
                throw GetFollowersError.networkError(error.localizedDescription)
            }
        }
    }
}
```

---

## GetFollowingUseCase

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/GetFollowingUseCase.swift`

### Purpose
Retrieves the list of users that a given user is following with pagination support.

### Protocol Definition

```swift
import Foundation

/// Retrieves following list for a user profile
///
/// Provides paginated access to users that a given user follows.
protocol GetFollowingUseCaseProtocol: Sendable {
    /// Gets the list of users a given user is following
    /// - Parameters:
    ///   - userId: The user whose following list to retrieve
    ///   - limit: Maximum results per page (default 20)
    ///   - offset: Pagination offset (default 0)
    /// - Returns: Array of profile search results representing followed users
    /// - Throws: GetFollowingError if retrieval fails
    func execute(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]
}
```

### Error Type

```swift
/// Errors that can occur when retrieving following list
enum GetFollowingError: Error, LocalizedError, Sendable {
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Failed to load following: \(message)"
        case .unauthorized:
            return "You must be logged in to view following"
        }
    }
}
```

### Implementation

```swift
import Foundation

/// Retrieves following list for a user profile with pagination
///
/// `GetFollowingUseCase` fetches the list of users that a given user follows.
/// This is a remote-only operation since we need the complete following list
/// across all users in the system.
///
/// ## Pagination
///
/// Results are paginated with a default page size of 20. The offset parameter
/// specifies how many results to skip for subsequent pages.
///
/// ## Usage
///
/// ```swift
/// let useCase = GetFollowingUseCase(socialService: socialService)
///
/// // First page
/// let page1 = try await useCase.execute(userId: profileId, limit: 20, offset: 0)
///
/// // Second page
/// let page2 = try await useCase.execute(userId: profileId, limit: 20, offset: 20)
/// ```
final class GetFollowingUseCase: GetFollowingUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    /// Default page size
    static let defaultLimit = 20

    /// Maximum page size
    static let maxLimit = 50

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(
        userId: UUID,
        limit: Int = defaultLimit,
        offset: Int = 0
    ) async throws -> [ProfileSearchResult] {
        // Enforce limit bounds
        let effectiveLimit = min(max(limit, 1), Self.maxLimit)
        let effectiveOffset = max(offset, 0)

        do {
            return try await socialService.getFollowing(
                userId: userId,
                limit: effectiveLimit,
                offset: effectiveOffset
            )
        } catch let error as SocialError {
            switch error {
            case .unauthorized:
                throw GetFollowingError.unauthorized
            case .networkError(let underlyingError):
                throw GetFollowingError.networkError(underlyingError.localizedDescription)
            default:
                throw GetFollowingError.networkError(error.localizedDescription)
            }
        }
    }
}
```

---

## ToggleFollowUseCase Updates

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/ToggleFollowUseCase.swift`

### Assessment
The existing `ToggleFollowUseCase` is already functional and uses the correct pattern. It properly:
- Calls `socialService.isFollowing()` to check current state
- Toggles between `followUser()` and `unfollowUser()` based on state
- Follows the `final class` with `@unchecked Sendable` pattern

### Recommended Updates
Minor enhancements for consistency:

1. Add an error type for better view-layer error handling
2. Add a method to check follow state without toggling (useful for UI)

### Updated Implementation

```swift
import Foundation

/// Toggle follow relationship
///
/// Manages follow/unfollow actions between users.
protocol ToggleFollowUseCaseProtocol: Sendable {
    /// Toggles the follow relationship between two users
    /// - Parameters:
    ///   - followerId: The user performing the action (current user)
    ///   - followeeId: The user to follow/unfollow
    /// - Returns: The new follow state (true = now following, false = now not following)
    /// - Throws: ToggleFollowError if the operation fails
    func execute(followerId: UUID, followeeId: UUID) async throws -> Bool

    /// Checks if one user is following another
    /// - Parameters:
    ///   - followerId: The potential follower
    ///   - followeeId: The potential followee
    /// - Returns: true if followerId is following followeeId
    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool
}

/// Errors that can occur when toggling follow
enum ToggleFollowError: Error, LocalizedError, Sendable {
    case cannotFollowSelf
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .networkError(let message):
            return "Follow action failed: \(message)"
        case .unauthorized:
            return "You must be logged in to follow users"
        }
    }
}

/// Toggles follow relationship between users
///
/// `ToggleFollowUseCase` provides a convenient toggle interface for follow buttons.
/// It checks the current follow state and performs the opposite action.
///
/// ## Usage
///
/// ```swift
/// let useCase = ToggleFollowUseCase(socialService: socialService)
///
/// // Toggle follow state
/// let isNowFollowing = try await useCase.execute(
///     followerId: currentUserId,
///     followeeId: profileUserId
/// )
///
/// // Check state without toggling
/// let isFollowing = await useCase.isFollowing(
///     followerId: currentUserId,
///     followeeId: profileUserId
/// )
/// ```
final class ToggleFollowUseCase: ToggleFollowUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(followerId: UUID, followeeId: UUID) async throws -> Bool {
        // 1. Prevent self-follow at use case level
        guard followerId != followeeId else {
            throw ToggleFollowError.cannotFollowSelf
        }

        // 2. Check current state
        let isCurrentlyFollowing = await socialService.isFollowing(
            followerId: followerId,
            followeeId: followeeId
        )

        // 3. Toggle
        do {
            if isCurrentlyFollowing {
                try await socialService.unfollowUser(
                    followerId: followerId,
                    followeeId: followeeId
                )
                return false
            } else {
                try await socialService.followUser(
                    followerId: followerId,
                    followeeId: followeeId
                )
                return true
            }
        } catch let error as SocialError {
            switch error {
            case .cannotFollowSelf:
                throw ToggleFollowError.cannotFollowSelf
            case .unauthorized:
                throw ToggleFollowError.unauthorized
            case .networkError(let underlyingError):
                throw ToggleFollowError.networkError(underlyingError.localizedDescription)
            default:
                throw ToggleFollowError.networkError(error.localizedDescription)
            }
        }
    }

    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool {
        await socialService.isFollowing(followerId: followerId, followeeId: followeeId)
    }
}
```

---

## Environment Keys

### File to Modify
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/Environment+UseCases.swift`

### New Environment Keys

Add the following environment keys for the new use cases:

```swift
// MARK: - Update Profile Use Case

private struct UpdateProfileUseCaseKey: EnvironmentKey {
    static let defaultValue: UpdateProfileUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var updateProfileUseCase: UpdateProfileUseCaseProtocol? {
        get { self[UpdateProfileUseCaseKey.self] }
        set { self[UpdateProfileUseCaseKey.self] = newValue }
    }
}

// MARK: - Search Profiles Use Case

private struct SearchProfilesUseCaseKey: EnvironmentKey {
    static let defaultValue: SearchProfilesUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var searchProfilesUseCase: SearchProfilesUseCaseProtocol? {
        get { self[SearchProfilesUseCaseKey.self] }
        set { self[SearchProfilesUseCaseKey.self] = newValue }
    }
}

// MARK: - Upload Profile Photo Use Case

private struct UploadProfilePhotoUseCaseKey: EnvironmentKey {
    static let defaultValue: UploadProfilePhotoUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var uploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol? {
        get { self[UploadProfilePhotoUseCaseKey.self] }
        set { self[UploadProfilePhotoUseCaseKey.self] = newValue }
    }
}

// MARK: - Get Followers Use Case

private struct GetFollowersUseCaseKey: EnvironmentKey {
    static let defaultValue: GetFollowersUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var getFollowersUseCase: GetFollowersUseCaseProtocol? {
        get { self[GetFollowersUseCaseKey.self] }
        set { self[GetFollowersUseCaseKey.self] = newValue }
    }
}

// MARK: - Get Following Use Case

private struct GetFollowingUseCaseKey: EnvironmentKey {
    static let defaultValue: GetFollowingUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var getFollowingUseCase: GetFollowingUseCaseProtocol? {
        get { self[GetFollowingUseCaseKey.self] }
        set { self[GetFollowingUseCaseKey.self] = newValue }
    }
}
```

### Remove Old ProfileUseCaseProtocol

The existing `ProfileUseCaseProtocol` placeholder should be removed as it's being replaced by the more specific use cases:

```swift
// REMOVE this section:
// MARK: - Profile Use Case (TODO: Implement)
// ...
// protocol ProfileUseCaseProtocol: Sendable { ... }
```

---

## Acceptance Criteria

### Task 3.1: UpdateProfileUseCase

- [ ] `UpdateProfileUseCaseProtocol` defined with execute method
- [ ] `UpdateProfileError` enum with all error cases
- [ ] `UpdateProfileUseCase` implementation as `final class`
- [ ] Bio validation (max 280 characters)
- [ ] Display name validation (max 50 characters)
- [ ] Handle format validation (regex pattern)
- [ ] Whitespace trimming for text fields
- [ ] Error transformation from ProfileError to UpdateProfileError
- [ ] Code compiles without errors

### Task 3.2: SearchProfilesUseCase

- [ ] `SearchProfilesUseCaseProtocol` defined with execute method
- [ ] `SearchProfilesError` enum with all error cases
- [ ] `SearchProfilesUseCase` implementation as `final class`
- [ ] Minimum query length validation (2 characters)
- [ ] Query trimming
- [ ] Limit bounds enforcement (1-50)
- [ ] Error transformation from ProfileError
- [ ] Code compiles without errors

### Task 3.3: UploadProfilePhotoUseCase

- [ ] `UploadProfilePhotoUseCaseProtocol` defined with execute method
- [ ] `UploadProfilePhotoError` enum with all error cases
- [ ] `UploadProfilePhotoUseCase` implementation as `final class`
- [ ] Image compression with progressive quality reduction
- [ ] Size validation (max 5MB)
- [ ] Coordinates StorageService upload and ProfileService update
- [ ] Returns photo URL on success
- [ ] Error transformation from StorageError and ProfileError
- [ ] Code compiles without errors

### Task 3.4: GetFollowersUseCase

- [ ] `GetFollowersUseCaseProtocol` defined with execute method
- [ ] `GetFollowersError` enum with all error cases
- [ ] `GetFollowersUseCase` implementation as `final class`
- [ ] Pagination parameters (limit, offset)
- [ ] Limit bounds enforcement (1-50)
- [ ] Error transformation from SocialError
- [ ] Code compiles without errors

### Task 3.5: GetFollowingUseCase

- [ ] `GetFollowingUseCaseProtocol` defined with execute method
- [ ] `GetFollowingError` enum with all error cases
- [ ] `GetFollowingUseCase` implementation as `final class`
- [ ] Pagination parameters (limit, offset)
- [ ] Limit bounds enforcement (1-50)
- [ ] Error transformation from SocialError
- [ ] Code compiles without errors

### Task 3.6: ToggleFollowUseCase Updates

- [ ] Protocol updated with return type `Bool`
- [ ] `isFollowing` method added to protocol
- [ ] `ToggleFollowError` enum added
- [ ] Implementation returns new follow state
- [ ] Error transformation from SocialError
- [ ] Code compiles without errors

### Environment Keys

- [ ] `UpdateProfileUseCaseKey` added
- [ ] `SearchProfilesUseCaseKey` added
- [ ] `UploadProfilePhotoUseCaseKey` added
- [ ] `GetFollowersUseCaseKey` added
- [ ] `GetFollowingUseCaseKey` added
- [ ] Old `ProfileUseCaseProtocol` placeholder removed
- [ ] Code compiles without errors

---

## Builder Handoff Notes

### Dependencies

1. **Phase 2 must be complete**:
   - `ProfileServiceImpl` with `updateProfile`, `searchProfiles`, `fetchRemoteProfile` methods
   - `SocialServiceImpl` with `getFollowers`, `getFollowing`, `isFollowing`, `followUser`, `unfollowUser` methods
   - `StorageServiceImpl` with `uploadProfilePhoto` method

2. **Required imports**:
   - `Foundation` (all use cases)
   - `UIKit` (UploadProfilePhotoUseCase only - for `UIImage`)

### Order of Operations

1. **First**: Create `UpdateProfileUseCase.swift`
2. **Second**: Create `SearchProfilesUseCase.swift`
3. **Third**: Create `UploadProfilePhotoUseCase.swift`
4. **Fourth**: Create `GetFollowersUseCase.swift`
5. **Fifth**: Create `GetFollowingUseCase.swift`
6. **Sixth**: Update `ToggleFollowUseCase.swift`
7. **Seventh**: Update `Environment+UseCases.swift` with new keys
8. **Eighth**: Verify all code compiles

### Implementation Notes

1. **Sendable Compliance**: All use cases use `@unchecked Sendable` because they hold references to actor-based services. The actors ensure thread safety, so the `@unchecked` is justified.

2. **Error Transformation**: Use cases transform service-layer errors into use-case-specific errors. This:
   - Provides cleaner error messages for the view layer
   - Hides implementation details
   - Makes error handling more specific to the use case context

3. **Input Validation**: All validation happens at the use case layer:
   - Bio/display name length limits
   - Query minimum length
   - Handle format regex
   - Image size limits

4. **Pagination Pattern**: GetFollowers and GetFollowing use offset-based pagination. Views should track the offset and increment by the page size for subsequent requests.

5. **UIKit Import**: Only `UploadProfilePhotoUseCase` needs UIKit for `UIImage`. This is acceptable because:
   - Photo selection happens in SwiftUI views using PhotosPicker
   - PhotosPicker returns `PhotosPickerItem` which converts to `UIImage`
   - The conversion is handled before calling the use case

### Files Summary

| File | Action | Priority |
|------|--------|----------|
| `Domain/UseCases/UpdateProfileUseCase.swift` | CREATE | 1 |
| `Domain/UseCases/SearchProfilesUseCase.swift` | CREATE | 2 |
| `Domain/UseCases/UploadProfilePhotoUseCase.swift` | CREATE | 3 |
| `Domain/UseCases/GetFollowersUseCase.swift` | CREATE | 4 |
| `Domain/UseCases/GetFollowingUseCase.swift` | CREATE | 5 |
| `Domain/UseCases/ToggleFollowUseCase.swift` | MODIFY | 6 |
| `App/Environment+UseCases.swift` | MODIFY | 7 |

### Testing Verification

After implementation, verify with these tests:

1. **UpdateProfileUseCase Test**:
   ```swift
   let useCase = UpdateProfileUseCase(profileService: profileService)

   // Test bio validation
   do {
       try await useCase.execute(
           profileId: userId,
           displayName: nil,
           bio: String(repeating: "a", count: 300), // Too long
           homeGym: nil,
           climbingSince: nil,
           favoriteStyle: nil,
           isPublic: nil,
           handle: nil
       )
       XCTFail("Should throw bioTooLong error")
   } catch let error as UpdateProfileError {
       if case .bioTooLong = error {
           // Expected
       } else {
           XCTFail("Wrong error type")
       }
   }

   // Test successful update
   try await useCase.execute(
       profileId: userId,
       displayName: nil,
       bio: "Valid bio",
       homeGym: nil,
       climbingSince: nil,
       favoriteStyle: nil,
       isPublic: nil,
       handle: nil
   )
   ```

2. **SearchProfilesUseCase Test**:
   ```swift
   let useCase = SearchProfilesUseCase(profileService: profileService)

   // Test minimum query length
   do {
       _ = try await useCase.execute(query: "a", limit: 20)
       XCTFail("Should throw queryTooShort error")
   } catch let error as SearchProfilesError {
       if case .queryTooShort = error {
           // Expected
       }
   }

   // Test successful search
   let results = try await useCase.execute(query: "alex", limit: 20)
   print("Found \(results.count) profiles")
   ```

3. **UploadProfilePhotoUseCase Test**:
   ```swift
   let useCase = UploadProfilePhotoUseCase(
       storageService: storageService,
       profileService: profileService
   )

   let testImage = UIImage(systemName: "person.circle")!
   let url = try await useCase.execute(
       image: testImage,
       userId: userId,
       profileId: userId
   )
   print("Uploaded to: \(url)")
   assert(url.contains("avatars/"))
   ```

4. **GetFollowersUseCase Test**:
   ```swift
   let useCase = GetFollowersUseCase(socialService: socialService)

   let page1 = try await useCase.execute(userId: profileId, limit: 20, offset: 0)
   print("Followers page 1: \(page1.count) results")

   let page2 = try await useCase.execute(userId: profileId, limit: 20, offset: 20)
   print("Followers page 2: \(page2.count) results")
   ```

5. **ToggleFollowUseCase Test**:
   ```swift
   let useCase = ToggleFollowUseCase(socialService: socialService)

   // Check initial state
   let wasFollowing = await useCase.isFollowing(
       followerId: userA,
       followeeId: userB
   )

   // Toggle
   let isNowFollowing = try await useCase.execute(
       followerId: userA,
       followeeId: userB
   )

   assert(isNowFollowing == !wasFollowing)
   ```

---

## Appendix: Data Flow Diagrams

### Profile Update Flow

```
User taps "Save" in EditProfileView
              |
              v
+-------------------------+
|  @Environment           |
|  (\.updateProfileUseCase)|
+------------+------------+
             |
             v
+-------------------------+
|   UpdateProfileUseCase  |
|   1. Validate bio       |
|   2. Validate name      |
|   3. Validate handle    |
|   4. Trim whitespace    |
+------------+------------+
             |
             v
+-------------------------+
|   ProfileServiceImpl    |  actor
|   (updateProfile)       |
+------------+------------+
             |
             +---------------------------+
             |                           |
             v                           v
+----------------+            +------------------+
| SwiftData      |            | ProfilesTable    |
| (local save)   |            | (remote sync)    |
+----------------+            +------------------+
```

### Photo Upload Flow

```
User selects photo via PhotosPicker
              |
              v
+-------------------------+
| PhotosPickerItem -> UIImage
+------------+------------+
             |
             v
+-------------------------+
| @Environment            |
| (\.uploadProfilePhotoUseCase)
+------------+------------+
             |
             v
+-------------------------+
| UploadProfilePhotoUseCase
| 1. Compress image       |
| 2. Validate size        |
+------------+------------+
             |
             +---------------------------+
             |                           |
             v                           v
+----------------+            +------------------+
| StorageService |            | ProfileService   |
| (upload photo) |            | (update photoURL)|
+----------------+            +------------------+
             |
             v
+-------------------------+
| Supabase Storage        |
| avatars/{userId}/*.jpg  |
+-------------------------+
```

### Search Flow

```
User types in search field
              |
              v
+-------------------------+
| @Environment            |
| (\.searchProfilesUseCase)
+------------+------------+
             |
             v
+-------------------------+
| SearchProfilesUseCase   |
| 1. Validate query >= 2  |
| 2. Trim whitespace      |
| 3. Enforce limit        |
+------------+------------+
             |
             v
+-------------------------+
| ProfileServiceImpl      |  actor
| (searchProfiles)        |
+------------+------------+
             |
             v
+-------------------------+
| ProfilesTable           |
| (remote query)          |
+------------+------------+
             |
             v
+-------------------------+
| Supabase REST API       |
| GET /profiles?or=...    |
+-------------------------+
             |
             v
+-------------------------+
| [ProfileSearchResult]   |
| returned to View        |
+-------------------------+
```

---

**Document Version**: 1.0
**Last Updated**: 2026-01-19
**Author**: Agent 1 (The Architect)
**Next Phase**: Phase 4 (Components) - depends on Phases 1, 3 partial completion
