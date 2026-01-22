# Phase 2: Services Specification

> **Feature**: Social Profile Feature - Phase 2
> **Status**: Ready for Implementation
> **Author**: Agent 1 (The Architect)
> **Created**: 2026-01-19
> **Master Document**: [SOCIAL_PROFILE_FEATURE.md](../SOCIAL_PROFILE_FEATURE.md)

---

## Table of Contents
1. [Overview](#overview)
2. [StorageService Specification](#storageservice-specification)
3. [ProfileService Implementation](#profileservice-implementation)
4. [SocialService Extensions](#socialservice-extensions)
5. [ProfilesTable Updates](#profilestable-updates)
6. [FollowsTable Actor](#followstable-actor)
7. [Error Handling](#error-handling)
8. [Acceptance Criteria](#acceptance-criteria)
9. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose
Implement the business logic layer for the social profile system by:
1. Creating a StorageService for profile photo uploads to Supabase Storage
2. Replacing the ProfileService stub with a full actor implementation
3. Extending SocialService with follower/following list methods
4. Adding new DTOs and methods to ProfilesTable for profile search
5. Creating a FollowsTable actor for follow relationship management

### Scope
This phase covers Tasks 2.1 through 2.4 from the master document:
- [ ] 2.1 Create StorageService protocol and implementation
- [ ] 2.2 Implement ProfileService (replace stub)
  - [ ] 2.2.1 createProfile method
  - [ ] 2.2.2 updateProfile method
  - [ ] 2.2.3 getProfile method
  - [ ] 2.2.4 searchProfiles method
- [ ] 2.3 Extend SocialService with follower methods
  - [ ] 2.3.1 getFollowers method
  - [ ] 2.3.2 getFollowing method
  - [ ] 2.3.3 getFollowCounts method
- [ ] 2.4 Update ProfilesTable actor with new DTOs

### Dependencies
- Phase 1 must be complete (database migration applied, SCProfile model updated)
- Supabase Storage bucket `avatars` must exist (see Setup Requirements below)

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `Domain/Services/StorageService.swift` | Photo upload service |
| `Integrations/Supabase/FollowsTable.swift` | Follows table operations |

### Files to Modify
| File Path | Changes |
|-----------|---------|
| `Domain/Services/ProfileService.swift` | Replace stub with actor implementation |
| `Domain/Services/SocialService.swift` | Add 3 follower/following methods |
| `Integrations/Supabase/Tables/ProfilesTable.swift` | Add search method and ProfileSearchResultDTO |
| `Integrations/Supabase/SupabaseConfig.swift` | Add storageURL computed property |

---

## StorageService Specification

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/StorageService.swift`

### Purpose
Provides an abstraction over Supabase Storage for uploading and managing profile photos. The service handles image compression, unique filename generation, and URL retrieval.

### Protocol Definition

```swift
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
```

### Error Type

```swift
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
```

### Actor Implementation

```swift
import Foundation

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

    func getPublicURL(path: String) -> String {
        // Format: {project_url}/storage/v1/object/public/{bucket}/{path}
        return config.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent("public")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)
            .absoluteString
    }
}
```

### SupabaseConfig Update

Add to `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/SupabaseConfig.swift`:

```swift
/// Base URL for Storage API endpoints
var storageURL: URL {
    url.appendingPathComponent("storage/v1")
}
```

### Storage Bucket Setup (Manual Step)

The `avatars` bucket must be created in the Supabase dashboard with the following configuration:

```sql
-- Create avatars bucket (run in Supabase SQL Editor)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Allow authenticated users to upload their own photos
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- RLS Policy: Allow authenticated users to update their own photos
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- RLS Policy: Allow authenticated users to delete their own photos
CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- RLS Policy: Anyone can view public avatars
CREATE POLICY "Public avatar access"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');
```

---

## ProfileService Implementation

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/ProfileService.swift`

### Purpose
Replace the existing stub with a full actor implementation that manages profile CRUD operations with offline-first semantics.

### Updated Protocol

```swift
import Foundation
import SwiftData

/// Profile CRUD operations
///
/// `ProfileServiceProtocol` defines the contract for profile management including
/// creation, updates, retrieval, and search. Implementations should follow
/// offline-first patterns where SwiftData is the source of truth.
protocol ProfileServiceProtocol: Sendable {
    /// Creates a new profile for a user
    /// - Parameters:
    ///   - id: The user's UUID (from Supabase Auth)
    ///   - handle: Unique username/handle
    ///   - photoURL: Optional profile photo URL
    ///   - homeZIP: Optional home ZIP code
    /// - Returns: The created SCProfile
    /// - Throws: ProfileError if creation fails
    func createProfile(
        id: UUID,
        handle: String,
        photoURL: String?,
        homeZIP: String?
    ) async throws -> SCProfile

    /// Updates an existing profile
    /// - Parameters:
    ///   - profileId: The profile's UUID
    ///   - updates: The fields to update
    /// - Throws: ProfileError if update fails
    func updateProfile(profileId: UUID, updates: ProfileUpdates) async throws

    /// Retrieves a profile by ID
    /// - Parameter profileId: The profile's UUID
    /// - Returns: The profile if found, nil otherwise
    func getProfile(profileId: UUID) async -> SCProfile?

    /// Searches for profiles matching a query
    /// - Parameters:
    ///   - query: Search string (matches handle or display name)
    ///   - limit: Maximum results to return
    /// - Returns: Array of matching profiles
    func searchProfiles(query: String, limit: Int) async throws -> [ProfileSearchResult]

    /// Fetches a profile from the remote server
    /// - Parameter profileId: The profile's UUID
    /// - Returns: The remote profile data
    /// - Throws: ProfileError if fetch fails
    func fetchRemoteProfile(profileId: UUID) async throws -> ProfileDTO?
}

/// Result type for profile search (lightweight, no SwiftData dependency)
struct ProfileSearchResult: Sendable, Identifiable {
    let id: UUID
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let isPublic: Bool
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int
}
```

### Error Type

```swift
/// Errors that can occur during profile operations
enum ProfileError: Error, LocalizedError, Sendable {
    case profileNotFound
    case handleAlreadyTaken
    case invalidHandle
    case bioTooLong(maxLength: Int)
    case saveFailed(String)
    case networkError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .handleAlreadyTaken:
            return "This handle is already taken"
        case .invalidHandle:
            return "Invalid handle format"
        case .bioTooLong(let maxLength):
            return "Bio exceeds maximum length of \(maxLength) characters"
        case .saveFailed(let message):
            return "Failed to save profile: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Not authorized to perform this action"
        }
    }
}
```

### Actor Implementation

```swift
import Foundation
import SwiftData

/// Manages profile CRUD operations with offline-first semantics
///
/// `ProfileServiceImpl` provides profile management with the following approach:
/// - Local SwiftData is the source of truth for the UI
/// - Changes are saved locally first, then synced to Supabase in background
/// - Remote operations (search) query Supabase directly
///
/// ## Offline-First Pattern
///
/// ```
/// User Action
///     │
///     ▼
/// Save to SwiftData (< 100ms)
///     │
///     ├─► Return to UI immediately
///     │
///     └─► Enqueue background sync
///             │
///             ▼
///         Supabase (async)
/// ```
///
/// ## Usage
///
/// ```swift
/// let profileService = ProfileServiceImpl(
///     modelContainer: container,
///     profilesTable: profilesTable,
///     syncActor: syncActor
/// )
///
/// try await profileService.updateProfile(
///     profileId: userId,
///     updates: ProfileUpdates(bio: "Climber from Colorado")
/// )
/// ```
actor ProfileServiceImpl: ProfileServiceProtocol {
    private let modelContainer: ModelContainer
    private let profilesTable: ProfilesTable

    init(
        modelContainer: ModelContainer,
        profilesTable: ProfilesTable
    ) {
        self.modelContainer = modelContainer
        self.profilesTable = profilesTable
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func createProfile(
        id: UUID,
        handle: String,
        photoURL: String?,
        homeZIP: String?
    ) async throws -> SCProfile {
        // 1. Validate handle format
        guard isValidHandle(handle) else {
            throw ProfileError.invalidHandle
        }

        // 2. Check handle availability
        let isAvailable = try await profilesTable.checkHandleAvailable(handle: handle)
        guard isAvailable else {
            throw ProfileError.handleAlreadyTaken
        }

        // 3. Create profile locally
        let profile = await MainActor.run {
            let profile = SCProfile(
                id: id,
                handle: handle,
                photoURL: photoURL,
                homeZIP: homeZIP,
                needsSync: true
            )
            modelContext.insert(profile)
            return profile
        }

        // 4. Save locally
        try await MainActor.run {
            try modelContext.save()
        }

        // 5. Sync to remote (fire and forget, will retry on failure)
        Task {
            try? await syncProfileToRemote(profile)
        }

        return profile
    }

    func updateProfile(profileId: UUID, updates: ProfileUpdates) async throws {
        // 1. Validate bio length if provided
        if let bio = updates.bio, bio.count > SCProfile.maxBioLength {
            throw ProfileError.bioTooLong(maxLength: SCProfile.maxBioLength)
        }

        // 2. If handle is changing, check availability
        if let newHandle = updates.handle {
            guard isValidHandle(newHandle) else {
                throw ProfileError.invalidHandle
            }
            let isAvailable = try await profilesTable.checkHandleAvailable(handle: newHandle)
            guard isAvailable else {
                throw ProfileError.handleAlreadyTaken
            }
        }

        // 3. Find and update profile locally
        try await MainActor.run {
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            guard let profile = try modelContext.fetch(descriptor).first else {
                throw ProfileError.profileNotFound
            }

            // Apply updates
            if let handle = updates.handle { profile.handle = handle }
            if let photoURL = updates.photoURL { profile.photoURL = photoURL }
            if let homeZIP = updates.homeZIP { profile.homeZIP = homeZIP }
            if let boulderScale = updates.preferredGradeScaleBoulder {
                profile.preferredGradeScaleBoulder = boulderScale
            }
            if let routeScale = updates.preferredGradeScaleRoute {
                profile.preferredGradeScaleRoute = routeScale
            }
            if let isPublic = updates.isPublic { profile.isPublic = isPublic }
            if let displayName = updates.displayName { profile.displayName = displayName }
            if let bio = updates.bio { profile.bio = bio }
            if let homeGym = updates.homeGym { profile.homeGym = homeGym }
            if let climbingSince = updates.climbingSince { profile.climbingSince = climbingSince }
            if let favoriteStyle = updates.favoriteStyle { profile.favoriteStyle = favoriteStyle }

            profile.updatedAt = Date()
            profile.needsSync = true

            try modelContext.save()
        }

        // 4. Sync to remote (fire and forget)
        Task {
            try? await syncProfileUpdateToRemote(profileId: profileId, updates: updates)
        }
    }

    func getProfile(profileId: UUID) async -> SCProfile? {
        await MainActor.run {
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            return try? modelContext.fetch(descriptor).first
        }
    }

    func searchProfiles(query: String, limit: Int) async throws -> [ProfileSearchResult] {
        // Search is a remote-only operation (searching across all users)
        // Returns lightweight results that don't require SwiftData
        let results = try await profilesTable.searchProfiles(query: query, limit: limit)
        return results.map { dto in
            ProfileSearchResult(
                id: dto.id,
                handle: dto.handle,
                displayName: dto.displayName,
                photoURL: dto.photoURL,
                bio: dto.bio,
                isPublic: dto.isPublic,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount
            )
        }
    }

    func fetchRemoteProfile(profileId: UUID) async throws -> ProfileDTO? {
        try await profilesTable.fetchProfile(userId: profileId)
    }

    // MARK: - Private Helpers

    private func isValidHandle(_ handle: String) -> Bool {
        // Handle rules: 3-30 chars, alphanumeric + underscores, starts with letter
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]{2,29}$"
        return handle.range(of: pattern, options: .regularExpression) != nil
    }

    private func syncProfileToRemote(_ profile: SCProfile) async throws {
        let dto = await MainActor.run {
            ProfileDTO(
                id: profile.id,
                handle: profile.handle,
                photoURL: profile.photoURL,
                homeZIP: profile.homeZIP,
                preferredGradeScaleBoulder: profile.preferredGradeScaleBoulder.rawValue,
                preferredGradeScaleRoute: profile.preferredGradeScaleRoute.rawValue,
                isPublic: profile.isPublic,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt,
                displayName: profile.displayName,
                bio: profile.bio,
                homeGym: profile.homeGym,
                climbingSince: profile.climbingSince,
                favoriteStyle: profile.favoriteStyle,
                followerCount: profile.followerCount,
                followingCount: profile.followingCount,
                sendCount: profile.sendCount,
                premiumExpiresAt: profile.premiumStatus?.expiresAt,
                premiumProductId: profile.premiumStatus?.productId,
                premiumOriginalTransactionId: profile.premiumStatus?.originalTransactionId
            )
        }

        _ = try await profilesTable.upsertProfile(dto)

        // Mark as synced
        await MainActor.run {
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == profile.id }
            )
            if let profile = try? modelContext.fetch(descriptor).first {
                profile.needsSync = false
                try? modelContext.save()
            }
        }
    }

    private func syncProfileUpdateToRemote(profileId: UUID, updates: ProfileUpdates) async throws {
        let request = ProfileUpdateRequest(
            handle: updates.handle,
            photoURL: updates.photoURL,
            homeZIP: updates.homeZIP,
            preferredGradeScaleBoulder: updates.preferredGradeScaleBoulder?.rawValue,
            preferredGradeScaleRoute: updates.preferredGradeScaleRoute?.rawValue,
            isPublic: updates.isPublic,
            displayName: updates.displayName,
            bio: updates.bio,
            homeGym: updates.homeGym,
            climbingSince: updates.climbingSince,
            favoriteStyle: updates.favoriteStyle
        )

        _ = try await profilesTable.updateProfile(userId: profileId, updates: request)

        // Mark as synced
        await MainActor.run {
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            if let profile = try? modelContext.fetch(descriptor).first {
                profile.needsSync = false
                try? modelContext.save()
            }
        }
    }
}
```

---

## SocialService Extensions

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/SocialService.swift`

### Purpose
Extend the existing SocialService with methods for retrieving followers, following, and counts.

### Updated Protocol

Add to `SocialServiceProtocol`:

```swift
/// Social features (follow/feed/kudos/comments)
protocol SocialServiceProtocol: Sendable {
    // ... existing methods ...

    // MARK: - New Follower/Following Methods (Phase 2)

    /// Gets the list of users following a given user
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum number of results
    ///   - offset: Pagination offset
    /// - Returns: Array of profiles following this user
    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]

    /// Gets the list of users a given user is following
    /// - Parameters:
    ///   - userId: The user whose following list to retrieve
    ///   - limit: Maximum number of results
    ///   - offset: Pagination offset
    /// - Returns: Array of profiles this user follows
    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult]

    /// Gets the follower and following counts for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Tuple of (followerCount, followingCount)
    func getFollowCounts(userId: UUID) async throws -> (followers: Int, following: Int)
}
```

### Updated Implementation

```swift
import Foundation
import SwiftData

/// Manages social features including follows, posts, kudos, and comments
///
/// `SocialServiceImpl` provides social functionality with offline-first semantics.
/// Follow actions are saved locally first, then synced to Supabase.
/// Follower/following lists are fetched from the remote server.
actor SocialServiceImpl: SocialServiceProtocol {
    private let modelContainer: ModelContainer
    private let followsTable: FollowsTable
    private let profilesTable: ProfilesTable

    init(
        modelContainer: ModelContainer,
        followsTable: FollowsTable,
        profilesTable: ProfilesTable
    ) {
        self.modelContainer = modelContainer
        self.followsTable = followsTable
        self.profilesTable = profilesTable
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Follow/Unfollow (existing implementations to update)

    func followUser(followerId: UUID, followeeId: UUID) async throws {
        // 1. Prevent self-follow
        guard followerId != followeeId else {
            throw SocialError.cannotFollowSelf
        }

        // 2. Check if already following (locally first)
        let existingFollow = await MainActor.run { () -> SCFollow? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return try? modelContext.fetch(descriptor).first
        }

        if existingFollow != nil {
            return // Already following
        }

        // 3. Check for soft-deleted follow to restore
        let deletedFollow = await MainActor.run { () -> SCFollow? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt != nil
                }
            )
            return try? modelContext.fetch(descriptor).first
        }

        // 4. Create or restore follow locally
        try await MainActor.run {
            if let follow = deletedFollow {
                // Restore soft-deleted follow
                follow.deletedAt = nil
                follow.needsSync = true
            } else {
                // Create new follow
                let follow = SCFollow(
                    followerId: followerId,
                    followeeId: followeeId,
                    needsSync: true
                )
                modelContext.insert(follow)
            }
            try modelContext.save()
        }

        // 5. Sync to remote
        Task {
            try? await followsTable.createFollow(followerId: followerId, followeeId: followeeId)
        }
    }

    func unfollowUser(followerId: UUID, followeeId: UUID) async throws {
        // 1. Find follow locally
        let follow = await MainActor.run { () -> SCFollow? in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return try? modelContext.fetch(descriptor).first
        }

        guard let follow = follow else {
            return // Not following, nothing to do
        }

        // 2. Soft delete locally
        try await MainActor.run {
            follow.deletedAt = Date()
            follow.needsSync = true
            try modelContext.save()
        }

        // 3. Sync to remote
        Task {
            try? await followsTable.deleteFollow(followerId: followerId, followeeId: followeeId)
        }
    }

    func isFollowing(followerId: UUID, followeeId: UUID) async -> Bool {
        // Check locally first
        let localResult = await MainActor.run { () -> Bool in
            let descriptor = FetchDescriptor<SCFollow>(
                predicate: #Predicate {
                    $0.followerId == followerId &&
                    $0.followeeId == followeeId &&
                    $0.deletedAt == nil
                }
            )
            return (try? modelContext.fetch(descriptor).first) != nil
        }
        return localResult
    }

    // MARK: - New Follower/Following Methods

    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult] {
        // This is a remote-only operation - we need the full list across all users
        let results = try await followsTable.getFollowers(
            userId: userId,
            limit: limit,
            offset: offset
        )
        return results.map { dto in
            ProfileSearchResult(
                id: dto.id,
                handle: dto.handle,
                displayName: dto.displayName,
                photoURL: dto.photoURL,
                bio: dto.bio,
                isPublic: dto.isPublic,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount
            )
        }
    }

    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResult] {
        // This is a remote-only operation
        let results = try await followsTable.getFollowing(
            userId: userId,
            limit: limit,
            offset: offset
        )
        return results.map { dto in
            ProfileSearchResult(
                id: dto.id,
                handle: dto.handle,
                displayName: dto.displayName,
                photoURL: dto.photoURL,
                bio: dto.bio,
                isPublic: dto.isPublic,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount
            )
        }
    }

    func getFollowCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        // Prefer local cached counts if available
        let localCounts = await MainActor.run { () -> (Int, Int)? in
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == userId }
            )
            guard let profile = try? modelContext.fetch(descriptor).first else {
                return nil
            }
            return (profile.followerCount, profile.followingCount)
        }

        if let counts = localCounts {
            return counts
        }

        // Fallback to remote
        guard let profileDTO = try await profilesTable.fetchProfile(userId: userId) else {
            return (0, 0)
        }
        return (profileDTO.followerCount, profileDTO.followingCount)
    }

    // MARK: - Existing Stub Methods (not implemented in Phase 2)

    func createPost(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws -> SCPost {
        // TODO: Implement in future phase
        fatalError("Not implemented")
    }

    func getFeed(userId: UUID, limit: Int) async -> [SCPost] {
        // TODO: Implement in future phase
        return []
    }

    func addKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement in future phase
    }

    func removeKudos(postId: UUID, userId: UUID) async throws {
        // TODO: Implement in future phase
    }

    func addComment(postId: UUID, authorId: UUID, content: String) async throws -> SCComment {
        // TODO: Implement in future phase
        fatalError("Not implemented")
    }

    func getComments(postId: UUID) async -> [SCComment] {
        // TODO: Implement in future phase
        return []
    }
}

/// Errors that can occur during social operations
enum SocialError: Error, LocalizedError, Sendable {
    case cannotFollowSelf
    case alreadyFollowing
    case notFollowing
    case postNotFound
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .alreadyFollowing:
            return "You are already following this user"
        case .notFollowing:
            return "You are not following this user"
        case .postNotFound:
            return "Post not found"
        case .unauthorized:
            return "Not authorized to perform this action"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

---

## ProfilesTable Updates

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/ProfilesTable.swift`

### Purpose
Add profile search functionality with pagination support.

### New Method

Add to `ProfilesTable` actor:

```swift
/// Search profiles by handle or display name
///
/// Performs a partial match search on both `handle` and `display_name` columns.
/// Only returns public profiles. Results are ordered by relevance (exact matches first,
/// then alphabetically).
///
/// ## RLS Considerations
///
/// This query relies on the `profiles_select_public` RLS policy that allows
/// reading profiles where `is_public = true` or the profile belongs to the
/// current user.
///
/// - Parameters:
///   - query: Search string (minimum 2 characters)
///   - limit: Maximum results to return (default 20, max 50)
/// - Returns: Array of matching profile DTOs
/// - Throws: NetworkError if query fails
func searchProfiles(query: String, limit: Int = 20) async throws -> [ProfileSearchResultDTO] {
    // Enforce reasonable limits
    let effectiveLimit = min(max(limit, 1), 50)

    // Supabase uses PostgREST ilike for case-insensitive partial matching
    // We search both handle and display_name
    let searchPattern = "%\(query)%"

    // Build query params for OR condition
    // PostgREST syntax: or=(handle.ilike.*query*,display_name.ilike.*query*)
    let queryParams: [String: String] = [
        "select": "id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count",
        "or": "(handle.ilike.\(searchPattern),display_name.ilike.\(searchPattern))",
        "is_public": "eq.true",
        "order": "handle.asc",
        "limit": "\(effectiveLimit)"
    ]

    let request = SupabaseRequest(
        path: "/profiles",
        method: "GET",
        queryParams: queryParams
    )

    // Note: Search requires auth to prevent abuse, but returns only public profiles
    return try await repository.client.execute(request, requiresAuth: true)
}
```

### New DTO

Add to `ProfilesTable.swift`:

```swift
// MARK: - Profile Search Result DTO

/// Lightweight DTO for profile search results
///
/// Contains only the fields needed for displaying search results and profile previews.
/// Does not include premium status or grade preferences.
struct ProfileSearchResultDTO: Codable, Sendable {
    let id: UUID
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let isPublic: Bool
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case displayName = "display_name"
        case photoURL = "photo_url"
        case bio
        case isPublic = "is_public"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case sendCount = "send_count"
    }
}
```

---

## FollowsTable Actor

### File Location
`/Users/skelley/Projects/SwiftClimb/SwiftClimb/Integrations/Supabase/Tables/FollowsTable.swift`

### Purpose
Provides typed operations for the `follows` table in Supabase, including creating/deleting follows and fetching follower/following lists with profile data.

### Implementation

```swift
import Foundation

/// Follows table operations
///
/// `FollowsTable` provides typed operations for the `follows` table in Supabase.
/// It manages follower/following relationships and retrieves lists with joined profile data.
///
/// ## Table Structure
///
/// ```sql
/// follows (
///     id UUID PRIMARY KEY,
///     follower_id UUID REFERENCES profiles(id),
///     followee_id UUID REFERENCES profiles(id),
///     created_at TIMESTAMPTZ,
///     deleted_at TIMESTAMPTZ  -- soft delete
/// )
/// ```
///
/// ## Follower Count Updates
///
/// The `follower_count` and `following_count` fields on `profiles` are automatically
/// updated by database triggers when follows are created, soft-deleted, or restored.
actor FollowsTable {
    private let repository: SupabaseRepository

    init(repository: SupabaseRepository) {
        self.repository = repository
    }

    // MARK: - Follow Operations

    /// Creates a new follow relationship
    ///
    /// If a soft-deleted follow exists, it will be restored instead of creating a duplicate.
    ///
    /// - Parameters:
    ///   - followerId: The user who is following
    ///   - followeeId: The user being followed
    /// - Throws: NetworkError if operation fails
    func createFollow(followerId: UUID, followeeId: UUID) async throws {
        // Use upsert to handle restoring soft-deleted follows
        let dto = FollowDTO(
            id: UUID(),
            followerId: followerId,
            followeeId: followeeId,
            createdAt: Date(),
            deletedAt: nil
        )

        // Try to find existing soft-deleted follow first
        let existing = try await findExistingFollow(followerId: followerId, followeeId: followeeId)

        if let existing = existing {
            // Restore the soft-deleted follow
            let restoreRequest = FollowRestoreRequest(deletedAt: nil)
            let _: FollowDTO = try await repository.update(
                table: "follows",
                id: existing.id,
                values: restoreRequest
            )
        } else {
            // Create new follow
            let _: FollowDTO = try await repository.insert(
                into: "follows",
                values: dto
            )
        }
    }

    /// Soft-deletes a follow relationship
    ///
    /// - Parameters:
    ///   - followerId: The user who is unfollowing
    ///   - followeeId: The user being unfollowed
    /// - Throws: NetworkError if operation fails
    func deleteFollow(followerId: UUID, followeeId: UUID) async throws {
        // Find the follow relationship
        let existing = try await findExistingFollow(followerId: followerId, followeeId: followeeId)

        guard let follow = existing, follow.deletedAt == nil else {
            return // Not following or already deleted
        }

        // Soft delete
        try await repository.delete(from: "follows", id: follow.id)
    }

    /// Checks if a follow relationship exists
    ///
    /// - Parameters:
    ///   - followerId: The potential follower
    ///   - followeeId: The potential followee
    /// - Returns: true if an active follow exists
    func checkIsFollowing(followerId: UUID, followeeId: UUID) async throws -> Bool {
        let queryParams: [String: String] = [
            "select": "id",
            "follower_id": "eq.\(followerId.uuidString)",
            "followee_id": "eq.\(followeeId.uuidString)",
            "deleted_at": "is.null",
            "limit": "1"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let results: [FollowDTO] = try await repository.client.execute(request)
        return !results.isEmpty
    }

    // MARK: - Follower/Following Lists

    /// Gets the list of profiles following a user
    ///
    /// Returns profiles that have an active (non-deleted) follow relationship
    /// where the specified user is the followee.
    ///
    /// - Parameters:
    ///   - userId: The user whose followers to retrieve
    ///   - limit: Maximum results
    ///   - offset: Pagination offset
    /// - Returns: Array of profile DTOs
    func getFollowers(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResultDTO] {
        // Use a view or RPC for joined query
        // PostgREST query: select profiles joined via follows
        let queryParams: [String: String] = [
            "select": "follower:follower_id(id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count)",
            "followee_id": "eq.\(userId.uuidString)",
            "deleted_at": "is.null",
            "order": "created_at.desc",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let results: [FollowWithProfileDTO] = try await repository.client.execute(request)
        return results.compactMap { $0.follower }
    }

    /// Gets the list of profiles a user is following
    ///
    /// Returns profiles that have an active (non-deleted) follow relationship
    /// where the specified user is the follower.
    ///
    /// - Parameters:
    ///   - userId: The user whose following list to retrieve
    ///   - limit: Maximum results
    ///   - offset: Pagination offset
    /// - Returns: Array of profile DTOs
    func getFollowing(userId: UUID, limit: Int, offset: Int) async throws -> [ProfileSearchResultDTO] {
        let queryParams: [String: String] = [
            "select": "followee:followee_id(id,handle,display_name,photo_url,bio,is_public,follower_count,following_count,send_count)",
            "follower_id": "eq.\(userId.uuidString)",
            "deleted_at": "is.null",
            "order": "created_at.desc",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let results: [FollowWithProfileDTO] = try await repository.client.execute(request)
        return results.compactMap { $0.followee }
    }

    // MARK: - Sync Operations

    /// Fetch follows updated since a given date for incremental sync
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [FollowDTO] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = formatter.string(from: since)

        let queryParams: [String: String] = [
            "select": "*",
            "or": "(follower_id.eq.\(userId.uuidString),followee_id.eq.\(userId.uuidString))",
            "updated_at": "gt.\(sinceString)",
            "order": "updated_at.asc"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        return try await repository.client.execute(request)
    }

    // MARK: - Private Helpers

    private func findExistingFollow(followerId: UUID, followeeId: UUID) async throws -> FollowDTO? {
        let queryParams: [String: String] = [
            "select": "*",
            "follower_id": "eq.\(followerId.uuidString)",
            "followee_id": "eq.\(followeeId.uuidString)",
            "limit": "1"
        ]

        let request = SupabaseRequest(
            path: "/follows",
            method: "GET",
            queryParams: queryParams
        )

        let results: [FollowDTO] = try await repository.client.execute(request)
        return results.first
    }
}

// MARK: - Data Transfer Objects

/// Follow relationship DTO
struct FollowDTO: Codable, Sendable {
    let id: UUID
    let followerId: UUID
    let followeeId: UUID
    let createdAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followeeId = "followee_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// DTO for restoring a soft-deleted follow
private struct FollowRestoreRequest: Codable, Sendable {
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

/// DTO for follow with joined profile data (followers query)
struct FollowWithProfileDTO: Codable, Sendable {
    let follower: ProfileSearchResultDTO?
    let followee: ProfileSearchResultDTO?
}
```

---

## Error Handling

### Consolidated Error Types

The following error types are defined across the services:

| Error Type | Location | Purpose |
|------------|----------|---------|
| `StorageError` | `StorageService.swift` | File upload/delete failures |
| `ProfileError` | `ProfileService.swift` | Profile CRUD failures |
| `SocialError` | `SocialService.swift` | Follow/social operation failures |
| `NetworkError` | `NetworkError.swift` (existing) | Low-level network failures |

### Error Propagation Pattern

```
View → UseCase → Service → Table Actor → Repository → HTTPClient
                                                          │
                                                          ▼
                                                    NetworkError
                                                          │
                                                          ▼
                                              Service-specific Error
                                                          │
                                                          ▼
                                                    View handles
```

Services should catch `NetworkError` from the repository layer and wrap in service-specific errors when additional context is helpful.

---

## Acceptance Criteria

### Task 2.1: StorageService

- [ ] `StorageServiceProtocol` defined with upload, delete, and getPublicURL methods
- [ ] `StorageError` enum with appropriate error cases
- [ ] `StorageServiceImpl` actor implementation
- [ ] Validates image data is not empty
- [ ] Enforces 5MB file size limit
- [ ] Generates unique filenames with timestamp and UUID
- [ ] Uses upsert (x-upsert header) to allow overwrites
- [ ] Returns correct public URL format
- [ ] `SupabaseConfig.storageURL` property added
- [ ] Code compiles without errors

### Task 2.2: ProfileService Implementation

- [ ] `ProfileServiceProtocol` updated with `ProfileSearchResult` type
- [ ] `ProfileError` enum with appropriate error cases
- [ ] `ProfileServiceImpl` replaces stub implementation
- [ ] `createProfile` validates handle format and availability
- [ ] `createProfile` saves locally first, then syncs
- [ ] `updateProfile` validates bio length
- [ ] `updateProfile` checks handle availability if changed
- [ ] `updateProfile` uses offline-first pattern
- [ ] `getProfile` queries local SwiftData
- [ ] `searchProfiles` queries remote Supabase
- [ ] `fetchRemoteProfile` method added for explicit remote fetch
- [ ] Code compiles without errors

### Task 2.3: SocialService Extensions

- [ ] `SocialServiceProtocol` extended with 3 new methods
- [ ] `SocialError` enum created
- [ ] `SocialServiceImpl` replaces stub implementation
- [ ] `followUser` prevents self-follow
- [ ] `followUser` handles restoring soft-deleted follows
- [ ] `followUser` uses offline-first pattern
- [ ] `unfollowUser` soft-deletes locally first
- [ ] `isFollowing` checks local data
- [ ] `getFollowers` queries remote with pagination
- [ ] `getFollowing` queries remote with pagination
- [ ] `getFollowCounts` prefers local cache, falls back to remote
- [ ] Code compiles without errors

### Task 2.4: ProfilesTable Updates

- [ ] `searchProfiles` method added to ProfilesTable
- [ ] `ProfileSearchResultDTO` created with correct CodingKeys
- [ ] Search uses ilike for case-insensitive partial matching
- [ ] Search only returns public profiles
- [ ] Search enforces reasonable limit (max 50)
- [ ] Code compiles without errors

### FollowsTable Actor (New)

- [ ] `FollowsTable` actor created
- [ ] `FollowDTO` with correct CodingKeys
- [ ] `createFollow` handles soft-deleted restoration
- [ ] `deleteFollow` soft-deletes correctly
- [ ] `checkIsFollowing` works correctly
- [ ] `getFollowers` returns joined profile data
- [ ] `getFollowing` returns joined profile data
- [ ] `fetchUpdatedSince` supports sync
- [ ] Code compiles without errors

---

## Builder Handoff Notes

### Dependencies

1. **Phase 1 must be complete**:
   - SCProfile model must have new fields
   - ProfileDTO/ProfileUpdateRequest must have new fields
   - Database migration must be applied (or mock data available)

2. **Supabase Storage bucket must exist** (manual setup):
   - Create `avatars` bucket in Supabase dashboard
   - Apply RLS policies from StorageService Specification section

### Order of Operations

1. **First**: Add `storageURL` to `SupabaseConfig`
2. **Second**: Create `FollowsTable.swift` (needed by SocialService)
3. **Third**: Update `ProfilesTable.swift` with search method and DTO
4. **Fourth**: Create `StorageService.swift`
5. **Fifth**: Replace `ProfileService.swift` stub with full implementation
6. **Sixth**: Replace `SocialService.swift` stub with full implementation
7. **Seventh**: Verify all code compiles

### Implementation Notes

1. **Actor Isolation**: All service implementations are actors for thread safety. The `@MainActor` property wrapper is used for `modelContext` access to ensure SwiftData operations happen on the main thread.

2. **Offline-First Pattern**: Follow this sequence for all write operations:
   ```
   1. Save to SwiftData (set needsSync = true)
   2. Return to caller immediately
   3. Fire-and-forget Task to sync to Supabase
   4. On sync success, set needsSync = false
   ```

3. **Search is Remote-Only**: Profile search must query Supabase because we need to search across all users, not just locally cached data.

4. **PostgREST Query Syntax**:
   - `ilike` for case-insensitive pattern matching
   - `or=(...)` for OR conditions
   - `is.null` for NULL checks
   - Embedded resources use `table:foreign_key(columns)`

5. **Repository Access**: The `FollowsTable` needs access to `repository.client` for direct request execution. You may need to expose a computed property on `SupabaseRepository`:
   ```swift
   var client: SupabaseClientActor { _client }
   ```

### Testing Verification

After implementation, verify with these tests:

1. **StorageService Test**:
   ```swift
   // Create test image data
   let testImage = UIImage(systemName: "person.circle")!
   let imageData = testImage.jpegData(compressionQuality: 0.8)!

   // Upload
   let url = try await storageService.uploadProfilePhoto(imageData: imageData, userId: testUserId)
   print("Uploaded to: \(url)")

   // Verify URL format
   assert(url.contains("avatars/\(testUserId.uuidString)/"))
   ```

2. **ProfileService Test**:
   ```swift
   // Update bio
   try await profileService.updateProfile(
       profileId: userId,
       updates: ProfileUpdates(bio: "Test bio")
   )

   // Verify local update
   let profile = await profileService.getProfile(profileId: userId)
   assert(profile?.bio == "Test bio")

   // Search
   let results = try await profileService.searchProfiles(query: "test", limit: 10)
   print("Found \(results.count) profiles")
   ```

3. **SocialService Test**:
   ```swift
   // Follow
   try await socialService.followUser(followerId: userA, followeeId: userB)

   // Check following
   let isFollowing = await socialService.isFollowing(followerId: userA, followeeId: userB)
   assert(isFollowing == true)

   // Get followers
   let followers = try await socialService.getFollowers(userId: userB, limit: 10, offset: 0)
   assert(followers.contains { $0.id == userA })

   // Unfollow
   try await socialService.unfollowUser(followerId: userA, followeeId: userB)
   ```

### Files Summary

| File | Action | Priority |
|------|--------|----------|
| `Integrations/Supabase/SupabaseConfig.swift` | MODIFY | 1 |
| `Integrations/Supabase/Tables/FollowsTable.swift` | CREATE | 2 |
| `Integrations/Supabase/Tables/ProfilesTable.swift` | MODIFY | 3 |
| `Domain/Services/StorageService.swift` | CREATE | 4 |
| `Domain/Services/ProfileService.swift` | REPLACE | 5 |
| `Domain/Services/SocialService.swift` | REPLACE | 6 |

---

## Appendix: Data Flow Diagrams

### Profile Update Flow

```
User taps "Save" in EditProfileView
              │
              ▼
┌─────────────────────────┐
│   UpdateProfileUseCase  │  (Phase 3)
└───────────┬─────────────┘
            │ ProfileUpdates
            ▼
┌─────────────────────────┐
│   ProfileServiceImpl    │  actor
│   (updateProfile)       │
└───────────┬─────────────┘
            │
            ├────────────────────────────┐
            │ 1. Validate               │
            ▼                            │
┌─────────────────────────┐              │
│   SwiftData             │              │
│   (SCProfile @Model)    │              │
│   save() < 100ms        │              │
└───────────┬─────────────┘              │
            │                            │
            │ 2. Return immediately      │
            ▼                            │
       ← UI Updated                      │
                                         │
            │ 3. Background Task         │
            ▼                            │
┌─────────────────────────┐              │
│   ProfilesTable         │              │
│   (updateProfile)       │              │
└───────────┬─────────────┘              │
            │                            │
            ▼                            │
┌─────────────────────────┐              │
│   Supabase              │              │
│   (profiles table)      │              │
└─────────────────────────┘              │
                                         │
            │ 4. Mark needsSync = false  │
            └────────────────────────────┘
```

### Photo Upload Flow

```
User selects photo
        │
        ▼
┌─────────────────────────┐
│  UploadProfilePhoto     │  (Phase 3)
│  UseCase                │
└───────────┬─────────────┘
            │
            ├── 1. Compress image (UIKit)
            │
            ▼
┌─────────────────────────┐
│   StorageServiceImpl    │  actor
│   (uploadProfilePhoto)  │
└───────────┬─────────────┘
            │
            ├── 2. Validate size/format
            │
            ▼
┌─────────────────────────┐
│   Supabase Storage      │  REST API
│   POST /storage/v1/...  │
└───────────┬─────────────┘
            │
            ├── 3. Get public URL
            │
            ▼
┌─────────────────────────┐
│   ProfileServiceImpl    │
│   updateProfile(photoURL)│
└───────────┬─────────────┘
            │
            └── 4. Update profile locally + sync
```

### Followers List Flow

```
User taps "Followers" count
              │
              ▼
┌─────────────────────────┐
│   GetFollowersUseCase   │  (Phase 3)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   SocialServiceImpl     │  actor
│   (getFollowers)        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   FollowsTable          │  actor
│   (getFollowers)        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   Supabase REST API     │
│   GET /follows          │
│   with joined profiles  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   [ProfileSearchResult] │
│   returned to View      │
└─────────────────────────┘
```

---

**Document Version**: 1.0
**Last Updated**: 2026-01-19
**Author**: Agent 1 (The Architect)
**Next Phase**: Phase 3 (Use Cases) - depends on Phase 2 completion
