# Phase 5: Views Specification

> **Feature**: Social Profile Feature - Feature Views
> **Phase**: 5 of 7
> **Status**: Ready for Implementation
> **Created**: 2026-01-19
> **Author**: Agent 1 (Architect)

---

## Table of Contents
1. [Overview](#overview)
2. [Navigation Architecture](#navigation-architecture)
3. [View Specifications](#view-specifications)
   - [5.1 MyProfileView](#51-myprofileview)
   - [5.2 EditProfileView](#52-editprofileview)
   - [5.3 OtherProfileView](#53-otherprofileview)
   - [5.4 ProfileSearchView](#54-profilesearchview)
   - [5.5 FollowersListView](#55-followerslistview)
   - [5.6 FollowingListView](#56-followinglistview)
4. [Shared Patterns](#shared-patterns)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose
Phase 5 builds the feature views that compose Phase 4 components and call Phase 3 use cases. These views follow the MV (Model-View) pattern without ViewModels, using `@Query` for SwiftData observation and `@Environment` for dependency injection.

### View Summary

| View | Purpose | Tab/Navigation |
|------|---------|----------------|
| `MyProfileView` | Display and manage own profile | Profile tab root |
| `EditProfileView` | Edit profile fields in sheet | Sheet from MyProfileView |
| `OtherProfileView` | View another user's profile | Push navigation |
| `ProfileSearchView` | Search/discover climbers | Search icon/tab |
| `FollowersListView` | Display followers list | Push from stats |
| `FollowingListView` | Display following list | Push from stats |

### File Locations

All views will be created/modified in:
```
SwiftClimb/Features/Profile/
  MyProfileView.swift          (NEW - refactored from ProfileView.swift)
  EditProfileView.swift        (NEW - extracted from ProfileView.swift)
  OtherProfileView.swift       (NEW)
  ProfileSearchView.swift      (NEW)
  FollowersListView.swift      (NEW)
  FollowingListView.swift      (NEW)
  ProfileView.swift            (RENAME to MyProfileView.swift)
```

### Key Patterns

All views in this phase follow these patterns:

1. **MV Architecture**: No ViewModels. Views call use cases directly.
2. **SwiftData Queries**: Use `@Query` to observe local data.
3. **Environment DI**: Access use cases via `@Environment`.
4. **State Management**: Use `@State` for view-local state (loading, errors, navigation).
5. **Async Operations**: Use `.task` modifier or explicit `Task { }` blocks.

---

## Navigation Architecture

### Navigation Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          ContentView (TabView)                        │
├─────────────────────────────────────────────────────────────────────┤
│  Session │ Logbook │ Insights │ Feed │ Profile                       │
│    Tab   │   Tab   │    Tab   │  Tab │   Tab                         │
└─────────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
                               ┌────────────────────────┐
                               │    MyProfileView       │
                               │  (NavigationStack)     │
                               └───────────┬────────────┘
                                           │
                     ┌─────────────────────┼─────────────────────┐
                     │                     │                     │
                     ▼                     ▼                     ▼
              ┌────────────┐        ┌────────────┐        ┌────────────┐
              │ Followers  │        │ Following  │        │   Edit     │
              │  ListView  │        │  ListView  │        │  Profile   │
              │   (Push)   │        │   (Push)   │        │  (Sheet)   │
              └─────┬──────┘        └─────┬──────┘        └────────────┘
                    │                     │
                    ▼                     ▼
              ┌────────────────────────────────┐
              │       OtherProfileView         │
              │          (Push)                │
              └──────────────┬─────────────────┘
                             │
               ┌─────────────┼─────────────────┐
               ▼             ▼                 ▼
        ┌────────────┐ ┌────────────┐    (Recursive)
        │ Followers  │ │ Following  │
        │  ListView  │ │  ListView  │
        └────────────┘ └────────────┘

                    === SEARCH FLOW ===

              ┌────────────────────────────┐
              │    ProfileSearchView       │
              │  (Modal or Search Tab)     │
              └─────────────┬──────────────┘
                            │ Select Result
                            ▼
              ┌────────────────────────────┐
              │      OtherProfileView      │
              └────────────────────────────┘
```

### Navigation Implementation

Use SwiftUI's `NavigationStack` with `NavigationLink` for type-safe navigation:

```swift
// Navigation destinations enum
enum ProfileNavigation: Hashable {
    case followers(userId: UUID, userName: String)
    case following(userId: UUID, userName: String)
    case otherProfile(userId: UUID)
}
```

---

## View Specifications

### 5.1 MyProfileView

#### Purpose
Displays the current user's profile with full information, stats, and edit capability. Replaces the existing `ProfileView.swift`.

#### User Flow
1. User opens Profile tab
2. View loads profile from SwiftData via `@Query`
3. User sees header, stats, and profile info
4. User can tap stats to navigate to followers/following lists
5. User can tap Edit to open edit sheet
6. User can tap avatar to change photo

#### State Management

```swift
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
    @State private var selectedImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()

    // MARK: - Computed Properties
    private var currentProfile: SCProfile? {
        profiles.first
    }
}
```

#### SwiftUI Structure

```swift
import SwiftUI
import SwiftData
import PhotosUI

@MainActor
struct MyProfileView: View {
    // ... state as above ...

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
            matching: .images
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
```

#### Key Dependencies
- `@Query` for SCProfile
- `uploadProfilePhotoUseCase` for photo upload
- `authManager` for sign out
- `currentUserId` for upload context

---

### 5.2 EditProfileView

#### Purpose
Full-featured profile editing in a modal sheet. Extracted and enhanced from the existing inline EditProfileView.

#### User Flow
1. User taps Edit in MyProfileView toolbar
2. Sheet presents with form fields
3. User edits fields (validation happens on save)
4. User taps Save to commit changes
5. Changes save to SwiftData, sheet dismisses
6. Background sync to Supabase

#### State Management

```swift
@MainActor
struct EditProfileView: View {
    // MARK: - Bindable Profile
    @Bindable var profile: SCProfile

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.updateProfileUseCase) private var updateProfileUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - Form State (copy for editing)
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var homeGym: String = ""
    @State private var handle: String = ""
    @State private var climbingSince: Date = Date()
    @State private var hasClimbingSince: Bool = false
    @State private var favoriteStyle: String = ""
    @State private var isPublic: Bool = false
    @State private var preferredGradeScaleBoulder: GradeScale = .v
    @State private var preferredGradeScaleRoute: GradeScale = .yds

    // MARK: - UI State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingClimbingSincePicker = false

    // MARK: - Validation
    private var bioCharacterCount: Int { bio.count }
    private var bioIsValid: Bool { bioCharacterCount <= 280 }
    private var canSave: Bool { bioIsValid && !isSaving }
}
```

#### SwiftUI Structure

```swift
import SwiftUI
import SwiftData

@MainActor
struct EditProfileView: View {
    // ... state as above ...

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Identity Section
                Section("Identity") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)

                    TextField("Handle", text: $handle)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                // MARK: - Bio Section
                Section {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)

                    HStack {
                        Spacer()
                        Text("\(bioCharacterCount)/280")
                            .font(SCTypography.metadata)
                            .foregroundStyle(bioIsValid ? SCColors.textSecondary : .red)
                    }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("Tell others about yourself and your climbing journey")
                }

                // MARK: - Climbing Info Section
                Section("Climbing Info") {
                    TextField("Home Gym", text: $homeGym)

                    // Favorite style picker
                    Picker("Favorite Style", selection: $favoriteStyle) {
                        Text("Not Set").tag("")
                        Text("Bouldering").tag("Bouldering")
                        Text("Sport").tag("Sport")
                        Text("Trad").tag("Trad")
                        Text("Top Rope").tag("Top Rope")
                    }

                    // Climbing since toggle + picker
                    Toggle("Show Climbing Since", isOn: $hasClimbingSince)

                    if hasClimbingSince {
                        DatePicker(
                            "Started Climbing",
                            selection: $climbingSince,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                // MARK: - Preferences Section
                Section("Preferences") {
                    Picker("Boulder Grade Scale", selection: $preferredGradeScaleBoulder) {
                        Text("V-Scale").tag(GradeScale.v)
                        Text("French").tag(GradeScale.french)
                    }

                    Picker("Route Grade Scale", selection: $preferredGradeScaleRoute) {
                        Text("YDS").tag(GradeScale.yds)
                        Text("French").tag(GradeScale.french)
                        Text("UIAA").tag(GradeScale.uiaa)
                    }
                }

                // MARK: - Privacy Section
                Section {
                    Toggle("Public Profile", isOn: $isPublic)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(isPublic
                        ? "Your profile can be discovered and viewed by other climbers"
                        : "Your profile is hidden from search and other climbers"
                    )
                }

                // MARK: - Error Display
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(SCTypography.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadProfileData()
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: - Data Loading

    private func loadProfileData() {
        displayName = profile.displayName ?? ""
        bio = profile.bio ?? ""
        homeGym = profile.homeGym ?? ""
        handle = profile.handle
        favoriteStyle = profile.favoriteStyle ?? ""
        isPublic = profile.isPublic
        preferredGradeScaleBoulder = profile.preferredGradeScaleBoulder
        preferredGradeScaleRoute = profile.preferredGradeScaleRoute

        if let since = profile.climbingSince {
            climbingSince = since
            hasClimbingSince = true
        } else {
            hasClimbingSince = false
        }
    }

    // MARK: - Save Action

    private func saveProfile() async {
        guard let useCase = updateProfileUseCase else {
            errorMessage = "Profile service not available"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await useCase.execute(
                profileId: profile.id,
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                homeGym: homeGym.isEmpty ? nil : homeGym,
                climbingSince: hasClimbingSince ? climbingSince : nil,
                favoriteStyle: favoriteStyle.isEmpty ? nil : favoriteStyle,
                isPublic: isPublic,
                handle: handle != profile.handle ? handle : nil
            )

            // Also update local preferences that aren't in the use case
            profile.preferredGradeScaleBoulder = preferredGradeScaleBoulder
            profile.preferredGradeScaleRoute = preferredGradeScaleRoute
            profile.updatedAt = Date()
            profile.needsSync = true

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
```

#### Validation Rules
- **Bio**: Max 280 characters (show character counter)
- **Handle**: 3-30 chars, alphanumeric + underscores, starts with letter
- **Display Name**: Max 50 characters

---

### 5.3 OtherProfileView

#### Purpose
View another user's profile with follow/unfollow capability. Shows limited info for private profiles.

#### User Flow
1. User navigates from search results, follower list, or feed
2. View fetches profile from remote (not local SwiftData)
3. User sees header, stats, and bio
4. User can follow/unfollow
5. User can navigate to their followers/following lists

#### State Management

```swift
@MainActor
struct OtherProfileView: View {
    // MARK: - Input
    let userId: UUID

    // MARK: - Environment
    @Environment(\.currentUserId) private var currentUserId
    @Environment(\.toggleFollowUseCase) private var toggleFollowUseCase
    @Environment(\.getFollowersUseCase) private var getFollowersUseCase

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
}
```

#### SwiftUI Structure

```swift
import SwiftUI

@MainActor
struct OtherProfileView: View {
    let userId: UUID

    // ... state as above ...

    // Service for fetching remote profile
    @Environment(\.searchProfilesUseCase) private var searchProfilesUseCase

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

        // Fetch profile from ProfileService via remote lookup
        // Note: This requires a new method or using the profilesTable directly
        // For now, we'll use a placeholder approach
        do {
            // In Phase 6, wire this to ProfileService.fetchRemoteProfile
            // For now, create a stub that would be replaced
            profile = await fetchRemoteProfile(userId: userId)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchRemoteProfile(userId: UUID) async -> ProfileSearchResult? {
        // This will be wired in Phase 6 to ProfileService
        // Placeholder for now - returns nil
        // The Builder should add Environment injection for ProfileService
        return nil
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
```

#### Note on Remote Profile Fetching
The `OtherProfileView` needs to fetch profile data from Supabase since we may not have this user in local SwiftData. This requires:
1. Adding a method to `ProfileServiceProtocol` or using `fetchRemoteProfile`
2. Potentially adding a dedicated use case: `GetProfileUseCase`

**Builder Action**: Consider adding an Environment key for `ProfileServiceProtocol` or creating a `FetchProfileUseCase` in Phase 6.

---

### 5.4 ProfileSearchView

#### Purpose
Search and discover other climbers. Shows suggested profiles when empty, search results when typing.

#### User Flow
1. User opens search (from navigation bar icon or dedicated tab)
2. View shows suggested profiles (popular, recently active)
3. User types in search field
4. Results filter as user types (debounced)
5. User taps result to navigate to profile

#### State Management

```swift
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
}
```

#### SwiftUI Structure

```swift
import SwiftUI

@MainActor
struct ProfileSearchView: View {
    // ... state as above ...

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
```

#### Search Behavior
- Minimum 2 characters to search
- 300ms debounce to avoid excessive API calls
- Shows loading indicator during search
- Shows empty state for no results

---

### 5.5 FollowersListView

#### Purpose
Display paginated list of users following a given user.

#### User Flow
1. User taps "Followers" in profile stats
2. View loads first page of followers
3. User scrolls to load more (infinite scroll)
4. User taps row to navigate to that profile

#### State Management

```swift
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
}
```

#### SwiftUI Structure

```swift
import SwiftUI

@MainActor
struct FollowersListView: View {
    let userId: UUID
    let userName: String

    // ... state as above ...

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
```

---

### 5.6 FollowingListView

#### Purpose
Display paginated list of users that a given user follows. Nearly identical to FollowersListView but uses `GetFollowingUseCase`.

#### State Management

```swift
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
}
```

#### SwiftUI Structure

```swift
import SwiftUI

@MainActor
struct FollowingListView: View {
    let userId: UUID
    let userName: String

    // ... state as above ...

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
```

---

## Shared Patterns

### Navigation Destination Enum

Create a shared navigation type in a dedicated file:

```swift
// File: SwiftClimb/Features/Profile/ProfileNavigation.swift

import Foundation

/// Navigation destinations for profile-related views
enum ProfileNavigation: Hashable {
    case followers(userId: UUID, userName: String)
    case following(userId: UUID, userName: String)
    case otherProfile(userId: UUID)
}
```

### PhotosPicker Integration

For photo selection in MyProfileView:

```swift
import PhotosUI

// Add to state
@State private var selectedPhotoItem: PhotosPickerItem?

// In view body
.photosPicker(
    isPresented: $showingPhotoPicker,
    selection: $selectedPhotoItem,
    matching: .images,
    photoLibrary: .shared()
)
```

### Error Handling Pattern

Consistent error display across views:

```swift
@ViewBuilder
private func errorView(_ message: String) -> some View {
    Text(message)
        .font(SCTypography.secondary)
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
}
```

### Infinite Scroll Pattern

Used in FollowersListView and FollowingListView:

```swift
.onAppear {
    if item.id == items.last?.id {
        Task {
            await loadMore()
        }
    }
}
```

---

## Acceptance Criteria

### Task 5.1: MyProfileView (Refactor from ProfileView)
- [ ] Rename `ProfileView.swift` to `MyProfileView.swift`
- [ ] Update class/struct name from `ProfileView` to `MyProfileView`
- [ ] Uses `ProfileHeaderView` component for header display
- [ ] Uses `ProfileStatsView` component with navigation callbacks
- [ ] Avatar tap opens PhotosPicker
- [ ] Photo upload shows progress indicator
- [ ] Photo upload uses `uploadProfilePhotoUseCase`
- [ ] Stats tap navigates to FollowersListView/FollowingListView
- [ ] Edit button opens EditProfileView sheet
- [ ] Sign out button calls authManager
- [ ] Error messages display properly
- [ ] VoiceOver navigable
- [ ] Preview compiles

### Task 5.2: EditProfileView (Extract and Enhance)
- [ ] Separate file from MyProfileView
- [ ] Form with all editable fields
- [ ] Bio character counter (280 max)
- [ ] Climbing since date picker with toggle
- [ ] Favorite style picker
- [ ] Grade scale pickers (boulder/route)
- [ ] Public/private toggle with description
- [ ] Cancel dismisses without save
- [ ] Save validates then calls `updateProfileUseCase`
- [ ] Loading state during save
- [ ] Error display on validation/save failure
- [ ] Cannot dismiss during save operation
- [ ] Preview compiles

### Task 5.3: OtherProfileView
- [ ] Accepts userId as input
- [ ] Shows loading state while fetching
- [ ] Shows error state if fetch fails with retry button
- [ ] Public profiles show full header, stats, bio
- [ ] Private profiles show limited info with lock icon
- [ ] Follow button visible (not for own profile)
- [ ] Follow button uses `toggleFollowUseCase`
- [ ] Stats navigate to their followers/following lists
- [ ] Handles own profile gracefully (no follow button)
- [ ] Preview compiles

### Task 5.4: ProfileSearchView
- [ ] Search field in navigation bar
- [ ] Suggested profiles when search empty
- [ ] Results appear as user types
- [ ] Minimum 2 characters to search
- [ ] 300ms debounce on search
- [ ] Loading indicator during search
- [ ] Empty state when no results
- [ ] ProfileRowView for each result
- [ ] FollowButton in each row (not for own profile)
- [ ] Tap row navigates to OtherProfileView
- [ ] Preview compiles

### Task 5.5: FollowersListView
- [ ] Accepts userId and userName as inputs
- [ ] Shows loading state initially
- [ ] Shows error state with retry
- [ ] Shows empty state when no followers
- [ ] Paginated loading (20 per page)
- [ ] Infinite scroll loads more
- [ ] ProfileRowView for each follower
- [ ] FollowButton in each row
- [ ] Tap row navigates to OtherProfileView
- [ ] Preview compiles

### Task 5.6: FollowingListView
- [ ] Accepts userId and userName as inputs
- [ ] Shows loading state initially
- [ ] Shows error state with retry
- [ ] Shows empty state when not following anyone
- [ ] Paginated loading (20 per page)
- [ ] Infinite scroll loads more
- [ ] ProfileRowView for each followed user
- [ ] FollowButton in each row
- [ ] Tap row navigates to OtherProfileView
- [ ] Preview compiles

### General Acceptance Criteria
- [ ] All views use `@MainActor` isolation
- [ ] All views follow MV pattern (no ViewModels)
- [ ] All async operations use `Task { }` or `.task` modifier
- [ ] All views use design system tokens (SCSpacing, SCTypography, SCColors)
- [ ] Navigation uses type-safe `ProfileNavigation` enum
- [ ] Build succeeds with no errors
- [ ] No compiler warnings related to concurrency

---

## Builder Handoff Notes

### Implementation Order

Build views in this sequence due to dependencies:

1. **ProfileNavigation.swift** (shared enum - no dependencies)
2. **MyProfileView.swift** (rename + refactor ProfileView)
3. **EditProfileView.swift** (extracted, referenced by MyProfileView)
4. **FollowersListView.swift** (navigation target)
5. **FollowingListView.swift** (navigation target)
6. **OtherProfileView.swift** (navigation target, uses ProfileNavigation)
7. **ProfileSearchView.swift** (can be built in parallel with 4-6)

### File Operations

```bash
# 1. Rename ProfileView to MyProfileView
mv SwiftClimb/Features/Profile/ProfileView.swift SwiftClimb/Features/Profile/MyProfileView.swift

# 2. Create new files
touch SwiftClimb/Features/Profile/ProfileNavigation.swift
touch SwiftClimb/Features/Profile/EditProfileView.swift
touch SwiftClimb/Features/Profile/OtherProfileView.swift
touch SwiftClimb/Features/Profile/ProfileSearchView.swift
touch SwiftClimb/Features/Profile/FollowersListView.swift
touch SwiftClimb/Features/Profile/FollowingListView.swift
```

### Required Imports

All views need these imports:
```swift
import SwiftUI
import SwiftData  // Only if using @Query
import PhotosUI   // Only MyProfileView
```

### ContentView Update (Phase 6)

In Phase 6, update ContentView.swift to use `MyProfileView`:
```swift
// Change from:
ProfileView()
// To:
MyProfileView()
```

### Known Gaps to Address in Phase 6

1. **OtherProfileView remote fetch**: The `fetchRemoteProfile` method needs wiring to `ProfileService.fetchRemoteProfile` or a new use case.

2. **ProfileSearchView suggested profiles**: The "suggested" feature currently just searches for "climber". A proper implementation would need a backend endpoint for popular/recommended profiles.

3. **Navigation from Feed**: Feed posts should be able to navigate to `OtherProfileView`. This will be wired in Phase 6.

4. **Search tab vs icon**: Decision needed on whether ProfileSearchView is:
   - A new tab in ContentView, OR
   - Accessible via navigation bar search icon in Profile tab

### Testing Checklist Before Handoff

After implementing each view:
- [ ] Build succeeds (Cmd+B)
- [ ] Preview renders
- [ ] No concurrency warnings
- [ ] VoiceOver announces elements correctly
- [ ] Touch targets are at least 44pt

### Coordinator Note

Update `SOCIAL_PROFILE_FEATURE.md` after completing each task:
1. Mark task as complete in the checkbox
2. Add timestamp to Completed Tasks Log
3. Update Progress Summary table

---

## References

### Existing Files to Reference
- `/SwiftClimb/Features/Profile/ProfileView.swift` - Current implementation to refactor
- `/SwiftClimb/Features/Session/SessionView.swift` - MV pattern reference
- `/SwiftClimb/Features/Profile/Components/` - Phase 4 components
- `/SwiftClimb/Domain/UseCases/` - Phase 3 use cases
- `/SwiftClimb/App/Environment+UseCases.swift` - Environment keys

### Phase 4 Components Used
- `ProfileHeaderView` - Header display
- `ProfileStatsView` - Stats with callbacks
- `ProfileAvatarView` - Avatar with sizes
- `ProfileRowView` - List rows
- `FollowButton` - Follow toggle

### Phase 3 Use Cases Used
- `UpdateProfileUseCaseProtocol` - Profile editing
- `SearchProfilesUseCaseProtocol` - Profile search
- `UploadProfilePhotoUseCaseProtocol` - Photo upload
- `GetFollowersUseCaseProtocol` - Followers list
- `GetFollowingUseCaseProtocol` - Following list
- `ToggleFollowUseCaseProtocol` - Follow/unfollow

---

**End of Phase 5 Views Specification**
