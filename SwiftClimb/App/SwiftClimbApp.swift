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

    // Premium service
    let premiumService: PremiumServiceProtocol?

    init() {
        modelContainer = SwiftDataContainer.shared.container

        // Initialize Supabase auth
        let supabaseClient = SupabaseClientActor(config: .shared)
        let supabaseRepository = SupabaseRepository(client: supabaseClient)
        let profilesTable = ProfilesTable(repository: supabaseRepository)
        let authMgr = SupabaseAuthManager(client: supabaseClient, profilesTable: profilesTable)
        self._authManager = State(initialValue: authMgr)

        // Initialize services (stubs)
        let sessionService = SessionService()
        let climbService = ClimbService()
        let attemptService = AttemptService()
        let socialService = SocialService()

        // Initialize premium service (only if authenticated)
        if let userId = authMgr.currentUserId {
            let premiumSync = PremiumSyncImpl(repository: supabaseRepository)
            premiumService = PremiumServiceImpl(
                modelContext: modelContainer.mainContext,
                userId: userId,
                supabaseSync: premiumSync
            )
        } else {
            premiumService = nil
        }

        // Initialize use cases with services (some need premium service)
        startSessionUseCase = StartSessionUseCase(sessionService: sessionService)
        endSessionUseCase = EndSessionUseCase(sessionService: sessionService)
        addClimbUseCase = AddClimbUseCase(climbService: climbService)
        logAttemptUseCase = LogAttemptUseCase(attemptService: attemptService)
        createPostUseCase = CreatePostUseCase(socialService: socialService)
        toggleFollowUseCase = ToggleFollowUseCase(socialService: socialService)
        searchOpenBetaUseCase = SearchOpenBetaUseCase(premiumService: premiumService)
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
            .task {
                // Listen for StoreKit transaction updates
                await premiumService?.listenForTransactionUpdates()
            }
        }
        .modelContainer(modelContainer)
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
