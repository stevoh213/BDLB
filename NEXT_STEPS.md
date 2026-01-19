# SwiftClimb - Next Steps

## Immediate Actions Required

### 1. Create Xcode Project
To convert this scaffold into a buildable Xcode project:

```bash
cd /Users/skelley/Projects/SwiftClimb
# Option A: Create new Xcode project via Xcode GUI
# File > New > Project > iOS > App
# - Product Name: SwiftClimb
# - Interface: SwiftUI
# - Storage: SwiftData
# - Language: Swift

# Option B: Use command line (if xcodeproj is available)
# Then add all existing Swift files to the project
```

### 2. Configure Build Settings
In Xcode project settings:
- **iOS Deployment Target**: 18.0 (Note: Spec mentions iOS 26+, likely a typo)
- **Swift Language Version**: Swift 6
- **Strict Concurrency Checking**: Complete (treat warnings as errors)
- **Bundle Identifier**: `com.yourteam.swiftclimb` (update)

### 3. Add Package Dependencies
Add via File > Add Package Dependencies:
- **supabase-swift**: https://github.com/supabase/supabase-swift
  - Version: Latest stable release

Optional (recommended):
- **swift-dependencies**: https://github.com/pointfreeco/swift-dependencies

### 4. Create Configuration Files

#### Config.swift (for environment variables)
```swift
enum Config {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
    static let openBetaEndpoint = "https://api.openbeta.io/graphql"
}
```

#### Info.plist additions
- Bundle Display Name
- Required Device Capabilities
- Privacy - Location When In Use Usage Description (for outdoor climbs)

### 5. Create Assets
- App Icon (1024x1024px)
- Accent Color in Assets.xcassets
- Preview Content folder

---

## Priority Implementation Order

### Phase 1: Local-Only MVP (No Backend)
**Goal**: Get app running with local SwiftData storage only

1. **Implement Core Services** (No network calls)
   - SessionService - CRUD operations on SwiftData
   - ClimbService - CRUD operations on SwiftData
   - AttemptService - CRUD operations on SwiftData
   - AuthService - Stub that returns mock profile

2. **Implement Use Cases** (Call local services)
   - StartSessionUseCase
   - AddClimbUseCase
   - LogAttemptUseCase
   - EndSessionUseCase

3. **Update Views to Use MV Pattern**
   - Update SessionView - Use @Query and Environment injection
   - Add climb UI to SessionView
   - Create AddClimbSheet
   - Create AttemptLoggerView

4. **Test Locally**
   - Start session
   - Add climbs
   - Log attempts
   - End session
   - View in logbook

### Phase 2: Supabase Integration
**Goal**: Sync to cloud storage

1. **Implement SupabaseClientActor**
   - Real auth flow with supabase-swift SDK
   - Token management
   - Request execution

2. **Implement Table Operations**
   - ProfilesTable
   - SessionsTable
   - ClimbsTable
   - AttemptsTable

3. **Implement SyncActor**
   - Pull updates
   - Push pending changes
   - Conflict resolution

4. **Test Sync**
   - Verify offline writes
   - Verify sync on connection
   - Test conflict scenarios

### Phase 3: OpenBeta Integration
**Goal**: Outdoor climb lookup

1. **Implement OpenBetaClientActor**
   - Real GraphQL execution
   - Rate limiting
   - Error handling

2. **Implement SearchOpenBetaUseCase**
   - Area search
   - Climb search
   - Result mapping to domain models

3. **Update AddClimbSheet**
   - Add outdoor climb search
   - Link to OpenBeta climbs
   - Display climb details

### Phase 4: Social Features
**Goal**: Following and feed

1. **Implement Social Services**
   - Follow/unfollow
   - Create posts
   - Add kudos/comments

2. **Implement Feed UI**
   - Post cards
   - Kudos interaction
   - Comments

3. **Implement Profile UI**
   - Public/private toggle
   - View followers/following
   - Edit profile

### Phase 5: Insights (Premium)
**Goal**: Analytics and visualizations

1. **Implement Insights Calculations**
   - Volume by week/month
   - Attempt pyramid
   - Send pyramid
   - Grade progression

2. **Implement Insights UI**
   - Charts using Swift Charts
   - Date range selection
   - Export functionality

3. **Add Subscription Paywall**
   - StoreKit 2 integration
   - Premium feature gating
   - Restore purchases

