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

    // Use cases - stubbed implementations
    let startSessionUseCase: StartSessionUseCaseProtocol
    let endSessionUseCase: EndSessionUseCaseProtocol
    let addClimbUseCase: AddClimbUseCaseProtocol
    let logAttemptUseCase: LogAttemptUseCaseProtocol
    let createPostUseCase: CreatePostUseCaseProtocol
    let toggleFollowUseCase: ToggleFollowUseCaseProtocol
    let searchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol

    // Premium service - recreated on auth state change
    @State private var premiumService: PremiumServiceProtocol?

    // Store repository for recreating premium service after login
    private let supabaseRepository: SupabaseRepository

    init() {
        modelContainer = SwiftDataContainer.shared.container

        // Initialize Supabase auth
        let supabaseClient = SupabaseClientActor(config: .shared)
        let repository = SupabaseRepository(client: supabaseClient)
        self.supabaseRepository = repository
        let profilesTable = ProfilesTable(repository: repository)
        let authMgr = SupabaseAuthManager(client: supabaseClient, profilesTable: profilesTable)
        self._authManager = State(initialValue: authMgr)

        // Initialize services (stubs)
        let sessionService = SessionService()
        let climbService = ClimbService()
        let attemptService = AttemptService()
        let socialService = SocialService()

        // Premium service starts nil, created after authentication
        self._premiumService = State(initialValue: nil)

        // Initialize use cases with services
        startSessionUseCase = StartSessionUseCase(sessionService: sessionService)
        endSessionUseCase = EndSessionUseCase(sessionService: sessionService)
        addClimbUseCase = AddClimbUseCase(climbService: climbService)
        logAttemptUseCase = LogAttemptUseCase(attemptService: attemptService)
        createPostUseCase = CreatePostUseCase(socialService: socialService)
        toggleFollowUseCase = ToggleFollowUseCase(socialService: socialService)
        searchOpenBetaUseCase = SearchOpenBetaUseCase(premiumService: nil)
    }

    #if DEBUG
    @State private var devBypassEnabled = false
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    ContentView()
                        .environment(\.authManager, authManager)
                        .environment(\.currentUserId, currentUserId)
                        .environment(\.startSessionUseCase, startSessionUseCase)
                        .environment(\.endSessionUseCase, endSessionUseCase)
                        .environment(\.addClimbUseCase, addClimbUseCase)
                        .environment(\.logAttemptUseCase, logAttemptUseCase)
                        .environment(\.createPostUseCase, createPostUseCase)
                        .environment(\.toggleFollowUseCase, toggleFollowUseCase)
                        .environment(\.searchOpenBetaUseCase, searchOpenBetaUseCase)
                        .environment(\.premiumService, premiumService)
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
            .task {
                await authManager.loadSession()
            }
            .task(id: premiumService != nil) {
                // Listen for StoreKit transaction updates when service exists
                await premiumService?.listenForTransactionUpdates()
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                updatePremiumService(isAuthenticated: isAuthenticated)
            }
            #if DEBUG
            .onChange(of: devBypassEnabled) { _, enabled in
                if enabled {
                    updatePremiumService(isAuthenticated: true)
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
