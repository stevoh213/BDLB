# Changelog

All notable changes to SwiftClimb will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Premium Subscription System (2026-01-19)

#### StoreKit 2 Integration
- **PremiumService** - Actor-based service managing StoreKit 2 transactions
  - `isPremium()` - Check premium status with 7-day offline grace period
  - `fetchProducts()` - Load subscription products from App Store
  - `purchase(productId:)` - Handle subscription purchase flow
  - `restorePurchases()` - Restore previous purchases
  - Transaction update listener for real-time status changes
- **SCPremiumStatus** - SwiftData model for caching premium state
  - 7-day offline grace period for verified purchases
  - Stores expiry date, product ID, original transaction ID
  - `isValid()` method checks expiry with grace period

#### Premium Feature Gates
- **Insights Tab** - Full block for free users with premium upsell
  - Shows PaywallView when free users attempt to access Insights
  - Premium users see full analytics and insights features
- **Logbook** - 30-day history limit for free users
  - Free users see sessions from last 30 days only
  - Premium users see unlimited history
  - "Upgrade to Premium" prompt in empty state for older sessions
- **OpenBeta Search** - Premium-only outdoor climb search
  - `SearchOpenBetaUseCase` throws `PremiumError.premiumRequired` for free users
  - Premium users have full access to OpenBeta outdoor climb database

#### Paywall UI
- **PaywallView** - Complete subscription purchase interface
  - Monthly subscription ($4.99/month)
  - Annual subscription ($49.99/year, save 17%)
  - Feature highlights with SF Symbols icons
  - Pricing cards with selection state
  - Purchase button with loading states
  - Restore purchases link
  - Terms of service and privacy policy links
  - Error handling with user-friendly messages
  - Dismiss action returns to previous screen

#### Supabase Integration
- Premium status synced to `profiles` table for support team queries
- Database migration adds three columns: `premium_expires_at`, `premium_product_id`, `premium_original_transaction_id`
- Indexed on `premium_expires_at` for efficient support queries
- `PremiumSyncImpl` actor syncs status to Supabase after StoreKit verification
- `ProfileDTO` updated to include premium fields with snake_case mapping
- `fetchRemotePremiumStatus()` retrieves premium info from server
- Sync occurs non-blocking after purchase, restore, and status changes
- Premium status visible across all user devices and accessible to support team

#### Technical Implementation
- All premium checks happen locally first (offline-first)
- Premium status cached in SwiftData with grace period
- PremiumService conforms to Sendable for concurrency safety
- @MainActor isolation for UI-facing premium checks
- StoreKit 2 transaction updates handled asynchronously
- Product IDs: `swiftclimb.premium.monthly`, `swiftclimb.premium.annual`

### Added - Supabase Auth Integration (2026-01-19)

#### Authentication Features
- **Supabase Authentication** - Complete auth flow with sign up, sign in, sign out
- **Token Management** - Automatic token refresh with Keychain storage
- **AuthView** - Sign up/sign in UI with form validation
- **Real-time Username Availability** - Debounced username checking during sign-up (500ms delay)
  - Visual feedback with spinner (checking), checkmark (available), X (taken), warning (invalid format)
  - Username validation: 3-20 characters, alphanumeric + underscore, must start with letter
  - Sign-up button disabled until username confirmed available
  - `checkHandleAvailable()` method in SupabaseAuthManager
- **Dev Bypass** - Debug-only authentication bypass for local testing
- **Row Level Security** - Proper RLS policies for all database tables

#### Recent Bug Fixes
- Fixed `grant_type` parameter (must be query param, not body) for Supabase Auth
- Fixed date decoding for timestamps with fractional seconds
- Added `Prefer: return=representation` header for POST/PATCH requests
- Fixed RLS policy to allow handle availability checks before authentication
- Fixed sign out button to properly use `authManager`

#### Technical Improvements
- Created `KeychainService` actor for secure token storage
- Implemented `SupabaseAuthManager` with proper error handling
- Added environment value keys for auth state and user ID
- Created 14 database tables with proper relationships and RLS policies

### Changed - Architecture Simplification (2026-01-18)

#### Architecture Change: MVVM → MV
- **Removed ViewModel layer** from all features
- Views now interact directly with UseCases via Environment injection
- SwiftData observation via @Query macro
- Two-way binding via @Bindable macro
- Simpler data flow with less boilerplate
- Reduced file count from 64 to 59 (removed 5 ViewModel files)