---

## File-by-File Implementation Guide

### Critical Path Files (Implement First)

#### 1. Domain/Services/SessionService.swift
```swift
// Replace stub with:
import SwiftData

final class SessionService: SessionServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSession(...) async throws -> SCSession {
        let session = SCSession(userId: userId, ...)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    // Implement remaining methods using SwiftData queries
}
```

#### 2. Features/Session/SessionView.swift
```swift
// Update to use MV pattern:
struct SessionView: View {
    @Query(
        filter: #Predicate<SCSession> {
            $0.endedAt == nil && $0.deletedAt == nil
        }
    )
    private var activeSessions: [SCSession]

    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        if let session = activeSessions.first {
            // Active session UI
        } else {
            // Start session button
        }
    }

    private func handleStartSession() async {
        // Call useCase directly
    }
}
```

#### 3. App/SwiftClimbApp.swift
```swift
// Add dependency injection via Environment:
extension EnvironmentValues {
    @Entry var startSessionUseCase: StartSessionUseCaseProtocol =
        DefaultStartSessionUseCase()
    @Entry var endSessionUseCase: EndSessionUseCaseProtocol =
        DefaultEndSessionUseCase()
}

@main
struct SwiftClimbApp: App {
    let modelContainer: ModelContainer
    let sessionService: SessionServiceProtocol
    let startSessionUseCase: StartSessionUseCaseProtocol
    let endSessionUseCase: EndSessionUseCaseProtocol

    init() {
        modelContainer = try! SwiftDataContainer.shared.container
        let context = modelContainer.mainContext

        sessionService = SessionService(modelContext: context)
        startSessionUseCase = StartSessionUseCase(
            sessionService: sessionService
        )
        endSessionUseCase = EndSessionUseCase(
            sessionService: sessionService
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.startSessionUseCase, startSessionUseCase)
                .environment(\.endSessionUseCase, endSessionUseCase)
        }
        .modelContainer(modelContainer)
    }
}
```

---

## Testing Checklist

### Unit Tests Needed
- [ ] Grade parsing (GradeConversionService)
- [ ] Conflict resolution (ConflictResolver)
- [ ] Sync operation queueing (SyncActor)
- [ ] DTO <-> Model conversion

### Integration Tests Needed
- [ ] SwiftData CRUD operations
- [ ] Session -> Climb -> Attempt cascade
- [ ] Supabase auth flow
- [ ] OpenBeta query execution
- [ ] Sync pull/push cycle

### UI Tests Needed
- [ ] Start/end session flow
- [ ] Add climb flow
- [ ] Log attempt flow
- [ ] Navigation between tabs
- [ ] VoiceOver support

---

## Common Development Commands

```bash
# Check for Swift syntax errors
find SwiftClimb -name "*.swift" -exec swift -parse {} \;

# Count lines of code
find SwiftClimb -name "*.swift" -exec wc -l {} + | tail -1

# Find TODOs
grep -r "TODO:" SwiftClimb

# Find FatalErrors (should be replaced)
grep -r "fatalError" SwiftClimb
```

---

## Resources

### Documentation
- SwiftData: https://developer.apple.com/documentation/swiftdata
- Swift 6 Concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- Supabase Swift: https://github.com/supabase/supabase-swift
- OpenBeta API: https://openbeta.io/developers

### Design References
- iOS 18 Design Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Liquid Glass Materials: Use `.regularMaterial`, `.thickMaterial`
- SF Symbols: https://developer.apple.com/sf-symbols/

---

## Questions to Answer Before Full Implementation

1. **Authentication Flow**
   - Email verification required?
   - Password reset flow?
   - Social login (Apple ID, Google)?

2. **Data Retention**
   - How long to keep deleted records (soft deletes)?
   - Data export functionality needed?
   - GDPR compliance requirements?

3. **Subscription Model**
   - Pricing tiers?
   - Free tier limitations (30 day history)?
   - Trial period?

4. **Offline Behavior**
   - Maximum offline duration?
   - Storage limits for unsync'd data?
   - Conflict resolution UX when sync fails?

5. **Performance Targets**
   - Attempt logging must be < 100ms (confirmed)
   - Max session load time?
   - Feed scroll performance requirements?

---

This scaffold provides a solid foundation. Focus on Phase 1 (Local-Only MVP) first to validate the architecture and user experience before adding network complexity.
