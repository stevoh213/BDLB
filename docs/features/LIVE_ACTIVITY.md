# Live Activity Feature

## Overview

SwiftClimb's Live Activity feature provides real-time session information on the Lock Screen and Dynamic Island for users with iPhone 14 Pro and later. The implementation follows Apple's ActivityKit framework and SwiftClimb's offline-first architecture, ensuring that activity updates happen instantly even without network connectivity.

## Key Features

- **Lock Screen Display**: Full-featured view showing session stats, timer, and quick actions
- **Dynamic Island**: Compact and expanded views with climbing session information
- **Deep Linking**: Tap "Add Climb" button to jump directly to the Add Climb sheet
- **Real-Time Updates**: Instant activity updates as climbs and attempts are logged
- **Actor-Based Management**: Thread-safe lifecycle management using Swift Concurrency
- **App Group State Sharing**: Communication bridge between main app and widget extension

## Architecture

### Component Overview

```
Main App (SwiftClimb)
├── LiveActivityManager (Actor)          # Lifecycle management
├── ClimbingSessionAttributes (Struct)   # ActivityKit data model
├── SessionActivityState (Struct)        # App Group state storage
└── DeepLinkHandler (Enum)              # URL routing

Widget Extension (SwiftClimbWidgets)
├── ClimbingSessionLiveActivity (Widget) # ActivityKit configuration
├── LockScreenView (View)                # Lock Screen UI
├── DynamicIsland* Views (Views)         # Dynamic Island UI
└── ClimbingSessionAttributes (Import)   # Shared data model
```

### Data Flow

```
User Action (Start Session)
    │
    ├──► StartSessionUseCase.execute()
    │        │
    │        ├──► SessionService.createSession()  [SwiftData write]
    │        │
    │        └──► LiveActivityManager.startActivity()
    │                 │
    │                 ├──► Activity.request()  [ActivityKit]
    │                 │
    │                 └──► SessionActivityState.write()  [App Group]
    │
    └──► Lock Screen & Dynamic Island Display

User Action (Add Climb)
    │
    ├──► AddClimbUseCase.execute()
    │        │
    │        ├──► ClimbService.createClimb()  [SwiftData write]
    │        │
    │        └──► LiveActivityManager.updateActivity()
    │                 │
    │                 ├──► Activity.update()  [ActivityKit]
    │                 │
    │                 └──► SessionActivityState.write()  [App Group]
    │
    └──► Live Activity Updates

User Taps "Add Climb" in Live Activity
    │
    ├──► Deep Link: swiftclimb://session/{id}/add-climb
    │
    ├──► SwiftClimbApp.onOpenURL()
    │        │
    │        └──► pendingDeepLink = DeepLink(url: url)
    │
    ├──► ActiveSessionContent.onChange(of: pendingDeepLink)
    │        │
    │        └──► showAddClimb = true
    │
    └──► AddClimbSheet Presented
```

## Implementation Details

### 1. ClimbingSessionAttributes

The ActivityKit data model defines static and dynamic state for the Live Activity.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimbPackage/Sources/SwiftClimbFeature/ClimbingSessionAttributes.swift`

```swift
public struct ClimbingSessionAttributes: ActivityAttributes {
    // Static attributes (immutable after activity starts)
    public let sessionId: UUID
    public let discipline: String  // Stored as String for widget compatibility
    public let startedAt: Date
    public let deepLinkScheme: String = "swiftclimb"

    // Dynamic state (updatable during activity)
    public struct ContentState: Codable, Hashable {
        public let climbCount: Int
        public let attemptCount: Int
        public let lastUpdated: Date
    }
}
```

**Key Design Decisions**:

- **Discipline as String**: The `Discipline` enum is app-specific and not available in the widget extension. Storing the raw value allows the widget to display discipline information without importing the entire domain model.
- **Shared Module**: This type MUST be in `SwiftClimbFeature` package so both the main app and widget extension use the exact same type. ActivityKit matches activities by fully qualified type name.
- **Deep Link Construction**: Convenience properties construct URLs for navigating back to the app.

**Convenience Extensions**:

```swift
extension ClimbingSessionAttributes {
    public var disciplineDisplayName: String {
        switch discipline {
        case "bouldering": return "Bouldering"
        case "sport": return "Sport"
        case "trad": return "Trad"
        case "top_rope": return "Top Rope"
        default: return discipline.capitalized
        }
    }

