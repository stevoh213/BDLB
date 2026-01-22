# Guide: Adding Live Activities to SwiftClimb

## Overview

This guide walks you through adding Live Activity support to a new feature in SwiftClimb. It uses the existing Climbing Session Live Activity as a reference and explains the required steps.

## Prerequisites

- Xcode 15+
- iOS 18+ deployment target
- Understanding of ActivityKit framework
- Familiarity with SwiftClimb's offline-first architecture

## Step 1: Define Activity Attributes

Create your activity attributes in the `SwiftClimbFeature` package (shared between app and widget).

**File**: `SwiftClimbPackage/Sources/SwiftClimbFeature/YourFeatureAttributes.swift`

```swift
#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

#if canImport(ActivityKit)
public struct YourFeatureAttributes: ActivityAttributes {
    // MARK: - Static Attributes (immutable after start)

    /// Unique identifier for the feature instance
    public let featureId: UUID

    /// Any other immutable data
    public let startedAt: Date

    /// Deep link scheme (consistent across all activities)
    public let deepLinkScheme: String = "swiftclimb"

    // MARK: - ContentState (dynamic, updatable)

    public struct ContentState: Codable, Hashable {
        /// Dynamic data that changes during activity
        public let count: Int
        public let lastUpdated: Date

        /// Initial state when activity starts
        public static var initial: ContentState {
            ContentState(count: 0, lastUpdated: Date())
        }

        public init(count: Int, lastUpdated: Date) {
            self.count = count
            self.lastUpdated = lastUpdated
        }
    }

    // MARK: - Initializer

    public init(featureId: UUID, startedAt: Date) {
        self.featureId = featureId
        self.startedAt = startedAt
    }
}

// MARK: - Convenience Extensions

extension YourFeatureAttributes {
    /// Constructs deep link URL for primary action
    public var primaryActionDeepLink: URL? {
        URL(string: "\(deepLinkScheme)://feature/\(featureId.uuidString)/action")
    }
}
#endif
```

**Key Points**:
- Place in shared package so both app and widget can access
- Use `#if canImport(ActivityKit)` for iOS-only features
- Store primitive types only (no custom enums or classes)
- Use `String` for enum values if widget needs to display them

## Step 2: Create Activity Manager

Create a manager actor for thread-safe lifecycle management.

**File**: `SwiftClimb/Core/LiveActivity/YourFeatureActivityManager.swift`

```swift
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif
import Foundation
import os.log

private let logger = Logger(subsystem: "com.bdlb.app", category: "YourFeatureActivity")

/// Protocol for dependency injection and testing
protocol YourFeatureActivityManagerProtocol: Sendable {
    func startActivity(featureId: UUID, startedAt: Date) async
    func updateActivity(featureId: UUID, count: Int) async
    func endActivity(featureId: UUID) async
    func hasActiveActivity(featureId: UUID) async -> Bool
}

#if canImport(ActivityKit)
actor YourFeatureActivityManager: YourFeatureActivityManagerProtocol {

    private var currentActivity: Activity<YourFeatureAttributes>?
    private var currentFeatureId: UUID?
    private var currentCount: Int = 0

    // MARK: - Lifecycle

    func startActivity(featureId: UUID, startedAt: Date) async {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Activities not enabled or not supported")
            return
        }

        // End any existing activity
        await endAllActivities()

        let attributes = YourFeatureAttributes(
            featureId: featureId,
            startedAt: startedAt
        )

        let initialState = YourFeatureAttributes.ContentState.initial

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil  // Local updates only
            )

            currentActivity = activity
            currentFeatureId = featureId
            currentCount = 0

            logger.info("Started activity for feature \(featureId)")
        } catch {
            logger.error("Failed to start activity: \(error)")
        }
    }

    func updateActivity(featureId: UUID, count: Int) async {
        guard let activity = currentActivity,
              currentFeatureId == featureId else {
            return
        }

        currentCount = count

        let newState = YourFeatureAttributes.ContentState(
            count: count,
            lastUpdated: Date()
        )

        await activity.update(ActivityContent(state: newState, staleDate: nil))

        logger.info("Updated activity: \(count)")
    }

    func endActivity(featureId: UUID) async {
        guard let activity = currentActivity,
              currentFeatureId == featureId else {
            return
        }

        let finalState = YourFeatureAttributes.ContentState(
            count: currentCount,
            lastUpdated: Date()
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        currentFeatureId = nil
        currentCount = 0

        logger.info("Ended activity for feature \(featureId)")
    }

    func hasActiveActivity(featureId: UUID) async -> Bool {
        return currentFeatureId == featureId && currentActivity != nil
    }

    // MARK: - Private Helpers

    private func endAllActivities() async {
        for activity in Activity<YourFeatureAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        currentActivity = nil
        currentFeatureId = nil
    }
}
#else
// Stub for non-iOS platforms
actor YourFeatureActivityManager: YourFeatureActivityManagerProtocol {
    func startActivity(featureId: UUID, startedAt: Date) async {}
    func updateActivity(featureId: UUID, count: Int) async {}
    func endActivity(featureId: UUID) async {}
    func hasActiveActivity(featureId: UUID) async -> Bool { false }
}
#endif
```

