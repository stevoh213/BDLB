import SwiftUI
import SwiftData

@MainActor
struct FeedView: View {
    // Query posts sorted by creation date
    @Query(
        filter: #Predicate<SCPost> { $0.deletedAt == nil },
        sort: \SCPost.createdAt,
        order: .reverse
    )
    private var posts: [SCPost]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.feedUseCase) private var feedUseCase

    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if posts.isEmpty {
                    emptyStateView
                } else {
                    feedListView
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(SCTypography.secondary)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Feed")
        }
        .task {
            await loadFeed()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Posts Yet")
                .font(SCTypography.sectionHeader)

            Text("Follow climbers to see their sessions and achievements")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: SCSpacing.md) {
                ForEach(posts) { post in
                    postRow(post)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func postRow(_ post: SCPost) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Post from \(post.authorId.uuidString.prefix(8))...")
                .font(SCTypography.body)

            if let content = post.content {
                Text(content)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }

            HStack(spacing: SCSpacing.md) {
                Button(action: {
                    Task {
                        await toggleKudos(for: post)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(post.kudosCount)")
                    }
                    .font(SCTypography.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentCount)")
                }
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(12)
    }

    private func loadFeed() async {
        guard let feedUseCase = feedUseCase else {
            errorMessage = "Feed service not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let remotePosts = try await feedUseCase.loadFeed()
            // Insert remote posts into local database
            for remotePost in remotePosts {
                modelContext.insert(remotePost)
            }
            try modelContext.save()
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func toggleKudos(for post: SCPost) async {
        guard let feedUseCase = feedUseCase else {
            errorMessage = "Feed service not available"
            return
        }

        do {
            try await feedUseCase.toggleKudos(postId: post.id)
        } catch {
            errorMessage = "Failed to toggle kudos: \(error.localizedDescription)"
        }
    }
}

#Preview {
    FeedView()
}