    public var addClimbDeepLink: URL? {
        URL(string: "\(deepLinkScheme)://session/\(sessionId.uuidString)/add-climb")
    }
}
```

### 2. LiveActivityManager

Actor-based manager for thread-safe Live Activity lifecycle management.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Core/LiveActivity/LiveActivityManager.swift`

```swift
actor LiveActivityManager: LiveActivityManagerProtocol {
    private var currentActivity: Activity<ClimbingSessionAttributes>?
    private var currentSessionId: UUID?
    private var currentClimbCount: Int = 0
    private var currentAttemptCount: Int = 0

    func startActivity(
        sessionId: UUID,
        discipline: Discipline,
        startedAt: Date
    ) async {
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        // End any existing activity
        await endAllActivities()

        let attributes = ClimbingSessionAttributes(
            sessionId: sessionId,
            discipline: discipline.rawValue,
            startedAt: startedAt
        )

        let initialState = ClimbingSessionAttributes.ContentState.initial

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: nil  // Local updates only
        )

        currentActivity = activity
        currentSessionId = sessionId
        currentClimbCount = 0
        currentAttemptCount = 0

        // Write to App Group
        writeState(sessionId: sessionId, discipline: discipline.rawValue, startedAt: startedAt)
    }

    func updateActivity(
        sessionId: UUID,
        climbCount: Int,
        attemptCount: Int
    ) async {
        guard let activity = currentActivity,
              currentSessionId == sessionId else {
            return
        }

        currentClimbCount = climbCount
        currentAttemptCount = attemptCount

        let newState = ClimbingSessionAttributes.ContentState(
            climbCount: climbCount,
            attemptCount: attemptCount,
            lastUpdated: Date()
        )

        await activity.update(ActivityContent(state: newState, staleDate: nil))

        // Update App Group state
        writeState(
            sessionId: sessionId,
            discipline: activity.attributes.discipline,
            startedAt: activity.attributes.startedAt
        )
    }

    func endActivity(sessionId: UUID) async {
        guard let activity = currentActivity,
              currentSessionId == sessionId else {
            return
        }

        await activity.end(dismissalPolicy: .immediate)

        currentActivity = nil
        currentSessionId = nil

        // Clear App Group state
        SessionActivityState.clear()
    }
}
```

**Key Design Decisions**:

- **Actor Isolation**: All access is serialized automatically, preventing race conditions when multiple updates occur rapidly (e.g., logging multiple climbs in quick succession).
- **Single Activity**: Only one Live Activity is active at a time. Starting a new session ends any existing activity.
- **Non-Throwing**: ActivityKit errors are logged but don't propagate to callers. Live Activity failures should never break core app functionality.
- **State Caching**: Keeps current counts in memory for quick incremental updates without database queries.
- **App Group Sync**: Writes state to App Group after each update for potential future widget extensions.

### 3. SessionActivityState

Lightweight state stored in App Group for cross-target communication.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Shared/SessionActivityState.swift`

```swift
struct SessionActivityState: Codable, Sendable {
    let sessionId: UUID
    let discipline: String
    let startedAt: Date
    let climbCount: Int
    let attemptCount: Int
    let lastUpdated: Date

    static let appGroupIdentifier = "group.com.swiftclimb.shared"
    static let stateKey = "activeSessionState"

    static func read() -> SessionActivityState? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: stateKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionActivityState.self, from: data)
    }

    func write() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Self.stateKey)
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        defaults.removeObject(forKey: stateKey)
    }
}
```

**Purpose**: The widget extension cannot access SwiftData, so this provides a lightweight communication bridge. While not currently used by the Live Activity (which gets data from `ClimbingSessionAttributes`), it's available for potential future widget extensions or complications.

### 4. ClimbingSessionLiveActivity Widget

The WidgetKit configuration that defines Lock Screen and Dynamic Island views.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimbWidgets/LiveActivity/ClimbingSessionActivity.swift`

