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
    /// - Throws: ProfileError if creation fails
    func createProfile(
        id: UUID,
        handle: String,
        photoURL: String?,
        homeZIP: String?
    ) async throws

    /// Updates an existing profile
    /// - Parameters:
    ///   - profileId: The profile's UUID
    ///   - updates: The fields to update
    /// - Throws: ProfileError if update fails
    func updateProfile(profileId: UUID, updates: ProfileUpdates) async throws

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

/// Domain-level profile update request.
///
/// Used by ProfileService and UpdateProfileUseCase to specify which fields to update.
/// This is separate from ProfileUpdateRequest (Supabase DTO) to maintain layer separation.
struct ProfileUpdates: Sendable {
    var handle: String?
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale?
    var preferredGradeScaleRoute: GradeScale?
    var isPublic: Bool?
    // Social profile fields
    var displayName: String?
    var bio: String?
    var homeGym: String?
    var climbingSince: Date?
    var favoriteStyle: String?

    init(
        handle: String? = nil,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: GradeScale? = nil,
        preferredGradeScaleRoute: GradeScale? = nil,
        isPublic: Bool? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil
    ) {
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
    }
}

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
///     profilesTable: profilesTable
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
    ) async throws {
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
        let profileId = await MainActor.run {
            let profile = SCProfile(
                id: id,
                handle: handle,
                photoURL: photoURL,
                homeZIP: homeZIP,
                needsSync: true
            )
            modelContext.insert(profile)
            return profile.id
        }

        // 4. Save locally
        try await MainActor.run {
            try modelContext.save()
        }

        // 5. Sync to remote (fire and forget, will retry on failure)
        Task {
            try? await syncProfileToRemoteById(profileId)
        }
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

    private func syncProfileToRemoteById(_ profileId: UUID) async throws {
        let dto = await MainActor.run { () -> ProfileDTO? in
            let descriptor = FetchDescriptor<SCProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            guard let profile = try? modelContext.fetch(descriptor).first else {
                return nil
            }
            return ProfileDTO(
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

        guard let dto = dto else { return }

        _ = try await profilesTable.upsertProfile(dto)

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
