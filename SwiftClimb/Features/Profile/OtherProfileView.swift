import SwiftUI

@MainActor
struct OtherProfileView: View {
    // MARK: - Input
    let userId: UUID

    // MARK: - Environment
    @Environment(\.currentUserId) private var currentUserId
    @Environment(\.toggleFollowUseCase) private var toggleFollowUseCase
    @Environment(\.fetchProfileUseCase) private var fetchProfileUseCase

    // MARK: - Remote Data State
    @State private var profile: ProfileSearchResult?
    @State private var isLoading = true
    @State private var loadError: String?

    // MARK: - Follow State
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var followError: String?

    // MARK: - Navigation
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.lg) {
                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else if let profile = profile {
                    if profile.isPublic {
                        publicProfileContent(profile)
                    } else {
                        privateProfileContent(profile)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(profile?.displayName ?? profile?.handle ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ProfileNavigation.self) { destination in
            switch destination {
            case .followers(let userId, let userName):
                FollowersListView(userId: userId, userName: userName)
            case .following(let userId, let userName):
                FollowingListView(userId: userId, userName: userName)
            case .otherProfile(let userId):
                OtherProfileView(userId: userId)
            }
        }
        .task {
            await loadProfile()
            await checkFollowStatus()
        }
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: SCSpacing.md) {
            ProgressView()
            Text("Loading profile...")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(SCColors.textSecondary)

            Text("Couldn't load profile")
                .font(SCTypography.sectionHeader)

            Text(message)
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await loadProfile()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Public Profile Content

    @ViewBuilder
    private func publicProfileContent(_ profile: ProfileSearchResult) -> some View {
        VStack(spacing: SCSpacing.lg) {
            // Header
            ProfileHeaderView(
                handle: profile.handle,
                displayName: profile.displayName,
                photoURL: profile.photoURL,
                bio: profile.bio,
                homeGym: nil,  // Not included in search result
                isEditable: false,
                onAvatarTap: nil
            )

            // Follow button (don't show for own profile)
            if currentUserId != userId {
                FollowButton(
                    isFollowing: isFollowing,
                    isLoading: isFollowLoading,
                    onTap: {
                        Task {
                            await toggleFollow()
                        }
                    }
                )
            }

            // Stats
            ProfileStatsView(
                followerCount: profile.followerCount,
                followingCount: profile.followingCount,
                sendCount: profile.sendCount,
                onFollowersTap: {
                    navigationPath.append(
                        ProfileNavigation.followers(
                            userId: profile.id,
                            userName: profile.displayName ?? profile.handle
                        )
                    )
                },
                onFollowingTap: {
                    navigationPath.append(
                        ProfileNavigation.following(
                            userId: profile.id,
                            userName: profile.displayName ?? profile.handle
                        )
                    )
                },
                onSendsTap: nil
            )

            // Error message for follow action
            if let followError = followError {
                Text(followError)
                    .font(SCTypography.secondary)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Private Profile Content

    @ViewBuilder
    private func privateProfileContent(_ profile: ProfileSearchResult) -> some View {
        VStack(spacing: SCSpacing.lg) {
            // Limited header (no bio)
            ProfileAvatarView(
                photoURL: profile.photoURL,
                size: .large,
                isEditable: false
            )

            VStack(spacing: SCSpacing.xxs) {
                Text(profile.displayName ?? profile.handle)
                    .font(SCTypography.screenHeader)
                    .fontWeight(.bold)

                Text("@\(profile.handle)")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }

            // Private indicator
            VStack(spacing: SCSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(SCColors.textSecondary)

                Text("This profile is private")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }
            .padding(.top, SCSpacing.lg)

            // Follow button still available
            if currentUserId != userId {
                FollowButton(
                    isFollowing: isFollowing,
                    isLoading: isFollowLoading,
                    onTap: {
                        Task {
                            await toggleFollow()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        loadError = nil

        guard let useCase = fetchProfileUseCase else {
            loadError = "Profile service not available"
            isLoading = false
            return
        }

        do {
            profile = try await useCase.execute(profileId: userId)
        } catch let error as FetchProfileError {
            loadError = error.localizedDescription
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func checkFollowStatus() async {
        guard let currentUserId = currentUserId,
              let useCase = toggleFollowUseCase else {
            return
        }

        isFollowing = await useCase.isFollowing(
            followerId: currentUserId,
            followeeId: userId
        )
    }

    private func toggleFollow() async {
        guard let currentUserId = currentUserId,
              let useCase = toggleFollowUseCase else {
            followError = "Unable to follow"
            return
        }

        isFollowLoading = true
        followError = nil

        do {
            isFollowing = try await useCase.execute(
                followerId: currentUserId,
                followeeId: userId
            )
        } catch {
            followError = error.localizedDescription
        }

        isFollowLoading = false
    }
}

#Preview {
    NavigationStack {
        OtherProfileView(userId: UUID())
    }
}