```swift
struct ClimbingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingSessionAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(WidgetDesignTokens.accentColor)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { /* ... */ }
                DynamicIslandExpandedRegion(.trailing) { /* ... */ }
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandCenterView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBottomView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                CompactLeadingView(attributes: context.attributes)
            } compactTrailing: {
                CompactTrailingView(
                    attributes: context.attributes,
                    state: context.state
                )
            } minimal: {
                MinimalView(attributes: context.attributes)
            }
        }
    }
}
```

#### Lock Screen View

Full-featured view showing comprehensive session information:

- **Header Row**: Discipline badge (e.g., "Bouldering") + Elapsed timer
- **Session Info Row**: Date + Start time
- **Stats Row**: Climb count + Attempt count + Add Climb button

```swift
private struct LockScreenView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            // Header with discipline and timer
            HStack {
                // Discipline badge
                HStack(spacing: 4) {
                    Image(systemName: "figure.climbing")
                    Text(attributes.disciplineDisplayName)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .cornerRadius(8)

                Spacer()

                // Elapsed timer
                Text(attributes.startedAt, style: .timer)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            // Stats and Add Climb button
            HStack(spacing: 16) {
                StatView(icon: "number", value: "\(state.climbCount)", label: "Climbs")
                StatView(icon: "arrow.counterclockwise", value: "\(state.attemptCount)", label: "Attempts")

                Spacer()

                if let url = attributes.addClimbDeepLink {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Climb")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetDesignTokens.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white)
                        .cornerRadius(20)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}
```

#### Dynamic Island Compact View

Minimal pill view shown when Live Activity is active:

- **Leading**: Climbing figure icon
- **Trailing**: Elapsed timer

#### Dynamic Island Expanded View

Full view shown when user long-presses the Dynamic Island:

- **Center**: Stats (climbs/attempts), discipline badge, timer, start time
- **Bottom**: Add Climb button (full-width)

### 5. Deep Link Handling

Deep links allow Live Activity buttons to navigate directly to specific screens in the app.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/DeepLinkHandler.swift`

```swift
enum DeepLink: Equatable, Sendable {
    case addClimb(sessionId: UUID)
    case viewSession(sessionId: UUID)
    case unknown

    static let scheme = "swiftclimb"

    init(url: URL) {
        guard url.scheme == Self.scheme,
              url.host == "session" else {
            self = .unknown
            return
        }

        let pathComponents = url.pathComponents
        guard pathComponents.count >= 2,
              let sessionId = UUID(uuidString: pathComponents[1]) else {
            self = .unknown
            return
        }

        if pathComponents.count >= 3 && pathComponents[2] == "add-climb" {
            self = .addClimb(sessionId: sessionId)
        } else {
            self = .viewSession(sessionId: sessionId)
        }
    }
}
```

**URL Format**: `swiftclimb://session/{sessionId}[/action]`

**Examples**:
- `swiftclimb://session/123e4567-e89b-12d3-a456-426614174000/add-climb`
- `swiftclimb://session/123e4567-e89b-12d3-a456-426614174000`

**App Integration**:

```swift
// In SwiftClimbApp.swift
@State private var pendingDeepLink: DeepLink?

var body: some Scene {
    WindowGroup {
        ContentView()
            .onOpenURL { url in
                pendingDeepLink = DeepLink(url: url)
            }
            .environment(\.pendingDeepLink, $pendingDeepLink)
    }
}

// In ActiveSessionContent.swift
@Environment(\.pendingDeepLink) private var pendingDeepLink

var body: some View {
    // ...
    .onChange(of: pendingDeepLink?.wrappedValue) { _, deepLink in
        if case .addClimb(let sessionId) = deepLink,
           sessionId == session.id {
            showAddClimb = true
            pendingDeepLink?.wrappedValue = nil
        }
    }
}
```

## Use Case Integration

Live Activity is integrated into the following use cases:

### StartSessionUseCase

