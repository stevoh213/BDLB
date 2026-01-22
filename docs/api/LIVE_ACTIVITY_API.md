# Live Activity API Reference

## Overview

This document provides a complete API reference for SwiftClimb's Live Activity implementation. All types are thread-safe and follow Swift 6 strict concurrency.

## Core Types

### ClimbingSessionAttributes

**Module**: `SwiftClimbFeature`
**Availability**: iOS 16.1+
**Conformances**: `ActivityAttributes`

Static and dynamic data for climbing session Live Activities.

```swift
public struct ClimbingSessionAttributes: ActivityAttributes {
    public let sessionId: UUID
    public let discipline: String
    public let startedAt: Date
    public let deepLinkScheme: String

    public struct ContentState: Codable, Hashable {
        public let climbCount: Int
        public let attemptCount: Int
        public let lastUpdated: Date

        public static var initial: ContentState
    }
}
```

#### Properties

##### `sessionId: UUID`
Unique identifier matching `SCSession.id`. Used for validation and deep linking.

##### `discipline: String`
Raw value of `Discipline` enum (e.g., "bouldering", "sport"). Stored as String for widget compatibility.

##### `startedAt: Date`
Session start timestamp. Used for elapsed timer display in Lock Screen and Dynamic Island.

##### `deepLinkScheme: String`
URL scheme for deep links. Always `"swiftclimb"`.

#### ContentState

Dynamic state that updates during the session.

##### `climbCount: Int`
Total number of climbs logged in this session.

##### `attemptCount: Int`
Total number of attempts across all climbs.

##### `lastUpdated: Date`
Timestamp of most recent state update. Used for staleness detection.

##### `static var initial: ContentState`
Initial state with zero climbs and attempts.

#### Convenience Properties

##### `var disciplineDisplayName: String`
Human-readable discipline name.

```swift
attributes.disciplineDisplayName  // "Bouldering"
```

##### `var disciplineIcon: String`
SF Symbol name for discipline icon.

```swift
attributes.disciplineIcon  // "figure.climbing"
```

##### `var addClimbDeepLink: URL?`
Deep link URL for Add Climb action.

```swift
attributes.addClimbDeepLink
// swiftclimb://session/{sessionId}/add-climb
```

##### `var viewSessionDeepLink: URL?`
Deep link URL for viewing session.

```swift
attributes.viewSessionDeepLink
// swiftclimb://session/{sessionId}
```

---

### LiveActivityManagerProtocol

**Module**: `SwiftClimb/Core/LiveActivity`
**Availability**: iOS 16.1+
**Conformances**: `Sendable`

Protocol for managing Live Activity lifecycle.

```swift
protocol LiveActivityManagerProtocol: Sendable {
    func startActivity(sessionId: UUID, discipline: Discipline, startedAt: Date) async
    func endActivity(sessionId: UUID) async
    func updateActivity(sessionId: UUID, climbCount: Int, attemptCount: Int) async
    func incrementAttemptCount(sessionId: UUID) async
    func decrementAttemptCount(sessionId: UUID) async
    func hasActiveActivity(sessionId: UUID) async -> Bool
}
```

#### Methods

##### `func startActivity(sessionId:discipline:startedAt:) async`

Starts a new Live Activity for a climbing session.

**Parameters**:
- `sessionId`: Unique identifier of the session
- `discipline`: Climbing discipline (bouldering, sport, etc.)
- `startedAt`: Session start time (for elapsed timer)

**Behavior**:
- Ends any existing activity before starting new one
- Checks `ActivityAuthorizationInfo().areActivitiesEnabled`
- Writes initial state to App Group
- Non-throwing (logs errors internally)

**Example**:
```swift
await liveActivityManager.startActivity(
    sessionId: session.id,
    discipline: .bouldering,
    startedAt: session.startedAt
)
```

##### `func endActivity(sessionId:) async`

Ends the Live Activity for a session.

**Parameters**:
- `sessionId`: Session whose activity should end