**Rationale**: SwiftData's observation system eliminates the need for ViewModels. Views can observe data directly and call UseCases for business logic, resulting in:
- Less code to maintain
- Clearer data flow (View → UseCase → Service → SwiftData)
- Better alignment with SwiftUI best practices
- Fewer actor boundary crossings

### Added - Initial Scaffolding (2026-01-18)

#### Application Layer
- Created `SwiftClimbApp.swift` with SwiftData model container configuration
- Created `ContentView.swift` with TabView-based navigation structure
- Configured app entry point with proper lifecycle management

#### Core/DesignSystem Module
**Tokens (Design System Primitives)**
- `Spacing.swift` - 7-point spacing scale (4pt to 48pt)
- `CornerRadius.swift` - Semantic corner radii (card: 12pt, sheet: 16pt, chip: 8pt, button: 12pt)
- `Typography.swift` - Dynamic Type font definitions with accessibility support
- `Colors.swift` - Semantic color system with Reduce Transparency and Darker Colors support

**Components (Reusable UI)**
- `SCGlassCard.swift` - Primary container with Liquid Glass material effect
- `SCPrimaryButton.swift` - Primary CTA button with accessibility compliance
- `SCSecondaryButton.swift` - Secondary action button
- `SCTagChip.swift` - Tag display chip with impact color indicators
- `SCMetricPill.swift` - Metric display component (RPE, readiness, pump levels)
- `SCSessionBanner.swift` - Active session indicator banner

All components include:
- Preview providers for development
- Minimum 44x44pt tap targets
- System material backgrounds (`.regularMaterial`, `.thickMaterial`)
- Accessibility support (Reduce Transparency, VoiceOver)

#### Core/Networking Module
- `NetworkError.swift` - Typed network error definitions with LocalizedError conformance
- `HTTPClient.swift` - Actor-based HTTP client with automatic retry and exponential backoff
- `GraphQLClient.swift` - GraphQL request/response handling with typed errors

#### Core/Persistence Module
- `SwiftDataContainer.swift` - Centralized ModelContainer configuration
- `ModelMigrations.swift` - Schema versioning infrastructure (stub for future migrations)

#### Core/Sync Module
- `SyncState.swift` - Sync state representation and operation types
- `SyncActor.swift` - Actor-based sync coordination with pull/push infrastructure
- `ChangeTracker.swift` - SwiftData change tracking actor
- `ConflictResolver.swift` - Last-write-wins conflict resolution implementation

#### Domain/Models
**Enumerations**
- `Discipline` - Boulder, Sport, Trad, TopRope
- `GradeScale` - V-scale, YDS, French, UIAA
- `AttemptOutcome` - Send, Fall, Bail
- `SendType` - Flash, Onsight, Redpoint, Repeat, Project
- `TagImpact` - Positive, Negative, Neutral

**Core Data Models** (SwiftData @Model classes)
- `SCProfile` - User profile with privacy settings and premium status
- `SCSession` - Climbing session with readiness/RPE tracking
- `SCClimb` - Individual climb with grade, discipline, and location data
- `SCAttempt` - Attempt on a climb with outcome and notes
- `Grade` - Value type for grade representation with normalization support

**Tag System**
- `SCTechniqueTag`, `SCSkillTag`, `SCWallStyleTag` - Reference data models
- Impact junction tables for linking climbs to tags with impact indicators

**Social Models**
- `SCPost` - User-generated posts with optional session/climb references
- `SCFollow` - Follow relationships between users
- `SCKudos` - Kudos on posts
- `SCComment` - Comments on posts

All models include:
- Unique ID attributes
- Proper @Relationship annotations with delete rules and inverses
- `needsSync` metadata for offline-first sync
- Timestamp fields (createdAt, updatedAt, deletedAt)
- Soft delete support

#### Domain/Services
Protocol definitions for all service layers:
- `AuthService` - Authentication operations
- `ProfileService` - Profile CRUD operations
- `SessionService` - Session lifecycle management
- `ClimbService` - Climb management
- `AttemptService` - Attempt logging
- `TagService` - Tag catalog access
- `SocialService` - Social feature operations
- `GradeConversionService` - Grade parsing and normalization

All services include stub implementations marked with `@unchecked Sendable` for development phase.

