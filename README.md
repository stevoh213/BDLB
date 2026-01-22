# SwiftClimb - iOS Climbing Logbook

A modern iOS climbing logbook application built with SwiftUI, SwiftData, and Swift 6 strict concurrency. SwiftClimb helps climbers track sessions, log attempts, analyze progress, and connect with the climbing community.

## Features

### Core Features
- **Session Tracking**: Start/end climbing sessions with mental and physical readiness metrics
- **Climb Logging**: Record climbs with grade, discipline, location, and notes
- **Attempt Tracking**: Log individual attempts with outcomes, send types, and timestamps
- **Live Activity**: Real-time session stats on Lock Screen and Dynamic Island (iPhone 14 Pro+)
- **Offline-First**: All data persists locally with SwiftData, syncs in background when online
- **Tag System**: Categorize climbs by technique, skill, and wall style with impact indicators

### Integrations
- **Supabase Backend**: Authentication, Row Level Security, 14 database tables
- **OpenBeta API**: Search outdoor climbs with comprehensive route information
- **Keychain Storage**: Secure token storage with automatic refresh

### Social Features (Planned)
- Follow climbers
- Share sessions and climbs
- Kudos and comments
- Activity feed

### Premium Features
- **Subscription System**: StoreKit 2 integration with monthly and annual plans
- **Advanced Analytics**: Insights tab with volume trends and progression (premium-gated)
- **Unlimited History**: Full logbook access (free users limited to 30 days)
- **OpenBeta Integration**: Search outdoor climbs from comprehensive route database (premium-only)
- **Offline Grace Period**: 7-day offline access for verified premium subscribers
- **Cross-Device Sync**: Premium status synced via Supabase profiles table
- **Support Team Access**: Premium subscription data stored in Supabase for customer support queries

## Project Status

**Current Version**: 0.1.0 (Alpha)
**Platform**: iOS 18.0+
**Language**: Swift 6
**Architecture**: Model-View (MV) with offline-first design

### What's Implemented
✅ Complete project structure with Xcode workspace
✅ 73 Swift files with actor-based concurrency
✅ SwiftData models with 15 tables (including SCPremiumStatus)
✅ Supabase authentication (sign up, sign in, sign out, token refresh)
✅ Real-time username availability checking with debouncing (500ms)
✅ Username format validation (3-20 chars, alphanumeric + underscore, starts with letter)
✅ Design system with reusable components
✅ Tab-based navigation (Session, Logbook, Insights, Feed, Profile)
✅ Live Activity with Lock Screen and Dynamic Island support
✅ Deep linking from Live Activity buttons
✅ Dev bypass for testing (DEBUG builds only)
✅ Keychain token storage
✅ Premium subscription system with StoreKit 2
✅ Paywall UI with monthly/annual pricing
✅ Premium feature gates (Insights, Logbook, OpenBeta)
✅ 7-day offline grace period for premium subscribers

### In Progress
🚧 Service implementations (Session, Climb, Attempt services)
🚧 Background sync with conflict resolution
🚧 Social features (Follow, Posts, Kudos, Comments)
🚧 Insights analytics implementation (UI built, calculations pending)

See [NEXT_STEPS.md](NEXT_STEPS.md) for detailed roadmap.

## Quick Start