**Behavior**:
- Dismisses activity immediately
- Clears App Group state
- No-op if session ID doesn't match current activity

**Example**:
```swift
await liveActivityManager.endActivity(sessionId: session.id)
```

##### `func updateActivity(sessionId:climbCount:attemptCount:) async`

Updates activity state with new counts.

**Parameters**:
- `sessionId`: Session to update
- `climbCount`: New total climb count
- `attemptCount`: New total attempt count

**Behavior**:
- Updates displayed counts in real-time
- Writes updated state to App Group
- No-op if session ID doesn't match

**Example**:
```swift
await liveActivityManager.updateActivity(
    sessionId: session.id,
    climbCount: 5,
    attemptCount: 12
)
```

##### `func incrementAttemptCount(sessionId:) async`

Increments attempt count by 1.

**Parameters**:
- `sessionId`: Session to update

**Behavior**:
- Uses internal climb count
- Convenience method for logging single attempts
- No-op if session ID doesn't match

**Example**:
```swift
await liveActivityManager.incrementAttemptCount(sessionId: session.id)
```

##### `func decrementAttemptCount(sessionId:) async`

Decrements attempt count by 1 (minimum 0).

**Parameters**:
- `sessionId`: Session to update

**Behavior**:
- Used when attempt is deleted
- Cannot go below 0
- No-op if session ID doesn't match

**Example**:
```swift
await liveActivityManager.decrementAttemptCount(sessionId: session.id)
```

##### `func hasActiveActivity(sessionId:) async -> Bool`

Checks if activity exists for a session.

**Parameters**:
- `sessionId`: Session to check

**Returns**: `true` if activity is active

**Example**:
```swift
if await liveActivityManager.hasActiveActivity(sessionId: session.id) {
    print("Live Activity is running")
}
```

---

### LiveActivityManager

**Module**: `SwiftClimb/Core/LiveActivity`
**Availability**: iOS 16.1+
**Conformances**: `LiveActivityManagerProtocol`, `Actor`

Concrete actor implementation of Live Activity management.

```swift
actor LiveActivityManager: LiveActivityManagerProtocol {
    private var currentActivity: Activity<ClimbingSessionAttributes>?
    private var currentSessionId: UUID?
    private var currentClimbCount: Int
    private var currentAttemptCount: Int
}
```

#### Actor Isolation

All methods are isolated to the actor, ensuring thread-safe access. Multiple concurrent calls are automatically serialized.

#### State Management

The manager maintains internal state to support incremental updates:
- Current activity reference
- Session ID for validation
- Cached climb and attempt counts

#### Error Handling

All ActivityKit errors are logged but not thrown. This ensures Live Activity failures don't break core app functionality.

---

### SessionActivityState

**Module**: `SwiftClimb/Shared`
**Availability**: iOS 16.1+
**Conformances**: `Codable`, `Sendable`

Lightweight state stored in App Group for widget access.

```swift
struct SessionActivityState: Codable, Sendable {
    let sessionId: UUID
    let discipline: String
    let startedAt: Date
    let climbCount: Int
    let attemptCount: Int
    let lastUpdated: Date

    static let appGroupIdentifier: String
    static let stateKey: String
}
```

#### Properties

##### `static let appGroupIdentifier: String`
App Group identifier: `"group.com.swiftclimb.shared"`

##### `static let stateKey: String`
UserDefaults key: `"activeSessionState"`

#### Methods

##### `static func read() -> SessionActivityState?`
Reads current state from App Group UserDefaults.

**Returns**: Stored state, or `nil` if no active session

**Example**:
```swift
if let state = SessionActivityState.read() {
    print("Active session: \(state.sessionId)")
}
```

##### `func write()`
Writes this state to App Group UserDefaults.

**Behavior**:
- Synchronous operation
- Safe to call from any thread
- Fails silently if App Group unavailable

**Example**:
```swift
let state = SessionActivityState(
    sessionId: session.id,
    discipline: "bouldering",
    startedAt: session.startedAt,
    climbCount: 5,
    attemptCount: 12,
    lastUpdated: Date()
)
state.write()
```