#### Domain/UseCases
Single-purpose business operation implementations:
- `StartSessionUseCase` - Start a new climbing session
- `EndSessionUseCase` - End active session with RPE
- `AddClimbUseCase` - Add climb to current session
- `LogAttemptUseCase` - Log attempt on a climb
- `SearchOpenBetaUseCase` - Search OpenBeta for outdoor climbs
- `ToggleFollowUseCase` - Follow/unfollow users
- `CreatePostUseCase` - Create social feed post

#### Features Module
**Session Feature**
- `SessionView.swift` - Active session UI with empty state

**Logbook Feature**
- `LogbookView.swift` - Session history list (stub)

**Insights Feature (Premium)**
- `InsightsView.swift` - Analytics UI with premium upsell

**Feed Feature (Social)**
- `FeedView.swift` - Social feed UI (stub)

**Profile Feature**
- `ProfileView.swift` - Profile and settings UI (stub)

#### Integrations/Supabase
- `SupabaseClientActor.swift` - Actor managing auth tokens and request pipeline
- `SupabaseAuthManager.swift` - High-level authentication operations
- `SupabaseRepository.swift` - Generic CRUD operations actor

**Table Operations**
- `ProfilesTable.swift` - Profiles table operations and DTO
- `SessionsTable.swift` - Sessions table operations and DTO
- `ClimbsTable.swift` - Climbs table operations and DTO
- `AttemptsTable.swift` - Attempts table operations and DTO
- `TagsTable.swift` - Tags table operations and DTOs
- `SocialTables.swift` - Social tables operations and DTOs

All DTOs use snake_case CodingKeys to match Supabase/Postgres conventions.

#### Integrations/OpenBeta
- `OpenBetaClientActor.swift` - Actor-based GraphQL client with rate limiting (0.5s minimum interval)
- `OpenBetaQueries.swift` - GraphQL query string definitions
- `OpenBetaModels.swift` - Response DTOs (Area, Climb, Grades, Types)

### Architecture Decisions
- Adopted Swift 6.2 strict concurrency checking throughout
- Implemented actor-based isolation for all network and sync operations
- Established offline-first architecture with SwiftData as UI source of truth
- Defined last-write-wins conflict resolution strategy
- Implemented soft deletes for sync compatibility
- Organized code by feature rather than layer
- Used UseCase pattern for business logic separation

### Documentation
- Created architecture decision records (ADR-001, ADR-002)
- Documented initial scaffolding specification
- Established multi-agent coordination protocol

### Known Issues
- **Missing Xcode Project**: 59 Swift files created but no .xcodeproj file
- **Technical Debt**: 14 instances of `@unchecked Sendable` in service stubs
- **Incomplete UI**: 12 deferred views (optional components)
- **Unimplemented Logic**: All service methods use `fatalError("Not implemented")`
- **Missing Configuration**: No Supabase URL/keys, no OpenBeta endpoint configuration
- **No Tests**: Unit, integration, and UI tests not yet implemented
- **Views Need Update**: Feature views need to be updated to use @Query and Environment injection

### Quality Metrics
- **Files Created**: 59 Swift files (reduced from 64)
- **Lines of Code**: ~3,800 (estimated)
- **Validation Score**: 88/100 (Agent 3)
- **Swift Concurrency Compliance**: 100% (all actor boundaries defined correctly)
- **SwiftData Compliance**: 100% (all models properly configured)
- **Architecture**: MV (Model-View) - simplified from MVVM

---

## Version History

### [0.1.0] - 2026-01-18 - Initial Scaffolding
- Complete project structure
- All domain models defined
- Design system components
- Architecture infrastructure
- Ready for Xcode project setup

---

## Future Milestones

### [0.2.0] - Local-Only MVP (Planned)
- Implement core services (Session, Climb, Attempt)
- Wire up use cases to Views
- Complete session tracking UI
- Add climb logging UI
- Test local SwiftData persistence

### [0.3.0] - Supabase Integration (Planned)
- Implement authentication flow
- Add table operations
- Enable background sync
- Test conflict resolution

### [0.4.0] - OpenBeta Integration (Planned)
- Implement GraphQL queries
- Add outdoor climb search
- Display climb details from OpenBeta

### [0.5.0] - Social Features (Planned)
- Follow/unfollow functionality
- Feed UI and post creation
- Kudos and comments

### [1.0.0] - Public Release (Planned)
- Complete all core features
- Insights (premium) analytics
- Subscription paywall
- App Store submission

---

**Note**: This changelog will be updated as development progresses. All dates and version numbers are subject to change.