```swift
final class StartSessionUseCase: StartSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    func execute(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID {
        let startedAt = Date()

        // 1. Create session locally (offline-first)
        let sessionId = try await sessionService.createSession(
            userId: userId,
            discipline: discipline,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )

        // 2. Start Live Activity
        await liveActivityManager?.startActivity(
            sessionId: sessionId,
            discipline: discipline,
            startedAt: startedAt
        )

        return sessionId
    }
}
```

### AddClimbUseCase

```swift
final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let attemptService: AttemptServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        data: AddClimbData,
        // ...
    ) async throws -> UUID {
        // Create climb and attempts
        let climbId = try await climbService.createClimb(/* ... */)
        try await createAttempts(/* ... */)

        // Update Live Activity with new counts
        if let liveActivityManager = liveActivityManager {
            let counts = try await climbService.getSessionCounts(sessionId: sessionId)
            await liveActivityManager.updateActivity(
                sessionId: sessionId,
                climbCount: counts.climbCount,
                attemptCount: counts.attemptCount
            )
        }

        return climbId
    }
}
```

### EndSessionUseCase

```swift
final class EndSessionUseCase: EndSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // End session locally
        try await sessionService.endSession(
            sessionId: sessionId,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes
        )

        // End Live Activity
        await liveActivityManager?.endActivity(sessionId: sessionId)
    }
}
```

### Other Use Cases

The following use cases also update Live Activity counts:

- **LogAttemptUseCase**: Increments attempt count
- **DeleteClimbUseCase**: Decrements climb and attempt counts
- **DeleteAttemptUseCase**: Decrements attempt count

## Configuration Requirements

### 1. Info.plist

Enable Live Activities support in the main app target.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Info.plist`

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 2. URL Scheme

Configure the custom URL scheme for deep linking.

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.swiftclimb</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>swiftclimb</string>
        </array>
    </dict>
</array>
```

### 3. App Groups

Configure App Group entitlement in both main app and widget extension targets.

**Identifier**: `group.com.swiftclimb.shared`

This allows `SessionActivityState` to be shared via UserDefaults between targets.

### 4. Widget Extension Target

The `SwiftClimbWidgets` target must include:
- `ClimbingSessionLiveActivity` widget configuration
- `ClimbingSessionAttributes` from `SwiftClimbFeature` package
- Widget design tokens (colors, spacing, typography)

## Testing

### Manual Testing

1. **Start Session**:
   - Launch app and start a new climbing session
   - Lock device and verify Live Activity appears on Lock Screen
   - On iPhone 14 Pro+, verify Dynamic Island shows compact view

2. **Add Climb**:
   - Tap "Add Climb" in Lock Screen Live Activity
   - Verify app opens and Add Climb sheet is presented
   - Complete the form and submit
   - Verify Live Activity updates with new climb/attempt counts

3. **Expanded Dynamic Island**:
   - Long-press Dynamic Island (iPhone 14 Pro+)
   - Verify expanded view shows stats, discipline, timer
   - Tap "Add Climb" button
   - Verify same behavior as Lock Screen button

4. **End Session**:
   - Return to app and end session
   - Verify Live Activity dismisses immediately

### Debugging Tips

**Live Activity not appearing**:
- Check `ActivityAuthorizationInfo().areActivitiesEnabled`
- Verify `NSSupportsLiveActivities` is `true` in Info.plist
- Check console logs for ActivityKit errors

**Deep linking not working**:
- Verify URL scheme is registered in Info.plist
- Print the URL in `onOpenURL` handler to verify format
- Check that `DeepLink` parsing logic matches URL structure
- Ensure `pendingDeepLink` environment value is injected

**Counts not updating**:
- Add logging in `LiveActivityManager.updateActivity()`
- Verify `sessionId` matches between update call and current activity
- Check that use cases are calling `updateActivity()` after persistence

**Widget not displaying**:
- Ensure `ClimbingSessionAttributes` is imported from the correct module
- Verify both main app and widget extension use same type (fully qualified name must match)
- Check that widget target includes `SwiftClimbFeature` package

## Best Practices

### 1. Non-Blocking Updates

