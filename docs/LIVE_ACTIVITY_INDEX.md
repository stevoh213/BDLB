# Live Activity Documentation Index

## Overview

SwiftClimb's Live Activity feature provides real-time climbing session information on the Lock Screen and Dynamic Island for iPhone users. This documentation covers the complete implementation, from architecture to API reference.

## Documentation Structure

### 1. Feature Documentation
**[Live Activity Feature](features/LIVE_ACTIVITY.md)**

Comprehensive documentation of the Live Activity implementation covering:
- Architecture overview and component diagram
- Data flow from user actions to UI updates
- Detailed implementation of all major components
- Use case integration patterns
- Configuration requirements
- Testing strategies
- Best practices and troubleshooting

**Target Audience**: Developers who need to understand or modify the existing Live Activity implementation.

**When to Read**:
- Understanding how Live Activity works in SwiftClimb
- Debugging Live Activity issues
- Making architectural changes
- Code review

### 2. Developer Guide
**[Adding Live Activities Guide](guides/ADDING_LIVE_ACTIVITIES.md)**

Step-by-step guide for adding Live Activity support to new features:
- Creating activity attributes
- Implementing activity managers
- Building widget views
- Integrating with use cases
- Handling deep links
- Testing checklist

**Target Audience**: Developers adding Live Activity to new features.

**When to Read**:
- Implementing Live Activity for a new feature
- Following best practices for Live Activity development
- Understanding the implementation workflow

### 3. API Reference
**[Live Activity API Reference](api/LIVE_ACTIVITY_API.md)**

Complete API documentation including:
- `ClimbingSessionAttributes` data model
- `LiveActivityManagerProtocol` and implementation
- `SessionActivityState` App Group storage
- `DeepLink` URL routing
- Environment keys and configuration
- Widget components
- Thread safety guarantees
- Performance considerations

**Target Audience**: Developers implementing or consuming Live Activity APIs.

**When to Read**:
- Looking up method signatures and parameters
- Understanding type conformances
- Checking thread safety requirements
- Debugging API usage

## Quick Start

### I want to understand the Live Activity feature
Start with **[Live Activity Feature](features/LIVE_ACTIVITY.md)** for a complete overview.

### I want to add Live Activity to a new feature
Follow the **[Adding Live Activities Guide](guides/ADDING_LIVE_ACTIVITIES.md)** step-by-step.

### I need API documentation
Refer to the **[Live Activity API Reference](api/LIVE_ACTIVITY_API.md)**.