**Key Points**:
- Use `actor` for automatic thread-safety
- Always check `areActivitiesEnabled` before starting
- Log errors but don't throw (activity failures shouldn't break app)
- Validate feature ID before updates
- Provide stub implementation for non-iOS platforms

## Step 3: Create Widget Views

Create the widget extension views for Lock Screen and Dynamic Island.

**File**: `SwiftClimbWidgets/LiveActivity/YourFeatureLiveActivity.swift`

```swift
import ActivityKit
import SwiftClimbFeature
import SwiftUI
import WidgetKit

struct YourFeatureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: YourFeatureAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(WidgetDesignTokens.accentColor)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                // Compact left side
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(WidgetDesignTokens.accentColor)
            } compactTrailing: {
                // Compact right side
                Text("\(context.state.count)")
                    .font(.system(size: 14, design: .rounded).weight(.medium))
            } minimal: {
                // Minimal view
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetDesignTokens.accentColor)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let attributes: YourFeatureAttributes
    let state: YourFeatureAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            // Your lock screen UI
            HStack {
                Text("Feature Name")
                    .font(.headline)
                Spacer()
                Text(attributes.startedAt, style: .timer)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Count: \(state.count)")
                    .font(.title2.bold())

                Spacer()

                // Action button with deep link
                if let url = attributes.primaryActionDeepLink {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Action")
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

// MARK: - Dynamic Island Expanded Views

private struct ExpandedCenterView: View {
    let attributes: YourFeatureAttributes
    let state: YourFeatureAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            Text("\(state.count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetDesignTokens.accentColor)

            Text(attributes.startedAt, style: .timer)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

private struct ExpandedBottomView: View {
    let attributes: YourFeatureAttributes
    let state: YourFeatureAttributes.ContentState

    var body: some View {
        if let url = attributes.primaryActionDeepLink {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Action")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WidgetDesignTokens.accentColor)
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: YourFeatureAttributes(
    featureId: UUID(),
    startedAt: Date().addingTimeInterval(-3600)
)) {
    YourFeatureLiveActivity()
} contentStates: {
    YourFeatureAttributes.ContentState(
        count: 10,
        lastUpdated: Date()
    )
}
```

**Key Points**:
- Use `WidgetDesignTokens` for consistent styling
- Always provide deep link actions via `Link` views
- Use `.timer` style for elapsed time display
- Include SwiftUI previews for rapid iteration

## Step 4: Add to Widget Bundle

Register your new Live Activity in the widget bundle.

**File**: `SwiftClimbWidgets/SwiftClimbWidgets.swift`

```swift
import WidgetKit
import SwiftUI

@main
struct SwiftClimbWidgets: WidgetBundle {
    var body: some Widget {
        ClimbingSessionLiveActivity()
        YourFeatureLiveActivity()  // Add your new activity
    }
}
```

## Step 5: Integrate with Use Cases

Add activity manager to relevant use cases.

```swift
final class StartFeatureUseCase: StartFeatureUseCaseProtocol, Sendable {
    private let featureService: FeatureServiceProtocol
    private let activityManager: YourFeatureActivityManagerProtocol?

    init(
        featureService: FeatureServiceProtocol,
        activityManager: YourFeatureActivityManagerProtocol? = nil
    ) {
        self.featureService = featureService
        self.activityManager = activityManager
    }

    func execute(featureData: FeatureData) async throws -> UUID {
        let startedAt = Date()

        // 1. Persist locally (offline-first)
        let featureId = try await featureService.createFeature(data: featureData)

        // 2. Start Live Activity
        await activityManager?.startActivity(
            featureId: featureId,
            startedAt: startedAt
        )

        return featureId
    }
}
```

**Key Points**:
- Make activity manager optional (`?`) so feature works without it
- Always persist to SwiftData first (offline-first)
- Start activity after successful persistence
- Use optional chaining (`?.`) for all activity operations

## Step 6: Add Deep Link Handling

Extend `DeepLink` enum to handle your new actions.

**File**: `SwiftClimb/App/DeepLinkHandler.swift`

