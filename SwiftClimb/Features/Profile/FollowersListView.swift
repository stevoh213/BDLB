import SwiftUI

@MainActor
struct FollowersListView: View {
    // MARK: - Input
    let userId: UUID
    let userName: String

    // MARK: - Environment
    @Environment(\.getFollowersUseCase) private var getFollowersUseCase
    @Environment(\.toggleFollowUseCase) private var toggleFollowUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - List State
    @State private var followers: [ProfileSearchResult] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadError: String?
    @State private var hasMorePages = true
    @State private var currentOffset = 0

    // MARK: - Follow State
    @State private var followingIds: Set<UUID> = []
    @State private var loadingFollowIds: Set<UUID> = []

    // MARK: - Constants
    private let pageSize = 20

    var body: some View {
        Group {
            if isLoading && followers.isEmpty {
                loadingView
            } else if let error = loadError, followers.isEmpty {
                errorView(error)
            } else if followers.isEmpty {
                emptyView
            } else {
                followersList
            }
        }
        .navigationTitle("\(userName)'s Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFollowers()
        }
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: SCSpacing.md) {
            ProgressView()
            Text("Loading followers...")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Followers", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await loadFollowers()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyView: some View {
        ContentUnavailableView(
            "No Followers Yet",
            systemImage: "person.2",
            description: Text("When people follow \(userName), they'll appear here")
        )
    }

    // MARK: - Followers List

    @ViewBuilder
    private var followersList: some View {
        List {
            ForEach(followers) { follower in
                NavigationLink(value: ProfileNavigation.otherProfile(userId: follower.id)) {
                    ProfileRowView(
                        id: follower.id,
                        handle: follower.handle,
                        displayName: follower.displayName,
                        photoURL: follower.photoURL,
                        trailingContent: {
                            if follower.id != currentUserId {
                                FollowButton(
                                    isFollowing: followingIds.contains(follower.id),
                                    isLoading: loadingFollowIds.contains(follower.id),
                                    onTap: {
                                        Task {
                                            await toggleFollow(follower.id)
                                        }
                                    }
                                )
                            }
                        }
                    )
                }
                .onAppear {
                    // Load more when approaching end
                    if follower.id == followers.last?.id {
                        Task {
                            await loadMoreFollowers()
                        }
                    }
                }
            }

            // Loading more indicator
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadFollowers() async {
        guard let useCase = getFollowersUseCase else {
            loadError = "Followers not available"
            return
        }

        isLoading = true
        loadError = nil
        currentOffset = 0

        do {
            let results = try await useCase.execute(
                userId: userId,
                limit: pageSize,
                offset: 0
            )

            followers = results
            hasMorePages = results.count == pageSize
            currentOffset = results.count

            await checkFollowStatus(for: results)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMoreFollowers() async {
        guard !isLoadingMore,
              hasMorePages,
              let useCase = getFollowersUseCase else {
            return
        }

        isLoadingMore = true

        do {
            let results = try await useCase.execute(
                userId: userId,
                limit: pageSize,
                offset: currentOffset
            )

            followers.append(contentsOf: results)
            hasMorePages = results.count == pageSize
            currentOffset += results.count

            await checkFollowStatus(for: results)
        } catch {
            // Silent failure for pagination
        }

        isLoadingMore = false
    }

    // MARK: - Follow Logic

    private func checkFollowStatus(for profiles: [ProfileSearchResult]) async {
        guard let currentUserId = currentUserId,
              let useCase = toggleFollowUseCase else {
            return
        }

        for profile in profiles {
            if await useCase.isFollowing(followerId: currentUserId, followeeId: profile.id) {
                followingIds.insert(profile.id)
            }
        }
    }

    private func toggleFollow(_ profileId: UUID) async {
        guard let currentUserId = currentUserId,
              let useCase = toggleFollowUseCase else {
            return
        }

        loadingFollowIds.insert(profileId)

        do {
            let isNowFollowing = try await useCase.execute(
                followerId: currentUserId,
                followeeId: profileId
            )

            if isNowFollowing {
                followingIds.insert(profileId)
            } else {
                followingIds.remove(profileId)
            }
        } catch {
            // Silent failure
        }

        loadingFollowIds.remove(profileId)
    }
}

#Preview {
    NavigationStack {
        FollowersListView(userId: UUID(), userName: "Alex Chen")
    }
}