Live Activity updates should never block UI operations:

```swift
// ✅ GOOD: Optional LiveActivityManager, non-throwing
await liveActivityManager?.updateActivity(
    sessionId: sessionId,
    climbCount: counts.climbCount,
    attemptCount: counts.attemptCount
)

// ❌ BAD: Required, throws errors
try await liveActivityManager.updateActivity(/* ... */)
```

### 2. Session ID Validation

Always validate session ID before updating:

```swift
func updateActivity(sessionId: UUID, climbCount: Int, attemptCount: Int) async {
    guard let activity = currentActivity,
          currentSessionId == sessionId else {
        return  // Silently ignore mismatched updates
    }
    // ... update logic
}
```

### 3. Clean Shutdown

Always end Live Activity when session completes:

```swift
func execute(sessionId: UUID, rpe: Int?, pumpLevel: Int?, notes: String?) async throws {
    // Persist to SwiftData first
    try await sessionService.endSession(/* ... */)

    // Then clean up Live Activity
    await liveActivityManager?.endActivity(sessionId: sessionId)
}
```

### 4. Error Handling

Log ActivityKit errors but don't propagate them:

```swift
do {
    let activity = try Activity.request(/* ... */)
    currentActivity = activity
} catch {
    logger.error("Failed to start activity: \(error)")
    // Don't throw - app should work fine without Live Activity
}
```

### 5. Type Safety

Use shared package for `ClimbingSessionAttributes` to ensure type matching:

```swift
// ✅ GOOD: Import from shared package
import SwiftClimbFeature

// ❌ BAD: Duplicate type definition in each target
// struct ClimbingSessionAttributes { /* ... */ }  // This breaks ActivityKit matching
```

## Future Enhancements

### Potential Improvements

1. **Remote Notifications**: Use `pushType: .token` to enable remote activity updates
2. **More Actions**: Add buttons for quick actions (e.g., "End Session", "View Stats")
3. **Rich Timer**: Replace text timer with circular progress indicator
4. **Stale Date**: Set `staleDate` to dim activity after extended inactivity
5. **Alert Configuration**: Use `.contentState` alerts for milestones (e.g., "10 climbs logged!")
6. **Historical Activities**: Display past activities in widget timeline

### Design Considerations

**Battery Impact**: Live Activities use minimal battery since updates are push-based. However, excessive updates (e.g., every second) should be avoided. Current implementation only updates when climbs/attempts change.

**Privacy**: Lock Screen content is visible without authentication. Ensure no sensitive information (e.g., location coordinates, personal notes) is displayed.

**Accessibility**: All text uses system fonts with Dynamic Type support. Icons have accessibility labels. Timer uses `.monospacedDigit()` for consistent width.

## Troubleshooting

### Common Issues

**Issue**: Activity starts but doesn't update
- **Cause**: Session ID mismatch between start and update calls
- **Solution**: Log session IDs in both operations to verify they match

**Issue**: Deep link opens app but doesn't show sheet
- **Cause**: View is not observing `pendingDeepLink` environment value
- **Solution**: Add `@Environment(\.pendingDeepLink)` and `.onChange(of:)` handler

**Issue**: Widget shows "No Activity"
- **Cause**: Type name mismatch between app and widget
- **Solution**: Ensure both targets import from `SwiftClimbFeature`, not local definitions

**Issue**: Timer shows incorrect time
- **Cause**: `startedAt` timestamp is wrong or device time changed
- **Solution**: Always use server-synced time if available, or persist `startedAt` carefully

### Debugging Commands

```swift
// Check if Live Activities are supported
let authInfo = ActivityAuthorizationInfo()
print("Activities enabled: \(authInfo.areActivitiesEnabled)")

// List all active activities
for activity in Activity<ClimbingSessionAttributes>.activities {
    print("Active activity: \(activity.id), session: \(activity.attributes.sessionId)")
}

// Force end all activities (useful for testing)
await endAllActivities()
```

## References

- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Live Activities Guide](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Dynamic Island HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [SwiftClimb Offline-First Architecture](../ARCHITECTURE.md)