##### `static func clear()`
Clears state from App Group UserDefaults.

**Behavior**:
- Called when session ends
- Removes stale state

**Example**:
```swift
SessionActivityState.clear()
```

---

### DeepLink

**Module**: `SwiftClimb/App`
**Availability**: iOS 16.1+
**Conformances**: `Equatable`, `Sendable`

Parsed deep link actions from Live Activity buttons.

```swift
enum DeepLink: Equatable, Sendable {
    case addClimb(sessionId: UUID)
    case viewSession(sessionId: UUID)
    case unknown

    static let scheme: String
    init(url: URL)
}
```

#### Cases

##### `case addClimb(sessionId: UUID)`
Open Add Climb sheet for session.

##### `case viewSession(sessionId: UUID)`
Navigate to session view.

##### `case unknown`
Unrecognized or malformed URL.

#### Properties

##### `static let scheme: String`
URL scheme: `"swiftclimb"`

#### Initializer

##### `init(url: URL)`
Parses URL into deep link action.

**Parameters**:
- `url`: URL to parse

**URL Format**: `swiftclimb://session/{sessionId}[/action]`

**Examples**:
```swift
let url = URL(string: "swiftclimb://session/123e4567-e89b-12d3-a456-426614174000/add-climb")!
let deepLink = DeepLink(url: url)

switch deepLink {
case .addClimb(let sessionId):
    showAddClimbSheet(for: sessionId)
case .viewSession(let sessionId):
    navigateToSession(sessionId)
case .unknown:
    // Handle gracefully
}
```

#### Factory Methods

##### `static func addClimbURL(sessionId:) -> URL?`
Creates Add Climb deep link URL.

**Parameters**:
- `sessionId`: Target session

**Returns**: Formatted deep link URL

**Example**:
```swift
let url = DeepLink.addClimbURL(sessionId: session.id)
// swiftclimb://session/{sessionId}/add-climb
```

##### `static func viewSessionURL(sessionId:) -> URL?`
Creates session view deep link URL.

**Parameters**:
- `sessionId`: Target session

**Returns**: Formatted deep link URL

**Example**:
```swift
let url = DeepLink.viewSessionURL(sessionId: session.id)
// swiftclimb://session/{sessionId}
```

---

## Environment Keys

### pendingDeepLink

Binding to pending deep link from Live Activity.

```swift
extension EnvironmentValues {
    @Entry var pendingDeepLink: Binding<DeepLink?>?
}
```

#### Usage

**In App**:
```swift
@State private var pendingDeepLink: DeepLink?

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(\.pendingDeepLink, $pendingDeepLink)
            .onOpenURL { url in
                pendingDeepLink = DeepLink(url: url)
            }
    }
}
```

**In View**:
```swift
@Environment(\.pendingDeepLink) private var pendingDeepLink

var body: some View {
    Text("View")
        .onChange(of: pendingDeepLink?.wrappedValue) { _, deepLink in
            if case .addClimb(let sessionId) = deepLink {
                showAddClimbSheet(for: sessionId)
                pendingDeepLink?.wrappedValue = nil
            }
        }
}
```

### liveActivityManager

Access to Live Activity manager.

```swift
extension EnvironmentValues {
    @Entry var liveActivityManager: LiveActivityManagerProtocol?
}
```

#### Usage

```swift
@Environment(\.liveActivityManager) private var liveActivityManager

func startSession() async {
    await liveActivityManager?.startActivity(
        sessionId: sessionId,
        discipline: .bouldering,
        startedAt: Date()
    )
}
```

---

## Widget Components

### ClimbingSessionLiveActivity

**Module**: `SwiftClimbWidgets`
**Availability**: iOS 16.1+
**Conformances**: `Widget`

Main widget configuration for climbing session Live Activities.

```swift
struct ClimbingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingSessionAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland { /* ... */ }
        }
    }
}
```

#### Lock Screen Layout

