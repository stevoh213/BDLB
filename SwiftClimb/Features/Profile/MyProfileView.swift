import SwiftUI
import SwiftData
import PhotosUI

@MainActor
struct MyProfileView: View {
    // MARK: - Data Queries
    @Query private var profiles: [SCProfile]

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.authManager) private var authManager
    @Environment(\.currentUserId) private var currentUserId
    @Environment(\.uploadProfilePhotoUseCase) private var uploadProfilePhotoUseCase

    // MARK: - View State
    @State private var showingEditSheet = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()

    // MARK: - Computed Properties

    /// Returns the current user's profile by filtering the query results.
    ///
    /// Note: We filter in the computed property rather than the `@Query` predicate
    /// because `currentUserId` comes from Environment and isn't available at
    /// property initialization time.
    private var currentProfile: SCProfile? {
        guard let userId = currentUserId else { return nil }
        return profiles.first { $0.id == userId }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    if let profile = currentProfile {
                        profileContent(profile)
                    } else {
                        emptyProfileView
                    }

                    if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    }

                    signOutButton
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    .disabled(currentProfile == nil)
                }
            }
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
        }
        .sheet(isPresented: $showingEditSheet) {
            if let profile = currentProfile {
                EditProfileView(profile: profile)
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await handlePhotoSelection(newValue)
            }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ profile: SCProfile) -> some View {
        VStack(spacing: SCSpacing.lg) {
            // Header with editable avatar
            ProfileHeaderView(
                handle: profile.handle,
                displayName: profile.displayName,
                photoURL: profile.photoURL,
                bio: profile.bio,
                homeGym: profile.homeGym,
                isEditable: true,
                onAvatarTap: { showingPhotoPicker = true }
            )

            // Photo upload indicator
            if isUploadingPhoto {
                ProgressView("Uploading photo...")
                    .font(SCTypography.secondary)
            }

            // Stats with navigation
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
                onSendsTap: nil  // Sends list not implemented in this phase
            )

            // Additional profile info sections
            profileInfoSection(profile)
        }
    }

    @ViewBuilder
    private func profileInfoSection(_ profile: SCProfile) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            // Climbing preferences
            if let yearsClimbing = profile.yearsClimbing {
                InfoRow(
                    label: "Climbing Since",
                    value: "\(yearsClimbing) years"
                )
            }

            if let favoriteStyle = profile.favoriteStyle {
                InfoRow(label: "Favorite Style", value: favoriteStyle)
            }

            InfoRow(
                label: "Boulder Grade Scale",
                value: profile.preferredGradeScaleBoulder.rawValue
            )

            InfoRow(
                label: "Route Grade Scale",
                value: profile.preferredGradeScaleRoute.rawValue
            )

            InfoRow(
                label: "Profile Visibility",
                value: profile.isPublic ? "Public" : "Private"
            )
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyProfileView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Profile Found")
                .font(SCTypography.sectionHeader)

            Text("Create your profile to get started")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(SCTypography.secondary)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
    }

    // MARK: - Sign Out Button

    @ViewBuilder
    private var signOutButton: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .font(SCTypography.body)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(SCColors.surfaceSecondary)
                .cornerRadius(SCCornerRadius.card)
        }
    }

    // MARK: - Actions

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        await uploadPhoto(image)
    }

    private func uploadPhoto(_ image: UIImage) async {
        guard let useCase = uploadProfilePhotoUseCase,
              let profile = currentProfile,
              let userId = currentUserId else {
            errorMessage = "Unable to upload photo"
            return
        }

        isUploadingPhoto = true
        errorMessage = nil

        do {
            _ = try await useCase.execute(
                image: image,
                userId: userId,
                profileId: profile.id
            )
            // Profile will update via SwiftData observation
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploadingPhoto = false
    }

    private func signOut() {
        guard let authManager = authManager else {
            errorMessage = "Auth service not available"
            return
        }

        Task {
            await authManager.signOut()
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
            Spacer()
            Text(value)
                .font(SCTypography.body)
        }
    }
}

#Preview {
    MyProfileView()
}
