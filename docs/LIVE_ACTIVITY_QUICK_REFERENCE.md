# Live Activity Quick Reference

**SwiftClimb Live Activity Cheat Sheet**

## Common Operations

### Start a Live Activity

```swift
await liveActivityManager.startActivity(
    sessionId: session.id,
    discipline: .bouldering,
    startedAt: session.startedAt
)
```

### Update Live Activity

```swift
await liveActivityManager.updateActivity(
    sessionId: session.id,
    climbCount: 5,
    attemptCount: 12
)
```

### End Live Activity

```swift
await liveActivityManager.endActivity(sessionId: session.id)
```

## Deep Link Format

```
swiftclimb://session/{sessionId}/add-climb
swiftclimb://session/{sessionId}
```

## Handling Deep Links

```swift
@Environment(\.pendingDeepLink) private var pendingDeepLink

var body: some View {
    Text("View")
        .onChange(of: pendingDeepLink?.wrappedValue) { _, deepLink in
            if case .addClimb(let sessionId) = deepLink,
               sessionId == currentSessionId {
                showSheet = true
                pendingDeepLink?.wrappedValue = nil
            }
        }
}
```

## Required Configuration

### Info.plist

```xml
<key>NSSupportsLiveActivities</key>
<true/>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>swiftclimb</string>
        </array>
    </dict>
</array>
```

### Entitlements

**App Group**: `group.com.swiftclimb.shared`

## Type Definitions

### ClimbingSessionAttributes

```swift
public struct ClimbingSessionAttributes: ActivityAttributes {
    public let sessionId: UUID
    public let discipline: String
    public let startedAt: Date

    public struct ContentState: Codable, Hashable {
        public let climbCount: Int
        public let attemptCount: Int
        public let lastUpdated: Date
    }
}
```

### LiveActivityManagerProtocol

```swift
protocol LiveActivityManagerProtocol: Sendable {
    func startActivity(sessionId: UUID, discipline: Discipline, startedAt: Date) async
    func updateActivity(sessionId: UUID, climbCount: Int, attemptCount: Int) async
    func endActivity(sessionId: UUID) async
}
```

## File Locations

| Type | Location |
|------|----------|
| Attributes | `SwiftClimbPackage/Sources/SwiftClimbFeature/ClimbingSessionAttributes.swift` |
| Manager | `SwiftClimb/Core/LiveActivity/LiveActivityManager.swift` |
| Widget | `SwiftClimbWidgets/LiveActivity/ClimbingSessionActivity.swift` |
| Deep Links | `SwiftClimb/App/DeepLinkHandler.swift` |

## Debugging Commands

```swift
// Check if enabled
let authInfo = ActivityAuthorizationInfo()
print("Enabled: \(authInfo.areActivitiesEnabled)")

// List active activities
for activity in Activity<ClimbingSessionAttributes>.activities {
    print("Active: \(activity.id)")
}
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Activity not appearing | Check `NSSupportsLiveActivities` in Info.plist |
| Deep link not working | Verify URL scheme registration |
| Counts not updating | Ensure session ID matches |
| Widget not displaying | Verify type is imported from `SwiftClimbFeature` |

## Documentation Links

- **Overview**: [LIVE_ACTIVITY_INDEX.md](LIVE_ACTIVITY_INDEX.md)
- **Feature Docs**: [features/LIVE_ACTIVITY.md](features/LIVE_ACTIVITY.md)
- **API Reference**: [api/LIVE_ACTIVITY_API.md](api/LIVE_ACTIVITY_API.md)
- **Developer Guide**: [guides/ADDING_LIVE_ACTIVITIES.md](guides/ADDING_LIVE_ACTIVITIES.md)

---

**Last Updated**: 2026-01-22