- **Header**: Discipline badge + Elapsed timer
- **Info Row**: Date + Start time
- **Stats Row**: Climb count + Attempt count + Add Climb button

#### Dynamic Island Compact Layout

- **Leading**: Climbing figure icon
- **Trailing**: Elapsed timer

#### Dynamic Island Expanded Layout

- **Center**: Stats (climbs/attempts) + Discipline + Timer + Start time
- **Bottom**: Add Climb button (full-width)

---

## Configuration

### Info.plist Keys

#### NSSupportsLiveActivities

Enable Live Activities support.

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

**Required**: Yes
**Target**: Main app

#### CFBundleURLTypes

Configure custom URL scheme for deep linking.

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

**Required**: Yes (for deep linking)
**Target**: Main app

### Entitlements

#### App Groups

Enable App Group for state sharing.

**Identifier**: `group.com.swiftclimb.shared`

**Required**: Yes
**Targets**: Main app, Widget extension

---

## Thread Safety

All Live Activity types follow Swift 6 strict concurrency:

- **Actors**: `LiveActivityManager` uses actor isolation for thread-safe state
- **Sendable**: All protocols and data types conform to `Sendable`
- **@MainActor**: Widget views use `@MainActor` for UI updates
- **Async/Await**: All manager operations are async for proper isolation

---

## Performance Considerations

### Update Frequency

Live Activities should update only when meaningful data changes:

```swift
// ✅ GOOD: Update when climb is added
await liveActivityManager.updateActivity(
    sessionId: sessionId,
    climbCount: newCount,
    attemptCount: newAttemptCount
)

// ❌ BAD: Update every second (unnecessary)
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    await liveActivityManager.updateActivity(/* ... */)
}
```

### Memory Usage

The manager caches minimal state:
- Activity reference: ~8 bytes
- Session ID: 16 bytes
- Two integers: 16 bytes

Total overhead: ~40 bytes per active session.

### Battery Impact

Live Activities use push-based updates with minimal battery impact. The elapsed timer is rendered by the system without app execution.

---

## Error Handling

### ActivityKit Errors

All ActivityKit errors are caught and logged:

```swift
do {
    let activity = try Activity.request(/* ... */)
} catch {
    logger.error("Failed to start activity: \(error)")
    // Continue - app works fine without Live Activity
}
```

**Common Errors**:
- `ActivityAuthorizationInfo.areActivitiesEnabled == false`
- Device doesn't support Live Activities (iOS < 16.1)
- Too many active activities (system limit)
- Activity type mismatch (widget and app use different types)

### Validation Errors

Session ID mismatches are silently ignored:

```swift
func updateActivity(sessionId: UUID, climbCount: Int, attemptCount: Int) async {
    guard currentSessionId == sessionId else {
        return  // No-op if ID doesn't match
    }
    // ... update logic
}
```

---

## Debugging

### Logging

All operations are logged with `os.log`:

```swift
private let logger = Logger(subsystem: "com.bdlb.app", category: "LiveActivity")

logger.info("Started activity for session \(sessionId)")
logger.error("Failed to start activity: \(error)")
```

### Console Output

Example log output:

```
[LiveActivity] Started activity for session 123e4567-e89b-12d3-a456-426614174000
[LiveActivity] Activity ID: ABC123-DEF456
[LiveActivity] Updated activity: 5 climbs, 12 attempts
[LiveActivity] Ended activity for session 123e4567-e89b-12d3-a456-426614174000
```

### Common Debugging Commands

```swift
// Check if activities are enabled
let authInfo = ActivityAuthorizationInfo()
print("Enabled: \(authInfo.areActivitiesEnabled)")

// List active activities
for activity in Activity<ClimbingSessionAttributes>.activities {
    print("Active: \(activity.id)")
}

// Force end all activities
await liveActivityManager.endAllActivities()
```

---

## See Also

- [Live Activity Feature Documentation](../features/LIVE_ACTIVITY.md)
- [Adding Live Activities Guide](../guides/ADDING_LIVE_ACTIVITIES.md)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
