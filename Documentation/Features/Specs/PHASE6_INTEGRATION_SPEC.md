# Phase 6: Integration Specification

> **Feature**: Social Profile Feature - Integration
> **Phase**: 6 of 7
> **Status**: Ready for Implementation
> **Created**: 2026-01-19
> **Author**: Agent 1 (Architect)

---

## Table of Contents
1. [Overview](#overview)
2. [Dependency Graph](#dependency-graph)
3. [Task Specifications](#task-specifications)
   - [6.1 Environment Keys](#61-environment-keys)
   - [6.2 SwiftClimbApp Wiring](#62-swiftclimbapp-wiring)
   - [6.3 Navigation Paths](#63-navigation-paths)
   - [6.4 Sync Operations](#64-sync-operations)
   - [6.5 Profile Search Tab](#65-profile-search-tab)
4. [Gap Analysis](#gap-analysis)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose

Phase 6 wires all Phase 2-5 components together into a working feature:
- Inject use cases into the SwiftUI Environment
- Create service instances with proper dependencies
- Enable navigation between profile views
- Add sync operation types for profile changes
- Integrate ProfileSearchView into the app navigation

### Current State

The following components exist but are NOT wired together:
- **Services**: `ProfileServiceImpl`, `StorageServiceImpl`, `SocialServiceImpl`
- **Use Cases**: `UpdateProfileUseCase`, `SearchProfilesUseCase`, `UploadProfilePhotoUseCase`, `GetFollowersUseCase`, `GetFollowingUseCase`
- **Environment Keys**: Keys exist but `defaultValue` is `nil` for new use cases
- **Views**: `MyProfileView`, `OtherProfileView`, `ProfileSearchView`, `FollowersListView`, `FollowingListView`, `EditProfileView`

### Files to Modify

| File Path | Task | Changes |
|-----------|------|---------|
| `/SwiftClimb/App/Environment+UseCases.swift` | 6.1 | Add `FetchProfileUseCaseProtocol` and key |
| `/SwiftClimb/App/SwiftClimbApp.swift` | 6.2 | Wire services and use cases |
| `/SwiftClimb/App/ContentView.swift` | 6.3, 6.5 | Add search tab or navigation |
| `/SwiftClimb/Core/Sync/SyncOperation.swift` | 6.4 | Add profile sync operations |
| `/SwiftClimb/Features/Profile/OtherProfileView.swift` | 6.3 | Wire `FetchProfileUseCase` |

### Files to Create

| File Path | Task | Purpose |
|-----------|------|---------|
| `/SwiftClimb/Domain/UseCases/FetchProfileUseCase.swift` | 6.1 | Fetch remote profile for OtherProfileView |

---

## Dependency Graph

### Service Initialization Order

Services must be created in the correct order due to dependencies:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SupabaseClientActor                              │
│                        (config: .shared)                                 │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        SupabaseRepository                                │
│                   (client: supabaseClient)                               │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
             ┌──────────┐   ┌──────────┐   ┌──────────┐
             │ Profiles │   │ Follows  │   │ HTTP     │
             │ Table    │   │ Table    │   │ Client   │
             └────┬─────┘   └────┬─────┘   └────┬─────┘
                  │              │              │
          ┌───────┴──────────────┴───────┐     │
          │                              │     │
          ▼                              ▼     ▼
    ┌──────────────┐              ┌──────────────────┐
    │ ProfileService│              │ StorageService   │
    │ (modelContainer,            │ (config, http,   │
    │  profilesTable)             │  supabaseClient) │
    └──────┬───────┘              └────────┬─────────┘
           │                               │
           ├───────────────────────────────┤
           │                               │
           ▼                               ▼
    ┌──────────────────────────────────────────────┐
    │             Use Cases                         │
    │  - UpdateProfileUseCase(profileService)       │
    │  - SearchProfilesUseCase(profileService)      │
    │  - FetchProfileUseCase(profileService)  NEW   │
    │  - UploadProfilePhotoUseCase(storage, profile)│
    │  - GetFollowersUseCase(socialService)         │
    │  - GetFollowingUseCase(socialService)         │
    └──────────────────────────────────────────────┘
```

### Use Case Dependencies

| Use Case | Required Services |
|----------|-------------------|
| `UpdateProfileUseCase` | `ProfileServiceProtocol` |
| `SearchProfilesUseCase` | `ProfileServiceProtocol` |
| `FetchProfileUseCase` (NEW) | `ProfileServiceProtocol` |
| `UploadProfilePhotoUseCase` | `StorageServiceProtocol`, `ProfileServiceProtocol` |
| `GetFollowersUseCase` | `SocialServiceProtocol` |
| `GetFollowingUseCase` | `SocialServiceProtocol` |
| `ToggleFollowUseCase` | `SocialServiceProtocol` (already wired) |

---

## Task Specifications

### 6.1 Environment Keys

#### 6.1.1 Create FetchProfileUseCase

`OtherProfileView` needs to fetch remote profile data. This requires a new use case.

**File to Create**: `/SwiftClimb/Domain/UseCases/FetchProfileUseCase.swift`

```swift
import Foundation

/// Errors that can occur when fetching a profile
enum FetchProfileError: Error, LocalizedError, Sendable {
    case profileNotFound
    case networkError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .networkError(let message):
            return "Failed to load profile: \(message)"
        case .unauthorized:
            return "You must be logged in to view profiles"
        }
    }
}

/// Fetches a remote profile by ID
///
/// Used by OtherProfileView to load profile data from Supabase
/// when viewing another user's profile.
protocol FetchProfileUseCaseProtocol: Sendable {
    /// Fetches a profile from the remote server
    /// - Parameter profileId: The profile's UUID
    /// - Returns: The profile data as a search result
    /// - Throws: FetchProfileError if the fetch fails
    func execute(profileId: UUID) async throws -> ProfileSearchResult
}

/// Fetches a remote profile by ID
///
/// `FetchProfileUseCase` retrieves profile data from Supabase for viewing
/// other users' profiles. This is a remote-only operation since the profile
/// may not exist in local SwiftData.
///
/// ## Usage
///
/// ```swift
/// let useCase = FetchProfileUseCase(profileService: profileService)
/// let profile = try await useCase.execute(profileId: userId)
/// ```
final class FetchProfileUseCase: FetchProfileUseCaseProtocol, @unchecked Sendable {
    private let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol) {
        self.profileService = profileService
    }

    func execute(profileId: UUID) async throws -> ProfileSearchResult {
        do {
            guard let dto = try await profileService.fetchRemoteProfile(profileId: profileId) else {
                throw FetchProfileError.profileNotFound
            }

            return ProfileSearchResult(
                id: dto.id,
                handle: dto.handle,
                displayName: dto.displayName,
                photoURL: dto.photoURL,
                bio: dto.bio,
                isPublic: dto.isPublic,
                followerCount: dto.followerCount,
                followingCount: dto.followingCount,
                sendCount: dto.sendCount
            )
        } catch let error as ProfileError {
            switch error {
            case .profileNotFound:
                throw FetchProfileError.profileNotFound
            case .unauthorized:
                throw FetchProfileError.unauthorized
            case .networkError(let underlyingError):
                throw FetchProfileError.networkError(underlyingError.localizedDescription)
            default:
                throw FetchProfileError.networkError(error.localizedDescription)
            }
        }
    }
}
```

#### 6.1.2 Add Environment Key for FetchProfileUseCase

**File to Modify**: `/SwiftClimb/App/Environment+UseCases.swift`

Add the following after the existing use case keys (around line 201):

```swift
// MARK: - Fetch Profile Use Case

private struct FetchProfileUseCaseKey: EnvironmentKey {
    static let defaultValue: FetchProfileUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var fetchProfileUseCase: FetchProfileUseCaseProtocol? {
        get { self[FetchProfileUseCaseKey.self] }
        set { self[FetchProfileUseCaseKey.self] = newValue }
    }
}
```

---

### 6.2 SwiftClimbApp Wiring

**File to Modify**: `/SwiftClimb/App/SwiftClimbApp.swift`

#### 6.2.1 Add Property Declarations

Add these properties to `SwiftClimbApp` (after existing use case declarations, around line 27):

```swift
// Profile-related use cases (Phase 6)
let updateProfileUseCase: UpdateProfileUseCaseProtocol
let searchProfilesUseCase: SearchProfilesUseCaseProtocol
let fetchProfileUseCase: FetchProfileUseCaseProtocol
let uploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol
let getFollowersUseCase: GetFollowersUseCaseProtocol
let getFollowingUseCase: GetFollowingUseCaseProtocol
```

#### 6.2.2 Initialize Services and Use Cases in init()

Update the `init()` method to create the services and use cases. Insert after existing service initialization (around line 57):

```swift
// Initialize Profile services (Phase 6)
let storageService = StorageServiceImpl(
    config: .shared,
    httpClient: HTTPClient(),
    supabaseClient: supabaseClient
)

let profileService = ProfileServiceImpl(
    modelContainer: modelContainer,
    profilesTable: profilesTable
)

// Initialize Profile use cases (Phase 6)
updateProfileUseCase = UpdateProfileUseCase(profileService: profileService)
searchProfilesUseCase = SearchProfilesUseCase(profileService: profileService)
fetchProfileUseCase = FetchProfileUseCase(profileService: profileService)
uploadProfilePhotoUseCase = UploadProfilePhotoUseCase(
    storageService: storageService,
    profileService: profileService
)
getFollowersUseCase = GetFollowersUseCase(socialService: socialService)
getFollowingUseCase = GetFollowingUseCase(socialService: socialService)
```

#### 6.2.3 Inject Use Cases into Environment

Update the `body` property to inject the new use cases. Add after existing `.environment()` calls (around line 89):

```swift
// Profile use cases (Phase 6)
.environment(\.updateProfileUseCase, updateProfileUseCase)
.environment(\.searchProfilesUseCase, searchProfilesUseCase)
.environment(\.fetchProfileUseCase, fetchProfileUseCase)
.environment(\.uploadProfilePhotoUseCase, uploadProfilePhotoUseCase)
.environment(\.getFollowersUseCase, getFollowersUseCase)
.environment(\.getFollowingUseCase, getFollowingUseCase)
```

#### Complete SwiftClimbApp Changes

For clarity, here is the complete set of changes to `SwiftClimbApp.swift`:

**Add to property declarations (after line 27):**
```swift
// Profile-related use cases (Phase 6)
let updateProfileUseCase: UpdateProfileUseCaseProtocol
let searchProfilesUseCase: SearchProfilesUseCaseProtocol
let fetchProfileUseCase: FetchProfileUseCaseProtocol
let uploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol
let getFollowersUseCase: GetFollowersUseCaseProtocol
let getFollowingUseCase: GetFollowingUseCaseProtocol
```

**Add to init() (after line 57, after socialService creation):**
```swift
// Initialize Profile services (Phase 6)
let storageService = StorageServiceImpl(
    config: .shared,
    httpClient: HTTPClient(),
    supabaseClient: supabaseClient
)

let profileService = ProfileServiceImpl(
    modelContainer: modelContainer,
    profilesTable: profilesTable
)

// Initialize Profile use cases (Phase 6)
updateProfileUseCase = UpdateProfileUseCase(profileService: profileService)
searchProfilesUseCase = SearchProfilesUseCase(profileService: profileService)
fetchProfileUseCase = FetchProfileUseCase(profileService: profileService)
uploadProfilePhotoUseCase = UploadProfilePhotoUseCase(
    storageService: storageService,
    profileService: profileService
)
getFollowersUseCase = GetFollowersUseCase(socialService: socialService)
getFollowingUseCase = GetFollowingUseCase(socialService: socialService)
```

**Add to body (after line 89):**
```swift
.environment(\.updateProfileUseCase, updateProfileUseCase)
.environment(\.searchProfilesUseCase, searchProfilesUseCase)
.environment(\.fetchProfileUseCase, fetchProfileUseCase)
.environment(\.uploadProfilePhotoUseCase, uploadProfilePhotoUseCase)
.environment(\.getFollowersUseCase, getFollowersUseCase)
.environment(\.getFollowingUseCase, getFollowingUseCase)
```

---

### 6.3 Navigation Paths

#### 6.3.1 Update OtherProfileView to Use FetchProfileUseCase

**File to Modify**: `/SwiftClimb/Features/Profile/OtherProfileView.swift`

Replace the stub `loadProfile()` method with actual implementation:

**Add to imports (at top):**
```swift
// No additional imports needed
```

**Add to Environment section (around line 10):**
```swift
@Environment(\.fetchProfileUseCase) private var fetchProfileUseCase
```

**Replace the `loadProfile()` method (around line 213):**
```swift
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
```

#### 6.3.2 Navigation is Already Implemented

The `ProfileNavigation` enum and `.navigationDestination` modifiers are already in place from Phase 5. No additional navigation changes are required.

---

### 6.4 Sync Operations

**File to Modify**: `/SwiftClimb/Core/Sync/SyncOperation.swift`

Add profile and follow sync operations to the `OperationType` enum.

#### Add New Operation Types

**Add to `OperationType` enum (around line 53, before the closing brace):**

```swift
// Profile sync operations (Phase 6)
case insertProfile(profileId: UUID)
case updateProfile(profileId: UUID)
case deleteProfile(profileId: UUID)

// Follow sync operations (Phase 6)
case insertFollow(followId: UUID)
case deleteFollow(followId: UUID)
```

#### Update entityType Computed Property

**Update the `entityType` computed property (starting around line 92):**

```swift
extension SyncOperation.OperationType {
    var entityType: String {
        switch self {
        case .insertSession, .updateSession, .deleteSession:
            return "session"
        case .insertClimb, .updateClimb, .deleteClimb:
            return "climb"
        case .insertAttempt, .updateAttempt, .deleteAttempt:
            return "attempt"
        case .insertProfile, .updateProfile, .deleteProfile:
            return "profile"
        case .insertFollow, .deleteFollow:
            return "follow"
        }
    }

    var isDelete: Bool {
        switch self {
        case .deleteSession, .deleteClimb, .deleteAttempt, .deleteProfile, .deleteFollow:
            return true
        default:
            return false
        }
    }
}
```

---

### 6.5 Profile Search Tab

There are two options for integrating `ProfileSearchView`:

#### Option A: Add Search Tab to ContentView (Recommended)

Add a dedicated "Search" tab for discovering climbers.

**File to Modify**: `/SwiftClimb/App/ContentView.swift`

**Update the `Tab` enum:**
```swift
enum Tab {
    case session
    case logbook
    case insights
    case feed
    case search  // NEW
    case profile
}
```

**Add the search tab to the TabView (before profile tab):**
```swift
ProfileSearchView()
    .tabItem {
        Label("Search", systemImage: "magnifyingglass")
    }
    .tag(Tab.search)
```

**Complete ContentView.swift:**
```swift
import SwiftUI

@MainActor
struct ContentView: View {
    @State private var selectedTab: Tab = .session

    enum Tab {
        case session
        case logbook
        case insights
        case feed
        case search
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionView()
                .tabItem {
                    Label("Session", systemImage: "figure.climbing")
                }
                .tag(Tab.session)

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
                .tag(Tab.logbook)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.insights)

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.feed)

            ProfileSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            MyProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

#Preview {
    ContentView()
}
```

#### Option B: Add Search Icon to Profile Tab (Alternative)

If 6 tabs feels like too many, add a search icon to the profile navigation bar instead.

**File to Modify**: `/SwiftClimb/Features/Profile/MyProfileView.swift`

Add toolbar button that presents `ProfileSearchView` as a sheet or navigation destination.

**This option is NOT recommended** for MVP because:
- Search is a primary discovery feature
- Users expect search to be prominent
- The profile tab is already complex

**Recommendation**: Use Option A (dedicated search tab).

---

## Gap Analysis

### Gaps Identified and Addressed

| Gap | Resolution |
|-----|------------|
| `OtherProfileView` has stub `loadProfile()` | Create `FetchProfileUseCase` + wire in Task 6.3 |
| Profile use cases not injected | Wire in `SwiftClimbApp` in Task 6.2 |
| No sync operations for profile | Add to `SyncOperation` in Task 6.4 |
| `ProfileSearchView` not accessible | Add search tab in Task 6.5 |

### Gaps NOT Addressed (Out of Scope for Phase 6)

| Gap | Reason | Future Phase |
|-----|--------|--------------|
| Suggested profiles uses placeholder search | Requires backend endpoint | Phase 7+ |
| Feed posts don't link to profiles | Feed feature not implemented | Future feature |
| Offline follow queue | Current implementation fires and forgets | Phase 7+ |
| Profile photo deletion when changing | Need to track old photos | Phase 7+ |

---

## Acceptance Criteria

### Task 6.1: Environment Keys
- [ ] `FetchProfileUseCase.swift` exists at `/SwiftClimb/Domain/UseCases/FetchProfileUseCase.swift`
- [ ] `FetchProfileUseCaseProtocol` is defined and Sendable
- [ ] `FetchProfileUseCase` implements the protocol
- [ ] Environment key `fetchProfileUseCase` is added to `Environment+UseCases.swift`
- [ ] Build succeeds with no errors

### Task 6.2: SwiftClimbApp Wiring
- [ ] `SwiftClimbApp` declares all 6 new use case properties
- [ ] `SwiftClimbApp.init()` creates `StorageServiceImpl` with correct dependencies
- [ ] `SwiftClimbApp.init()` creates `ProfileServiceImpl` with correct dependencies
- [ ] `SwiftClimbApp.init()` creates all 6 use cases with correct services
- [ ] All 6 use cases are injected via `.environment()` in body
- [ ] Build succeeds with no errors
- [ ] App launches without crashes

### Task 6.3: Navigation Paths
- [ ] `OtherProfileView` has `@Environment(\.fetchProfileUseCase)` property
- [ ] `OtherProfileView.loadProfile()` calls the use case (not stub)
- [ ] Navigating to `OtherProfileView` loads and displays remote profile
- [ ] Error states display correctly when profile not found
- [ ] Build succeeds with no errors

### Task 6.4: Sync Operations
- [ ] `SyncOperation.OperationType` includes `insertProfile`, `updateProfile`, `deleteProfile`
- [ ] `SyncOperation.OperationType` includes `insertFollow`, `deleteFollow`
- [ ] `entityType` returns "profile" for profile operations
- [ ] `entityType` returns "follow" for follow operations
- [ ] `isDelete` returns true for `deleteProfile` and `deleteFollow`
- [ ] Build succeeds with no errors

### Task 6.5: Profile Search Tab
- [ ] `ContentView.Tab` enum includes `search` case
- [ ] `ProfileSearchView` is displayed in a tab with magnifying glass icon
- [ ] Tab order is: Session, Logbook, Insights, Feed, Search, Profile
- [ ] Tapping search tab navigates to `ProfileSearchView`
- [ ] Build succeeds with no errors

### Integration Acceptance
- [ ] Can edit own profile from MyProfileView (uses UpdateProfileUseCase)
- [ ] Can upload profile photo from MyProfileView (uses UploadProfilePhotoUseCase)
- [ ] Can search for profiles from Search tab (uses SearchProfilesUseCase)
- [ ] Can tap search result to view profile (uses FetchProfileUseCase)
- [ ] Can follow/unfollow from OtherProfileView (uses ToggleFollowUseCase)
- [ ] Can view followers list (uses GetFollowersUseCase)
- [ ] Can view following list (uses GetFollowingUseCase)
- [ ] All navigation works correctly between profile views

---

## Builder Handoff Notes

### Implementation Order

Build in this sequence due to dependencies:

1. **Task 6.1**: Create `FetchProfileUseCase` + add environment key
2. **Task 6.4**: Add sync operations (independent, can be parallel with 6.1)
3. **Task 6.2**: Wire everything in `SwiftClimbApp`
4. **Task 6.3**: Update `OtherProfileView` to use the use case
5. **Task 6.5**: Add search tab to `ContentView`

### File Checklist

Create:
- [ ] `/SwiftClimb/Domain/UseCases/FetchProfileUseCase.swift`

Modify:
- [ ] `/SwiftClimb/App/Environment+UseCases.swift`
- [ ] `/SwiftClimb/App/SwiftClimbApp.swift`
- [ ] `/SwiftClimb/Features/Profile/OtherProfileView.swift`
- [ ] `/SwiftClimb/Core/Sync/SyncOperation.swift`
- [ ] `/SwiftClimb/App/ContentView.swift`

### Testing Checklist

After implementation, verify these flows work:

1. **Edit Profile Flow**
   - Open Profile tab
   - Tap Edit
   - Change bio and save
   - Verify changes persist

2. **Photo Upload Flow**
   - Open Profile tab
   - Tap avatar
   - Select photo
   - Verify upload completes and photo appears

3. **Search Flow**
   - Open Search tab
   - Type 2+ characters
   - Verify results appear
   - Tap result
   - Verify OtherProfileView loads correctly

4. **Follow Flow**
   - From search result, tap profile
   - Tap Follow button
   - Verify button changes to Following
   - Tap Followers count
   - Verify list loads

5. **Navigation Flow**
   - Navigate: Search > Profile > Followers > Profile
   - Verify back navigation works correctly

### Common Pitfalls

1. **Forgetting to inject a use case** - App will crash when view tries to use it
2. **Wrong service passed to use case** - Type system will catch this
3. **Circular dependencies** - Follow the dependency graph strictly
4. **Missing @MainActor** - Views need MainActor isolation
5. **Optional unwrap failures** - Environment keys default to nil, guard properly

### Coordinator Note

After completing Phase 6, update `SOCIAL_PROFILE_FEATURE.md`:
1. Mark all Phase 6 tasks as complete
2. Update Progress Summary table (should be 37/42)
3. Add timestamp to Completed Tasks Log
4. Set Current Focus to Phase 7: Testing & Polish

---

## References

### Existing Files to Reference
- `/SwiftClimb/App/SwiftClimbApp.swift` - Current DI setup pattern
- `/SwiftClimb/Domain/UseCases/ToggleFollowUseCase.swift` - Already wired use case pattern
- `/SwiftClimb/Domain/Services/ProfileService.swift` - ProfileServiceImpl implementation
- `/SwiftClimb/Core/Sync/SyncOperation.swift` - Current sync operations

### Phase Dependencies
- Phase 2: Services must exist (complete)
- Phase 3: Use cases must exist (complete)
- Phase 5: Views must exist (complete)

---

**End of Phase 6 Integration Specification**
