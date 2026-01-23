import SwiftUI
import SwiftData

// MARK: - Dev Bypass Configuration
// ⚠️ REMOVE BEFORE PRODUCTION RELEASE ⚠️
#if DEBUG
enum DevSettings {
    /// Mock user ID used when auth is bypassed
    static let mockUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
#endif

@main
struct SwiftClimbApp: App {
    let modelContainer: ModelContainer

    // Authentication
    @State private var authManager: SupabaseAuthManager

    // Live Activity Manager
    let liveActivityManager: LiveActivityManagerProtocol

    // Deep link handling
    @State private var pendingDeepLink: DeepLink?

    // Services
    let tagService: TagServiceProtocol

    // Use cases - stubbed implementations
    let startSessionUseCase: StartSessionUseCaseProtocol
    let endSessionUseCase: EndSessionUseCaseProtocol
    let getActiveSessionUseCase: GetActiveSessionUseCaseProtocol
    let listSessionsUseCase: ListSessionsUseCaseProtocol
    let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    let updateSessionUseCase: UpdateSessionUseCaseProtocol
    let addClimbUseCase: AddClimbUseCaseProtocol
    let logAttemptUseCase: LogAttemptUseCaseProtocol
    let updateClimbUseCase: UpdateClimbUseCaseProtocol
    let deleteClimbUseCase: DeleteClimbUseCaseProtocol
    let deleteAttemptUseCase: DeleteAttemptUseCaseProtocol
    let createPostUseCase: CreatePostUseCaseProtocol
    let toggleFollowUseCase: ToggleFollowUseCaseProtocol
    let searchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol

    // Profile-related use cases (Phase 6)
    let updateProfileUseCase: UpdateProfileUseCaseProtocol
    let searchProfilesUseCase: SearchProfilesUseCaseProtocol
    let fetchProfileUseCase: FetchProfileUseCaseProtocol
    let uploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol
    let getFollowersUseCase: GetFollowersUseCaseProtocol
    let getFollowingUseCase: GetFollowingUseCaseProtocol

    // Premium service - recreated on auth state change
    @State private var premiumService: PremiumServiceProtocol?

    // Sync actor - recreated on auth state change
    @State private var syncActor: SyncActor?
    @State private var periodicSyncTask: Task<Void, Never>?

    // Store repository and client for recreating services after login
    private let supabaseRepository: SupabaseRepository
    private let supabaseClient: SupabaseClientActor

    init() {
        modelContainer = SwiftDataContainer.shared.container

        // Initialize Supabase auth
        let supabaseClient = SupabaseClientActor(config: .shared)
        self.supabaseClient = supabaseClient
        let repository = SupabaseRepository(client: supabaseClient)
        self.supabaseRepository = repository
        let profilesTable = ProfilesTable(repository: repository)
        let authMgr = SupabaseAuthManager(client: supabaseClient, profilesTable: profilesTable)
        self._authManager = State(initialValue: authMgr)

        // Initialize table actors
        let followsTable = FollowsTable(repository: repository)

        // Initialize Live Activity Manager
        let liveActivityMgr = LiveActivityManager()
        self.liveActivityManager = liveActivityMgr

        // Initialize services
        let sessionService = SessionService(modelContainer: modelContainer)
        let climbService = ClimbService(modelContainer: modelContainer)
        let attemptService = AttemptService(modelContainer: modelContainer)
        let tagsTable = TagsTable(repository: repository)
        let tagService = TagService(modelContainer: modelContainer, tagsTable: tagsTable)
        self.tagService = tagService
        let socialService = SocialServiceImpl(
            modelContainer: modelContainer,
            followsTable: followsTable,
            profilesTable: profilesTable
        )

        // Initialize Profile services (Phase 6)
        let storageService = StorageServiceImpl(
            config: .shared,
            httpClient: HTTPClient(),
            supabaseClient: supabaseClient
        )

        let profileService = ProfileServiceImpl(
            modelContainer: modelContainer,
            profilesTable: profilesTable
        )

        // Premium service starts nil, created after authentication
        self._premiumService = State(initialValue: nil)

        // Initialize use cases with services and Live Activity Manager
        startSessionUseCase = StartSessionUseCase(
            sessionService: sessionService,
            liveActivityManager: liveActivityMgr
        )
        endSessionUseCase = EndSessionUseCase(
            sessionService: sessionService,
            liveActivityManager: liveActivityMgr
        )
        getActiveSessionUseCase = GetActiveSessionUseCase(sessionService: sessionService)
        listSessionsUseCase = ListSessionsUseCase(sessionService: sessionService)
        deleteSessionUseCase = DeleteSessionUseCase(sessionService: sessionService)
        updateSessionUseCase = UpdateSessionUseCase(sessionService: sessionService)
        addClimbUseCase = AddClimbUseCase(
            climbService: climbService,
            attemptService: attemptService,
            tagService: tagService,
            liveActivityManager: liveActivityMgr
        )
        logAttemptUseCase = LogAttemptUseCase(
            attemptService: attemptService,
            liveActivityManager: liveActivityMgr
        )
        updateClimbUseCase = UpdateClimbUseCase(climbService: climbService, tagService: tagService)
        deleteClimbUseCase = DeleteClimbUseCase(
            climbService: climbService,
            liveActivityManager: liveActivityMgr
        )
        deleteAttemptUseCase = DeleteAttemptUseCase(
            attemptService: attemptService,
            liveActivityManager: liveActivityMgr
        )
        createPostUseCase = CreatePostUseCase(socialService: socialService)
        toggleFollowUseCase = ToggleFollowUseCase(socialService: socialService)
        searchOpenBetaUseCase = SearchOpenBetaUseCase(premiumService: nil)

        // Initialize Profile use cases (Phase 6)
        updateProfileUseCase = UpdateProfileUseCase(profileService: profileService)
        searchProfilesUseCase = SearchProfilesUseCase(profileService: profileService)
        fetchProfileUseCase = FetchProfileUseCase(profileService: profileService)
        uploadProfilePhotoUseCase = UploadProfilePhotoUseCase(
            storageService: storageService,
            profileService: profileService
        )
        getFollowersUseCase = GetFollowersUseCase(socialService: socialService)
        getFollowingUseCase = GetFollowingUseCase(socialService: socialService)
    }

