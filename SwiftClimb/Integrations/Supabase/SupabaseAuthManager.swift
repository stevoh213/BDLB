import Foundation
import Observation

/// High-level authentication operations with observable state
@MainActor
@Observable
final class SupabaseAuthManager {
    private let client: SupabaseClientActor
    private let profilesTable: ProfilesTable

    // Observable auth state
    private(set) var currentSession: AuthSession?
    private(set) var currentProfile: ProfileDTO?
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    init(client: SupabaseClientActor, profilesTable: ProfilesTable) {
        self.client = client
        self.profilesTable = profilesTable
    }

    // MARK: - Auth Operations

    func signUp(email: String, password: String, handle: String) async throws {
        isLoading = true
        error = nil

        do {
            // Check if handle is available
            let handleAvailable = try await profilesTable.checkHandleAvailable(handle: handle)
            if !handleAvailable {
                throw AuthError.handleTaken
            }

            // Create auth user
            let metadata = ["handle": handle]
            let session = try await client.signUp(
                email: email,
                password: password,
                metadata: metadata
            )

            // Create profile row with user ID matching auth user ID
            let profile = ProfileDTO(
                id: session.user.id,
                handle: handle,
                photoURL: nil,
                homeZIP: nil,
                preferredGradeScaleBoulder: "V",
                preferredGradeScaleRoute: "YDS",
                isPublic: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            let createdProfile = try await profilesTable.createProfile(profile)

            currentSession = session
            currentProfile = createdProfile
            isAuthenticated = true
            isLoading = false
        } catch let authError as AuthError {
            self.error = authError
            isLoading = false
            throw authError
        } catch {
            // Wrap non-auth errors
            let wrappedError = AuthError.unknown(error.localizedDescription)
            self.error = wrappedError
            isLoading = false
            throw wrappedError
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            // Authenticate user
            let session = try await client.signIn(email: email, password: password)

            // Load or create profile
            if let profile = try await profilesTable.fetchProfile(userId: session.user.id) {
                currentProfile = profile
            } else {
                // Profile doesn't exist (shouldn't happen, but handle gracefully)
                // Create a default profile with email as handle
                let defaultHandle = email.components(separatedBy: "@").first ?? "user"
                let profile = ProfileDTO(
                    id: session.user.id,
                    handle: defaultHandle,
                    photoURL: nil,
                    homeZIP: nil,
                    preferredGradeScaleBoulder: "V",
                    preferredGradeScaleRoute: "YDS",
                    isPublic: false,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                currentProfile = try await profilesTable.createProfile(profile)
            }

            currentSession = session
            isAuthenticated = true
            isLoading = false
        } catch let authError as AuthError {
            self.error = authError
            isLoading = false
            throw authError
        } catch {
            let wrappedError = AuthError.unknown(error.localizedDescription)
            self.error = wrappedError
            isLoading = false
            throw wrappedError
        }
    }

    func signOut() async {
        isLoading = true
        await client.signOut()
        currentSession = nil
        currentProfile = nil
        isAuthenticated = false
        isLoading = false
    }

    func loadSession() async {
        isLoading = true

        do {
            // Try to restore session from Keychain
            if let session = try await client.restoreSession() {
                currentSession = session

                // Load profile for the user
                if let profile = try await profilesTable.fetchProfile(userId: session.user.id) {
                    currentProfile = profile
                    isAuthenticated = true
                } else {
                    // Profile missing - sign out for safety
                    await signOut()
                }
            } else {
                // No session to restore
                isAuthenticated = false
            }
        } catch {
            // Failed to restore session - clear state
            self.error = error
            currentSession = nil
            currentProfile = nil
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    var currentUserId: UUID? {
        currentSession?.user.id
    }

    var currentUserEmail: String? {
        currentSession?.user.email
    }
}