```swift
enum DeepLink: Equatable, Sendable {
    // Existing cases
    case addClimb(sessionId: UUID)
    case viewSession(sessionId: UUID)

    // Your new cases
    case yourFeatureAction(featureId: UUID)
    case viewYourFeature(featureId: UUID)

    case unknown

    init(url: URL) {
        guard url.scheme == Self.scheme else {
            self = .unknown
            return
        }

        // Existing session handling
        if url.host == "session" {
            // ... existing logic
        }

        // Your feature handling
        if url.host == "feature" {
            let pathComponents = url.pathComponents
            guard pathComponents.count >= 2,
                  let featureId = UUID(uuidString: pathComponents[1]) else {
                self = .unknown
                return
            }

            if pathComponents.count >= 3 && pathComponents[2] == "action" {
                self = .yourFeatureAction(featureId: featureId)
            } else {
                self = .viewYourFeature(featureId: featureId)
            }
            return
        }

        self = .unknown
    }
}
```

## Step 7: Handle Deep Links in Views

Observe pending deep link in your view and respond appropriately.

```swift
struct YourFeatureView: View {
    @Environment(\.pendingDeepLink) private var pendingDeepLink
    @State private var showActionSheet = false

    var body: some View {
        // Your view content
        Text("Feature View")
            .sheet(isPresented: $showActionSheet) {
                ActionSheet()
            }
            .onChange(of: pendingDeepLink?.wrappedValue) { _, deepLink in
                if case .yourFeatureAction(let featureId) = deepLink,
                   featureId == yourFeatureId {
                    showActionSheet = true
                    pendingDeepLink?.wrappedValue = nil
                }
            }
    }
}
```

## Step 8: Update App Initialization

Wire up your activity manager in the app entry point.

**File**: `SwiftClimb/App/SwiftClimbApp.swift`

```swift
@main
struct SwiftClimbApp: App {
    // ... existing properties

    let yourFeatureActivityManager: YourFeatureActivityManagerProtocol

    init() {
        // ... existing initialization

        // Initialize activity manager
        let activityMgr = YourFeatureActivityManager()
        self.yourFeatureActivityManager = activityMgr

        // Initialize use cases with activity manager
        startFeatureUseCase = StartFeatureUseCase(
            featureService: featureService,
            activityManager: activityMgr
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.yourFeatureActivityManager, yourFeatureActivityManager)
        }
    }
}
```

## Step 9: Add Environment Key

Create environment key for dependency injection.

**File**: `SwiftClimb/App/Environment+UseCases.swift`

```swift
extension EnvironmentValues {
    @Entry var yourFeatureActivityManager: YourFeatureActivityManagerProtocol? = nil
}
```

## Testing Checklist

- [ ] Activity appears on Lock Screen when feature starts
- [ ] Activity shows correct initial state
- [ ] Activity updates when data changes
- [ ] Activity dismisses when feature ends
- [ ] Deep link opens app and shows correct screen
- [ ] Dynamic Island shows compact view (iPhone 14 Pro+)
- [ ] Dynamic Island expands correctly (long-press)
- [ ] Timer displays elapsed time correctly
- [ ] Multiple rapid updates don't crash
- [ ] Activity works offline (no network required)

## Best Practices

### Do's

- ✅ Use shared package for attributes
- ✅ Make activity manager optional in use cases
- ✅ Log errors but don't throw
- ✅ Validate IDs before updates
- ✅ Use actor for thread-safety
- ✅ Persist data before starting activity
- ✅ Clear pending deep link after handling
- ✅ Use `#if canImport(ActivityKit)` for iOS-only code

### Don'ts

- ❌ Don't block UI on activity operations
- ❌ Don't duplicate attribute types across targets
- ❌ Don't store complex objects in attributes
- ❌ Don't update activity before persisting data
- ❌ Don't throw errors from activity manager
- ❌ Don't forget to end activity when feature completes
- ❌ Don't use force unwrapping in widget code

## Common Issues

### Activity doesn't appear
- Check `NSSupportsLiveActivities` in Info.plist
- Verify `ActivityAuthorizationInfo().areActivitiesEnabled`
- Check device supports Live Activities (iOS 16.1+)
- Look for errors in console logs

### Deep link doesn't work
- Verify URL scheme in Info.plist
- Check `DeepLink` parsing logic
- Ensure view observes `pendingDeepLink`
- Print URL to verify format

### Activity doesn't update
- Verify feature ID matches
- Check that use case calls `updateActivity()`
- Look for actor isolation issues
- Add logging to track update calls

### Widget shows wrong data
- Ensure attribute type matches exactly
- Verify package import (not local duplicate)
- Check ContentState is being updated
- Review SwiftUI preview for layout issues

## Resources

- [SwiftClimb Live Activity Implementation](../features/LIVE_ACTIVITY.md)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Live Activities Best Practices](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Dynamic Island Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/live-activities)