### Prerequisites
- macOS 15.0+ (Sequoia)
- Xcode 16.0+
- iOS 18.0+ device or simulator
- Supabase account (for backend features)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/SwiftClimb.git
   cd SwiftClimb
   ```

2. **Open the workspace**
   ```bash
   open SwiftClimb.xcworkspace
   ```

3. **Configure Supabase** (Optional - app works offline without this)
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Run the SQL migrations from `/Database/migrations/`
   - Update `SwiftClimb/Integrations/Supabase/SupabaseConfig.swift`:
     ```swift
     static let url = "https://YOUR_PROJECT.supabase.co"
     static let anonKey = "YOUR_ANON_KEY"
     ```

4. **Build and run**
   - Select a simulator or device
   - Press `Cmd+R` to build and run
   - Use dev bypass in DEBUG builds to skip authentication

### Dev Bypass (DEBUG Only)
In DEBUG builds, tap "Dev Bypass" on the auth screen to skip authentication and use mock data. This is automatically removed in Release builds.

**Note for AI assistants**: Read [CLAUDE.md](CLAUDE.md) for project conventions before making changes.

## Project Architecture

SwiftClimb follows a **layered architecture** with clear separation of concerns:

```
SwiftClimb/
├── SwiftClimb.xcworkspace/              # Open this in Xcode
├── SwiftClimb.xcodeproj/                # Xcode project
├── Config/                              # Build configuration
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Shared.xcconfig
│   └── SwiftClimb.entitlements
├── SwiftClimb/                          # Source code
│   ├── App/
│   │   ├── SwiftClimbApp.swift         # @main entry point
│   │   ├── ContentView.swift           # Root TabView
│   │   └── AuthView.swift              # Authentication UI
│   ├── Core/
│   │   ├── DesignSystem/               # Tokens + Components
│   │   ├── Networking/                 # HTTP + GraphQL clients
│   │   ├── Persistence/                # SwiftData + Keychain
│   │   └── Sync/                       # Background sync actors
│   ├── Domain/
│   │   ├── Models/                     # SwiftData @Model classes
│   │   ├── Services/                   # Service protocols
│   │   └── UseCases/                   # Business logic
│   ├── Features/
│   │   ├── Session/                    # Session tracking UI
│   │   ├── Logbook/                    # Session history UI
│   │   ├── Insights/                   # Analytics UI (premium)
│   │   ├── Feed/                       # Social feed UI
│   │   └── Profile/                    # Profile settings UI
│   └── Integrations/
│       ├── Supabase/                   # Auth + database sync
│       └── OpenBeta/                   # Outdoor climb search
└── docs/                                # All documentation
```

### Key Architectural Principles

1. **Offline-First**: SwiftData is the source of truth for UI, Supabase syncs in background
2. **Actor Isolation**: All network and sync operations use Swift actors for thread safety
3. **Model-View (MV)**: Views observe SwiftData via `@Query`, call UseCases for business logic
4. **Dependency Injection**: UseCases injected via `@Environment` for testability
5. **Strict Concurrency**: Swift 6 concurrency checking enabled throughout

See [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) for detailed architecture documentation.

## Configuration

### Build Settings
Build settings are managed through **XCConfig files** in `Config/`:
- `Shared.xcconfig` - Bundle ID, version, deployment target (iOS 18.0)
- `Debug.xcconfig` - Debug-specific settings
- `Release.xcconfig` - Release-specific settings

### Entitlements
App capabilities in `Config/SwiftClimb.entitlements`:
- Keychain access groups (for token storage)
- Network client entitlement (for Supabase/OpenBeta)

## Development Guide

### Code Organization
- **App Layer**: Entry point, navigation, dependency injection
- **Core Layer**: Shared infrastructure (design system, networking, sync)
- **Domain Layer**: Models, services, use cases (business logic)
- **Features Layer**: Feature-specific SwiftUI views
- **Integrations Layer**: External service integrations

### Adding a New Feature
1. Create models in `Domain/Models/`
2. Define service protocol in `Domain/Services/`
3. Implement use case in `Domain/UseCases/`
4. Create UI in `Features/YourFeature/`
5. Inject use case via `@Environment` in `SwiftClimbApp.swift`

### Design System
Reusable components in `Core/DesignSystem/`:
- **Tokens**: Spacing, Typography, Colors, CornerRadius
- **Components**: SCGlassCard, SCPrimaryButton, SCMetricPill, etc.

All components support:
- Dynamic Type
- Reduce Transparency
- VoiceOver
- Minimum 44x44pt tap targets

### Testing Strategy
- **Unit Tests**: Test services and use cases in isolation
- **Integration Tests**: Test SwiftData persistence and sync
- **UI Tests**: Test user flows end-to-end

*Note: Test suite is not yet implemented - tracked in NEXT_STEPS.md*
## Resources

### Documentation
- [Documentation Index](docs/README.md) - Complete documentation navigation
- [Architecture Guide](docs/architecture/ARCHITECTURE.md) - Detailed architecture documentation
- [Design System](docs/architecture/DESIGN_SYSTEM.md) - Component library and design tokens
- [Sync Strategy](docs/architecture/SYNC_STRATEGY.md) - Offline-first sync implementation
- [Live Activity](docs/LIVE_ACTIVITY_INDEX.md) - Live Activity implementation and API reference
- [CLAUDE.md](CLAUDE.md) - AI assistant project context and conventions

### External Links
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Swift 6 Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Supabase Documentation](https://supabase.com/docs)
- [OpenBeta API](https://openbeta.io/developers)

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the coding standards in CLAUDE.md
4. Add tests for new functionality
5. Run the test suite
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Coding Standards
- Follow Swift API Design Guidelines
- Use Swift 6 strict concurrency (async/await, actors)
- Write descriptive commit messages
- Add inline documentation for public APIs
- Ensure all views support accessibility features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **OpenBeta** - Comprehensive climbing route database
- **Supabase** - Backend infrastructure and authentication
- **XcodeBuildMCP** - AI-assisted development tooling

## Contact

For questions, feedback, or support:
- Open an issue on GitHub
- Email: support@swiftclimb.app (if applicable)

---

**Built with SwiftUI, SwiftData, and Swift 6**