### I'm debugging an issue
1. Check **[Troubleshooting](features/LIVE_ACTIVITY.md#troubleshooting)** section
2. Review **[Common Issues](guides/ADDING_LIVE_ACTIVITIES.md#common-issues)**
3. Consult **[Error Handling](api/LIVE_ACTIVITY_API.md#error-handling)** in API reference

## Key Concepts

### Offline-First Architecture
Live Activities follow SwiftClimb's offline-first pattern:
1. Persist data to SwiftData first
2. Update Live Activity after successful persistence
3. Activity updates are non-blocking and don't throw errors

### Actor-Based Concurrency
All Live Activity management uses Swift actors for thread safety:
- `LiveActivityManager` is an actor with automatic serialization
- All methods are async and properly isolated
- No manual locking or synchronization required

### Shared Type Definition
`ClimbingSessionAttributes` must be defined in a shared package:
- Both main app and widget extension must use the exact same type
- ActivityKit matches activities by fully qualified type name
- Located in `SwiftClimbFeature` package for maximum portability

### Deep Linking
Live Activity buttons use custom URL scheme for navigation:
- Format: `swiftclimb://session/{sessionId}/action`
- Parsed into `DeepLink` enum for type-safe routing
- Views observe `pendingDeepLink` environment value

## File Locations

### Core Implementation

```
SwiftClimb/
├── Core/LiveActivity/
│   ├── LiveActivityManager.swift           # Actor-based manager
│   └── LiveActivityManagerProtocol.swift   # Protocol for DI
├── Shared/
│   ├── ClimbingSessionAttributes.swift     # Re-export from package
│   └── SessionActivityState.swift          # App Group state
└── App/
    ├── DeepLinkHandler.swift                # URL routing
    ├── SwiftClimbApp.swift                  # DI + onOpenURL handler
    └── Environment+UseCases.swift           # Environment keys
```

### Shared Package

```
SwiftClimbPackage/Sources/SwiftClimbFeature/
└── ClimbingSessionAttributes.swift          # Shared data model
```

### Widget Extension

```
SwiftClimbWidgets/
├── SwiftClimbWidgets.swift                  # Widget bundle
├── LiveActivity/
│   └── ClimbingSessionActivity.swift       # UI implementation
└── Shared/
    └── WidgetDesignTokens.swift            # Design system
```

### Use Case Integration

```
SwiftClimb/Domain/UseCases/
├── StartSessionUseCase.swift               # Starts activity
├── EndSessionUseCase.swift                 # Ends activity
├── AddClimbUseCase.swift                   # Updates counts
├── LogAttemptUseCase.swift                 # Increments attempts
├── DeleteClimbUseCase.swift                # Decrements counts
└── DeleteAttemptUseCase.swift              # Decrements attempts
```

### Configuration

```
SwiftClimb/
├── Info.plist                              # NSSupportsLiveActivities + URL scheme
└── Config/
    └── SwiftClimb.entitlements             # App Group capability
```

## Related Documentation

- **[SwiftClimb Architecture](ARCHITECTURE.md)** - Overall app architecture
- **[Offline-First Guide](guides/OFFLINE_FIRST.md)** - Offline-first patterns
- **[Concurrency Guide](guides/CONCURRENCY.md)** - Swift Concurrency best practices
- **[Design System](DESIGN_SYSTEM.md)** - UI design tokens

## External Resources

- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit) - Apple's official framework docs
- [Live Activities Guide](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) - Implementation guide
- [Dynamic Island HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities) - Design guidelines
- [WWDC22 Session 10184](https://developer.apple.com/videos/play/wwdc2022/10184/) - Introducing Live Activities

## FAQ

### Q: Why is `discipline` stored as `String` instead of `Discipline` enum?
**A**: The widget extension doesn't have access to the `Discipline` enum from the main app. Storing the raw value allows the widget to display discipline information without importing the entire domain model.

### Q: Why use an actor instead of a class with locks?
**A**: Actors provide automatic thread-safety through compiler-enforced serialization. This eliminates manual locking, prevents deadlocks, and integrates seamlessly with Swift Concurrency.

### Q: Can I update Live Activity from a background task?
**A**: Yes, but ensure the update happens through an actor-isolated call. All `LiveActivityManager` methods are async and properly isolated for background execution.

### Q: What happens if ActivityKit is unavailable?
**A**: The implementation uses `#if canImport(ActivityKit)` to provide stub implementations on platforms without ActivityKit (e.g., macOS). The main app works fine without Live Activity support.

### Q: How do I test Live Activity on simulator?
**A**: Live Activities work on iOS 16.1+ simulators. Lock Screen testing requires using "Lock" from the simulator menu. Dynamic Island requires iPhone 14 Pro or later simulator.

### Q: Why doesn't the timer update in real-time?
**A**: The `.timer` style uses the system-rendered timer that updates automatically. No manual updates are needed. If the timer appears frozen, verify the `startedAt` timestamp is correct.

### Q: Can multiple sessions have Live Activities simultaneously?
**A**: No, only one Live Activity is active at a time. Starting a new session ends any existing activity. This is enforced by `LiveActivityManager` calling `endAllActivities()` before starting a new one.

### Q: How do I debug deep linking issues?
**A**: Add logging to `onOpenURL` handler and `DeepLink.init(url:)`. Print the incoming URL to verify format. Ensure the view observing `pendingDeepLink` has a valid `onChange(of:)` handler.

## Contributing

When contributing to Live Activity documentation:

1. **Feature docs**: Update `features/LIVE_ACTIVITY.md` when implementation changes
2. **Guide**: Update `guides/ADDING_LIVE_ACTIVITIES.md` when adding new patterns
3. **API Reference**: Keep `api/LIVE_ACTIVITY_API.md` in sync with code changes
4. **This index**: Update when adding new documentation files

Ensure all code examples compile and follow SwiftClimb's coding standards.

## Changelog

### 2026-01-22 - Initial Documentation
- Created comprehensive feature documentation
- Added step-by-step developer guide
- Compiled complete API reference
- Established documentation structure

---

**Last Updated**: 2026-01-22
**SwiftClimb Version**: 1.0 (iOS 18.0+)
**ActivityKit Version**: iOS 16.1+
