import SwiftUI

@MainActor
struct FollowingListView: View {
    // MARK: - Input
    let userId: UUID
    let userName: String

    // MARK: - Environment
    @Environment(\.getFollowingUseCase) private var getFollowingUseCase
    @Environment(\.toggleFollowUseCase) private var toggleFollowUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - List State
    @State private var following: [ProfileSearchResult] = []
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
            if isLoading && following.isEmpty {
                loadingView
            } else if let error = loadError, following.isEmpty {
                errorView(error)
            } else if following.isEmpty {
                emptyView
            } else {
                followingList
            }
        }
        .navigationTitle("\(userName) Follows")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFollowing()
        }
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: SCSpacing.md) {
            ProgressView()
            Text("Loading...")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Following", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await loadFollowing()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyView: some View {
        ContentUnavailableView(
            "Not Following Anyone",
            systemImage: "person.2",
            description: Text("\(userName) isn't following anyone yet")
        )
    }

    // MARK: - Following List

    @ViewBuilder
    private var followingList: some View {
        List {
            ForEach(following) { profile in
                NavigationLink(value: ProfileNavigation.otherProfile(userId: profile.id)) {
                    ProfileRowView(
                        id: profile.id,
                        handle: profile.handle,
                        displayName: profile.displayName,
                        photoURL: profile.photoURL,
                        trailingContent: {
                            if profile.id != currentUserId {
                                FollowButton(
                                    isFollowing: followingIds.contains(profile.id),
                                    isLoading: loadingFollowIds.contains(profile.id),
                                    onTap: {
                                        Task {
                                            await toggleFollow(profile.id)
                                        }
                                    }
                                )
                            }
                        }
                    )
                }
                .onAppear {
                    if profile.id == following.last?.id {
                        Task {
                            await loadMoreFollowing()
                        }
                    }
                }
            }

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

    private func loadFollowing() async {
        guard let useCase = getFollowingUseCase else {
            loadError = "Following list not available"
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

            following = results
            hasMorePages = results.count == pageSize
            currentOffset = results.count

            await checkFollowStatus(for: results)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMoreFollowing() async {
        guard !isLoadingMore,
              hasMorePages,
              let useCase = getFollowingUseCase else {
            return
        }

        isLoadingMore = true

        do {
            let results = try await useCase.execute(
                userId: userId,
                limit: pageSize,
                offset: currentOffset
            )

            following.append(contentsOf: results)
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
        FollowingListView(userId: UUID(), userName: "Alex Chen")
    }
}
