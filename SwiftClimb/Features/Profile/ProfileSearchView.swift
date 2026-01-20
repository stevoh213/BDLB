import SwiftUI

@MainActor
struct ProfileSearchView: View {
    // MARK: - Environment
    @Environment(\.searchProfilesUseCase) private var searchProfilesUseCase
    @Environment(\.toggleFollowUseCase) private var toggleFollowUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - Search State
    @State private var searchText = ""
    @State private var searchResults: [ProfileSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?

    // MARK: - Suggested State
    @State private var suggestedProfiles: [ProfileSearchResult] = []
    @State private var isLoadingSuggested = false

    // MARK: - Follow State (track per-profile loading)
    @State private var followingIds: Set<UUID> = []
    @State private var loadingFollowIds: Set<UUID> = []

    // MARK: - Navigation
    @State private var navigationPath = NavigationPath()

    // MARK: - Search Debounce
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if searchText.isEmpty {
                    suggestedSection
                } else {
                    searchResultsSection
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by name or @handle"
            )
            .navigationTitle("Find Climbers")
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
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            .task {
                await loadSuggestedProfiles()
            }
        }
    }

    // MARK: - Suggested Profiles Section

    @ViewBuilder
    private var suggestedSection: some View {
        Section {
            if isLoadingSuggested {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if suggestedProfiles.isEmpty {
                ContentUnavailableView(
                    "No Suggestions",
                    systemImage: "person.2",
                    description: Text("Start typing to search for climbers")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(suggestedProfiles) { profile in
                    profileRow(profile)
                }
            }
        } header: {
            Text("Suggested")
                .font(SCTypography.secondary)
        }
    }

    // MARK: - Search Results Section

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let error = searchError {
                VStack(spacing: SCSpacing.sm) {
                    Text("Search failed")
                        .font(SCTypography.cardTitle)
                    Text(error)
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
                .listRowBackground(Color.clear)
            } else if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(searchResults) { profile in
                    profileRow(profile)
                }
            }
        } header: {
            Text("Results")
                .font(SCTypography.secondary)
        }
    }

    // MARK: - Profile Row

    @ViewBuilder
    private func profileRow(_ profile: ProfileSearchResult) -> some View {
        ProfileRowView(
            id: profile.id,
            handle: profile.handle,
            displayName: profile.displayName,
            photoURL: profile.photoURL,
            trailingContent: {
                // Only show follow button for other users
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
            },
            onTap: {
                navigationPath.append(ProfileNavigation.otherProfile(userId: profile.id))
            }
        )
    }

    // MARK: - Search Logic

    private func handleSearchTextChange(_ newValue: String) {
        // Cancel previous search
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results if query too short
        guard trimmed.count >= 2 else {
            searchResults = []
            searchError = nil
            return
        }

        // Debounce search
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) async {
        guard let useCase = searchProfilesUseCase else {
            searchError = "Search not available"
            return
        }

        isSearching = true
        searchError = nil

        do {
            searchResults = try await useCase.execute(query: query, limit: 20)

            // Check follow status for results
            await checkFollowStatus(for: searchResults)
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }

        isSearching = false
    }

    private func loadSuggestedProfiles() async {
        guard let useCase = searchProfilesUseCase else { return }

        isLoadingSuggested = true

        // Load "suggested" by searching for popular handles or empty query
        // This is a placeholder - in production, you'd have a dedicated endpoint
        do {
            // For MVP, just load some profiles (could be recent signups, etc.)
            suggestedProfiles = try await useCase.execute(query: "climber", limit: 10)
            await checkFollowStatus(for: suggestedProfiles)
        } catch {
            // Silently fail for suggestions
            suggestedProfiles = []
        }

        isLoadingSuggested = false
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
            // Silent failure for follow toggle in list
        }

        loadingFollowIds.remove(profileId)
    }
}

#Preview {
    ProfileSearchView()
}