    #if DEBUG
    @State private var devBypassEnabled = false
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    ScenePhaseSyncWrapper {
                        ContentView()
                    } onForeground: {
                        Task {
                            await handleForegroundTransition()
                        }
                    }
                    .environment(\.authManager, authManager)
                    .environment(\.currentUserId, currentUserId)
                    .environment(\.startSessionUseCase, startSessionUseCase)
                    .environment(\.endSessionUseCase, endSessionUseCase)
                    .environment(\.getActiveSessionUseCase, getActiveSessionUseCase)
                    .environment(\.listSessionsUseCase, listSessionsUseCase)
                    .environment(\.deleteSessionUseCase, deleteSessionUseCase)
                    .environment(\.updateSessionUseCase, updateSessionUseCase)
                    .environment(\.addClimbUseCase, addClimbUseCase)
                    .environment(\.logAttemptUseCase, logAttemptUseCase)
                    .environment(\.updateClimbUseCase, updateClimbUseCase)
                    .environment(\.deleteClimbUseCase, deleteClimbUseCase)
                    .environment(\.deleteAttemptUseCase, deleteAttemptUseCase)
                    .environment(\.createPostUseCase, createPostUseCase)
                    .environment(\.toggleFollowUseCase, toggleFollowUseCase)
                    .environment(\.searchOpenBetaUseCase, searchOpenBetaUseCase)
                    .environment(\.premiumService, premiumService)
                    // Profile use cases (Phase 6)
                    .environment(\.updateProfileUseCase, updateProfileUseCase)
                    .environment(\.searchProfilesUseCase, searchProfilesUseCase)
                    .environment(\.fetchProfileUseCase, fetchProfileUseCase)
                    .environment(\.uploadProfilePhotoUseCase, uploadProfilePhotoUseCase)
                    .environment(\.getFollowersUseCase, getFollowersUseCase)
                    .environment(\.getFollowingUseCase, getFollowingUseCase)
                    // Services
                    .environment(\.tagService, tagService)
                    // Sync actor
                    .environment(\.syncActor, syncActor)
                    // Live Activity Manager
                    .environment(\.liveActivityManager, liveActivityManager)
                    // Deep link handling
                    .environment(\.pendingDeepLink, $pendingDeepLink)
                } else {
                    #if DEBUG
                    AuthView(authManager: authManager, onDevBypass: {
                        devBypassEnabled = true
                    })
                    #else
                    AuthView(authManager: authManager)
                    #endif
                }
            }
            .onOpenURL { url in
                // Handle deep links from Live Activity and other sources
                pendingDeepLink = DeepLink(url: url)
            }
            .task {
                await authManager.loadSession()
                // Sync profile to SwiftData after session restore
                if authManager.isAuthenticated {
                    await syncCurrentUserProfile()
                    // Sync tags from Supabase (needed before impacts can sync)
                    try? await tagService.syncTagsFromRemote()
                    // Initialize sync actor and perform initial sync
                    initializeSyncActor()
                    await performInitialSync()
                    startPeriodicSync()
                }
            }
            .task(id: premiumService != nil) {
                // Listen for StoreKit transaction updates when service exists
                await premiumService?.listenForTransactionUpdates()
            }
            .onChange(of: authManager.isAuthenticated) { oldValue, isAuthenticated in
                updatePremiumService(isAuthenticated: isAuthenticated)

                if isAuthenticated {
                    // User signed in - sync tags first, then initialize data sync
                    Task {
                        try? await tagService.syncTagsFromRemote()
                    }
                    initializeSyncActor()
                    Task {
                        await performInitialSync()
                    }
                    startPeriodicSync()
                } else {
                    // User signed out - stop sync
                    stopSync()
                }

                // Clear local data when user signs out
                if oldValue && !isAuthenticated {
                    clearLocalUserData()
                }

                // Sync profile to SwiftData when user signs in
                if !oldValue && isAuthenticated {
                    Task {
                        await syncCurrentUserProfile()
                    }
                }
            }
            #if DEBUG
            .onChange(of: devBypassEnabled) { _, enabled in
                if enabled {
                    Task {
                        await createDevProfile()
                        // Sync tags from remote for dev mode too
                        try? await tagService.syncTagsFromRemote()
                    }
                    updatePremiumService(isAuthenticated: true)
                    initializeSyncActor()
                    Task {
                        await performInitialSync()
                    }
                    startPeriodicSync()
                }
            }
            #endif
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Premium Service Lifecycle

    @MainActor
    private func updatePremiumService(isAuthenticated: Bool) {
        if isAuthenticated, let userId = currentUserId {
            let premiumSync = PremiumSyncImpl(repository: supabaseRepository)
            let context = modelContainer.mainContext
            premiumService = PremiumServiceImpl(
                modelContext: context,
                userId: userId,
                supabaseSync: premiumSync
            )
        } else {
            premiumService = nil
        }
    }

    // MARK: - Local Data Management

    /// Syncs the current user's profile from Supabase to SwiftData after sign in.
    ///
    /// This ensures the local SwiftData store has the user's profile available
    /// for offline-first access. The profile from `authManager.currentProfile`
    /// is converted to an `SCProfile` model and saved locally.
    @MainActor
    private func syncCurrentUserProfile() async {
        guard let dto = authManager.currentProfile else { return }

        let context = modelContainer.mainContext

        // Check if profile already exists locally
        let profileId = dto.id
        let descriptor = FetchDescriptor<SCProfile>(
            predicate: #Predicate<SCProfile> { profile in
                profile.id == profileId
            }
        )

        if let existingProfile = try? context.fetch(descriptor).first {
            // Update existing profile with remote data
            existingProfile.handle = dto.handle
            existingProfile.photoURL = dto.photoURL
            existingProfile.homeZIP = dto.homeZIP
            existingProfile.preferredGradeScaleBoulder = GradeScale(rawValue: dto.preferredGradeScaleBoulder) ?? .v
            existingProfile.preferredGradeScaleRoute = GradeScale(rawValue: dto.preferredGradeScaleRoute) ?? .yds
            existingProfile.isPublic = dto.isPublic
            existingProfile.displayName = dto.displayName
            existingProfile.bio = dto.bio
            existingProfile.homeGym = dto.homeGym
            existingProfile.climbingSince = dto.climbingSince
            existingProfile.favoriteStyle = dto.favoriteStyle
            existingProfile.followerCount = dto.followerCount
            existingProfile.followingCount = dto.followingCount
            existingProfile.sendCount = dto.sendCount
            existingProfile.updatedAt = dto.updatedAt
            existingProfile.needsSync = false
        } else {
            // Create new local profile
            let profile = SCProfile(
                id: dto.id,
                handle: dto.handle,
                photoURL: dto.photoURL,
                homeZIP: dto.homeZIP,
                preferredGradeScaleBoulder: GradeScale(rawValue: dto.preferredGradeScaleBoulder) ?? .v,
                preferredGradeScaleRoute: GradeScale(rawValue: dto.preferredGradeScaleRoute) ?? .yds,
                isPublic: dto.isPublic,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                displayName: dto.displayName,
                bio: dto.bio,
                homeGym: dto.homeGym,
                climbingSince: dto.climbingSince,
                favoriteStyle: dto.favoriteStyle,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount,
                needsSync: false
            )
            context.insert(profile)
        }

        do {
            try context.save()
        } catch {
            print("Failed to sync profile to SwiftData: \(error)")
        }
    }

    /// Clears all local user data from SwiftData when signing out.
    ///
    /// This ensures that when a different user signs in, they don't see
    /// the previous user's cached data. Data will be re-synced from Supabase
    /// when the new user signs in.
    ///
    /// ## Why We Clear ALL Data (Not Filtered by UserId)
    ///
    /// This app follows a single-user-per-device offline-first architecture:
    /// - Only ONE user's profile exists in SwiftData at any time
    /// - Other users' profiles are fetched from network without local caching
    /// - Sessions, climbs, and attempts all belong to the current user
    ///
    /// Therefore, clearing ALL data is correct and efficient. We use batch
    /// delete (`context.delete(model:)`) for performance rather than fetching
    /// and deleting individual records filtered by userId.
    ///
    /// If the architecture changes to cache multiple users' data (e.g., for
    /// offline viewing of followed users' profiles), this function should be
    /// updated to filter by the signing-out user's ID.
    @MainActor
    private func clearLocalUserData() {
        let context = modelContainer.mainContext

        // Delete all profiles (only current user's profile exists locally)
        do {
            try context.delete(model: SCProfile.self)
        } catch {
            print("Failed to delete profiles: \(error)")
        }

        // Delete all sessions (all belong to current user)
        do {
            try context.delete(model: SCSession.self)
        } catch {
            print("Failed to delete sessions: \(error)")
        }

        // Delete all climbs (all belong to current user)
        do {
            try context.delete(model: SCClimb.self)
        } catch {
            print("Failed to delete climbs: \(error)")
        }

        // Delete all attempts (all belong to current user)
        do {
            try context.delete(model: SCAttempt.self)
        } catch {
            print("Failed to delete attempts: \(error)")
        }

        // Save the deletions
        do {
            try context.save()
        } catch {
            print("Failed to save after clearing data: \(error)")
        }
    }

    #if DEBUG
    // MARK: - Dev Profile Creation

    @MainActor
    private func createDevProfile() async {
        let context = modelContainer.mainContext
        let mockId = DevSettings.mockUserId
        let descriptor = FetchDescriptor<SCProfile>(
            predicate: #Predicate<SCProfile> { profile in
                profile.id == mockId
            }
        )

        // Only create if doesn't exist
        if (try? context.fetch(descriptor).first) == nil {
            let profile = SCProfile(
                id: DevSettings.mockUserId,
                handle: "dev_user",
                isPublic: true,
                displayName: "Dev User",
                bio: "Test profile for development"
            )
            context.insert(profile)
            try? context.save()
        }
    }
    #endif

    // MARK: - Sync Lifecycle

    @MainActor
    private func initializeSyncActor() {
        syncActor = SyncActor(
            modelContainer: modelContainer,
            supabaseClient: supabaseClient
        )
    }

    @MainActor
    private func performInitialSync() async {
        guard let syncActor = syncActor, let userId = currentUserId else { return }

        do {
            try await syncActor.performSync(userId: userId)
        } catch {
            print("Initial sync failed: \(error)")
        }
    }

    @MainActor
    private func startPeriodicSync() {
        periodicSyncTask?.cancel()

        periodicSyncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))

                guard !Task.isCancelled else { break }

                if let syncActor = syncActor, let userId = currentUserId {
                    do {
                        try await syncActor.performSync(userId: userId)
                    } catch {
                        print("Periodic sync failed: \(error)")
                    }
                }
            }
        }
    }

    @MainActor
    private func stopSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
        syncActor = nil
    }

    @MainActor
    private func handleForegroundTransition() async {
        guard let syncActor = syncActor, let userId = currentUserId else { return }

        do {
            try await syncActor.performSync(userId: userId)
        } catch {
            print("Foreground sync failed: \(error)")
        }
    }

    // MARK: - Auth Helpers

    private var isAuthenticated: Bool {
        #if DEBUG
        if devBypassEnabled {
            return true
        }
        #endif
        return authManager.isAuthenticated
    }

    private var currentUserId: UUID? {
        #if DEBUG
        if devBypassEnabled {
            return DevSettings.mockUserId
        }
        #endif
        return authManager.currentUserId
    }
}

// MARK: - Scene Phase Sync Wrapper

/// Wrapper view that observes scenePhase and triggers sync on foreground transition.
@MainActor
struct ScenePhaseSyncWrapper<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    let content: Content
    let onForeground: () -> Void

    init(@ViewBuilder content: () -> Content, onForeground: @escaping () -> Void) {
        self.content = content()
        self.onForeground = onForeground
    }

    var body: some View {
        content
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if oldPhase != .active && newPhase == .active {
                    onForeground()
                }
            }
    }
}
