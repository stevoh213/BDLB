# SwiftClimb Architecture Guide

This document provides a comprehensive overview of SwiftClimb's architecture, design patterns, and implementation details.

## Table of Contents
1. [High-Level Architecture](#high-level-architecture)
2. [Module Organization](#module-organization)
3. [Concurrency Model](#concurrency-model)
4. [Data Flow](#data-flow)
5. [Offline-First Pattern](#offline-first-pattern)
6. [Dependency Injection](#dependency-injection)
7. [Error Handling](#error-handling)

---

## High-Level Architecture

SwiftClimb follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│           Presentation Layer                 │
│          (SwiftUI Views)                     │
│        @MainActor isolated                   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Application Layer                  │
│        (UseCases / Interactors)             │
│         Domain business logic                │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│            Domain Layer                      │
│     (Models, Protocols, Value Types)        │
│         Platform-independent                 │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│          Infrastructure Layer                │
│  (Services, Repositories, Network, Sync)    │
│          Actor-isolated                      │
└─────────────────────────────────────────────┘
```

### Design Principles

1. **Offline-First**: Local SwiftData is the source of truth for UI
2. **Actor Isolation**: Concurrency safety through Swift 6 strict concurrency
3. **Unidirectional Data Flow**: Data flows down, events flow up
4. **Dependency Inversion**: Depend on protocols, not implementations
5. **Single Responsibility**: Each component has one clear purpose

---

## Module Organization

### App Layer
**Purpose**: Application entry point and root navigation

```
App/
├── SwiftClimbApp.swift      # @main entry, dependency setup
└── ContentView.swift         # Root TabView navigation
```

**Responsibilities**:
- Initialize SwiftData model container
- Set up dependency injection
- Configure root navigation structure

**Example**:
```swift
@main
struct SwiftClimbApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = try! SwiftDataContainer.shared.container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

---

### Core Layer
**Purpose**: Shared infrastructure used across features

#### Core/DesignSystem
Design tokens and reusable UI components.

```
Core/DesignSystem/
├── Tokens/
│   ├── Spacing.swift         # 7-point spacing scale
│   ├── Typography.swift      # Dynamic Type fonts
│   ├── Colors.swift          # Semantic colors
│   └── CornerRadius.swift    # Border radii
└── Components/
    ├── SCGlassCard.swift     # Primary container
    ├── SCPrimaryButton.swift # CTA button
    ├── SCSecondaryButton.swift
    ├── SCTagChip.swift       # Tag display
    ├── SCMetricPill.swift    # RPE/readiness/pump
    └── SCSessionBanner.swift # Active session indicator
```

**Pattern**: All components use system materials (`.regularMaterial`, `.thickMaterial`) for Liquid Glass effect.

**Accessibility**:
- Minimum 44x44pt tap targets
- Dynamic Type support
- Reduce Transparency support
- VoiceOver labels

#### Core/Networking
Actor-based HTTP and GraphQL clients.

```
Core/Networking/
├── NetworkError.swift        # Typed errors
├── HTTPClient.swift          # HTTP requests + retry
└── GraphQLClient.swift       # GraphQL handling
```

**Pattern**: All networking is actor-isolated to prevent data races:
```swift
actor HTTPClient {
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Isolated state: retry counts, rate limiting
    }
}
```

#### Core/Persistence
SwiftData configuration and migration management.

```
Core/Persistence/
├── SwiftDataContainer.swift  # ModelContainer singleton
└── ModelMigrations.swift     # Schema versioning
```

**Pattern**: Centralized container configuration ensures all models are registered:
```swift
enum SwiftDataContainer {
    static let shared = SwiftDataContainer()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            SCProfile.self,
            SCSession.self,
            SCClimb.self,
            // ... all models
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        container = try! ModelContainer(
            for: schema,
            configurations: [config]
        )
    }
}
```

#### Core/Sync
Background synchronization with Supabase.

```
Core/Sync/
├── SyncState.swift           # Sync state types
├── SyncActor.swift           # Coordination actor
├── ChangeTracker.swift       # SwiftData change tracking
└── ConflictResolver.swift    # Last-write-wins logic
```

**Pattern**: SyncActor owns all sync state and coordinates background operations:
```swift
actor SyncActor {
    private var lastSyncAt: Date?
    private var isSyncing = false
    private var retryQueue: [SyncOperation] = []

    func pullUpdates() async throws { }
    func pushPendingChanges() async throws { }
}
```

See [SYNC_STRATEGY.md](./SYNC_STRATEGY.md) for detailed sync documentation.

---

### Domain Layer
**Purpose**: Platform-independent business logic and models

#### Domain/Models
SwiftData models and value types.

```
Domain/Models/
├── Enums.swift               # Discipline, GradeScale, etc.
├── Profile.swift             # SCProfile @Model
├── Session.swift             # SCSession @Model
├── Climb.swift               # SCClimb @Model
├── Attempt.swift             # SCAttempt @Model
├── Tags.swift                # Tag models
├── Social.swift              # Social models
└── Grade.swift               # Grade value type
```

**Pattern**: All `@Model` classes follow these conventions:
1. Use `SC` prefix (e.g., `SCSession`)
2. Include `id`, `createdAt`, `updatedAt`, `deletedAt`
3. Include `needsSync` flag for sync coordination
4. Define proper `@Relationship` with delete rules

**Example**:
```swift
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var needsSync: Bool

    @Relationship(deleteRule: .cascade, inverse: \SCClimb.session)
    var climbs: [SCClimb]

    init(/* parameters */) {
        // Set all properties
    }
}
```

**Soft Deletes**: All user-owned data uses `deletedAt` for sync compatibility. See [SYNC_STRATEGY.md](./SYNC_STRATEGY.md) for details.

#### Domain/Services
Protocol definitions for data operations.

```
Domain/Services/
├── AuthService.swift
├── ProfileService.swift
├── SessionService.swift
├── ClimbService.swift
├── AttemptService.swift
├── TagService.swift
├── SocialService.swift
└── GradeConversionService.swift
```

**Pattern**: Each service has a protocol and implementation:
```swift
/// Protocol defines interface (in Domain layer)
protocol SessionServiceProtocol: Sendable {
    func createSession(...) async throws -> SCSession
    func endSession(...) async throws
    func getActiveSession(userId: UUID) async -> SCSession?
}

/// Implementation (in Infrastructure or feature)
actor SessionService: SessionServiceProtocol {
    private let modelContext: ModelContext

    func createSession(...) async throws -> SCSession {
        let session = SCSession(...)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }
}
```

**Why Protocols?**
- Enables testing with mock implementations
- Allows swapping implementations (e.g., in-memory vs. SwiftData)
- Documents interface clearly

#### Domain/UseCases
Single-purpose business operations.

```
Domain/UseCases/
├── StartSessionUseCase.swift
├── EndSessionUseCase.swift
├── AddClimbUseCase.swift
├── LogAttemptUseCase.swift
├── SearchOpenBetaUseCase.swift
├── ToggleFollowUseCase.swift
└── CreatePostUseCase.swift
```

**Pattern**: One UseCase per high-level user action:
```swift
protocol StartSessionUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession
}

final class StartSessionUseCase: StartSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let syncActor: SyncActor

    init(sessionService: SessionServiceProtocol, syncActor: SyncActor) {
        self.sessionService = sessionService
        self.syncActor = syncActor
    }

    func execute(...) async throws -> SCSession {
        // 1. Validate no active session exists
        guard await sessionService.getActiveSession(userId: userId) == nil else {
            throw SessionError.sessionAlreadyActive
        }

        // 2. Create session locally
        let session = try await sessionService.createSession(...)

        // 3. Enqueue for background sync
        await syncActor.enqueue(.insertSession(session))

        return session
    }
}
```

**Why UseCases?**
- Keeps Views thin (no business logic in UI)
- Makes business logic testable in isolation
- Coordinates between multiple services
- Documents system capabilities explicitly
- Provides reusable operations across multiple views

---

### Features Layer
**Purpose**: Feature-specific UI

```
Features/
├── Session/
│   └── SessionView.swift
├── Logbook/
│   └── LogbookView.swift
├── Insights/
│   └── InsightsView.swift
├── Feed/
│   └── FeedView.swift
└── Profile/
    └── ProfileView.swift
```

**Pattern**: Each feature is self-contained with direct View access to UseCases and SwiftData.

**MV Architecture**: Views interact directly with domain layer through:
1. **@Query** for data observation from SwiftData
2. **@Bindable** for two-way data binding to models
3. **UseCases** injected via Environment for business logic
4. **@State** for view-local UI state

**Example View**:
```swift
struct SessionView: View {
    // SwiftData observation
    @Query(
        filter: #Predicate<SCSession> {
            $0.endedAt == nil && $0.deletedAt == nil
        }
    )
    private var activeSessions: [SCSession]

    // UseCase dependencies (injected)
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase

    // View-local state
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var mentalReadiness: Int?
    @State private var physicalReadiness: Int?

    private var currentSession: SCSession? {
        activeSessions.first
    }

    var body: some View {
        if let session = currentSession {
            // Active session UI with @Bindable
            ActiveSessionContent(session: session)
        } else {
            // Empty state: Start session button
            SCPrimaryButton(title: "Start Session") {
                await startNewSession()
            }
            .disabled(isLoading)
        }

        if let error = errorMessage {
            Text(error)
                .foregroundStyle(.red)
        }
    }

    private func startNewSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await startSessionUseCase.execute(
                userId: currentUserId,
                mentalReadiness: mentalReadiness,
                physicalReadiness: physicalReadiness
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ActiveSessionContent: View {
    @Bindable var session: SCSession

    var body: some View {
        // Two-way binding to session properties
        TextField("Notes", text: $session.notes ?? "")
    }
}
```

**Why Feature-Based Organization?**
- Co-locates related code (easier to find)
- Clear module boundaries
- Supports future modularization (Swift Packages)
- Reduces cross-module dependencies

---

### Integrations Layer
**Purpose**: External service integrations

#### Integrations/Supabase
Supabase authentication and database operations.

```
Integrations/Supabase/
├── SupabaseClientActor.swift      # Auth + request pipeline
├── SupabaseAuthManager.swift      # High-level auth operations
├── SupabaseRepository.swift       # Generic CRUD
└── Tables/
    ├── ProfilesTable.swift        # Profiles CRUD + DTO
    ├── SessionsTable.swift        # Sessions CRUD + DTO
    ├── ClimbsTable.swift          # Climbs CRUD + DTO
    ├── AttemptsTable.swift        # Attempts CRUD + DTO
    ├── TagsTable.swift            # Tags CRUD + DTOs
    └── SocialTables.swift         # Social CRUD + DTOs
```

**Pattern**: Separate DTOs from domain models:
```swift
// Domain model (SwiftData)
@Model
final class SCSession {
    var id: UUID
    var userId: UUID
    var startedAt: Date
    // Uses camelCase Swift conventions
}

// Supabase DTO (matches Postgres schema)
struct SessionDTO: Codable {
    let id: UUID
    let user_id: UUID
    let started_at: Date
    // Uses snake_case database conventions

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case started_at
    }
}

// Conversion extensions
extension SCSession {
    func toDTO() -> SessionDTO {
        SessionDTO(
            id: self.id,
            user_id: self.userId,
            started_at: self.startedAt
        )
    }
}

extension SessionDTO {
    func toModel() -> SCSession {
        SCSession(
            id: self.id,
            userId: self.user_id,
            startedAt: self.started_at
        )
    }
}
```

**Why DTOs?**
- Isolates database schema from domain models
- Allows different naming conventions (snake_case vs camelCase)
- Prevents tight coupling to backend

#### Integrations/OpenBeta
OpenBeta GraphQL API integration.

```
Integrations/OpenBeta/
├── OpenBetaClientActor.swift      # GraphQL client + rate limiting
├── OpenBetaQueries.swift          # Query definitions
└── OpenBetaModels.swift           # Response DTOs
```

**Pattern**: Rate-limited actor prevents API abuse:
```swift
actor OpenBetaClientActor {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval = 0.5  // 2 requests/sec max

    func executeQuery<T: Decodable>(_ query: String) async throws -> T {
        // Enforce rate limit
        if let last = lastRequestTime {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minimumInterval {
                try await Task.sleep(for: .seconds(minimumInterval - elapsed))
            }
        }

        lastRequestTime = Date()

        // Execute GraphQL query
        // ...
    }
}
```

---

## Concurrency Model

SwiftClimb uses **Swift 6 strict concurrency** with actor-based isolation.

### Actor Hierarchy

```
MainActor (UI Thread)
├── All SwiftUI Views (@MainActor)
└── Observes SwiftData changes via @Query

SyncActor
├── Sync state
├── Pull/push operations
└── Retry queue

SupabaseClientActor
├── Auth tokens
├── Request pipeline
└── Token refresh

OpenBetaClientActor
├── Rate limiting
└── GraphQL requests

HTTPClient Actor
├── Request execution
└── Retry logic
```

### Sendable Boundaries

Data crossing actor boundaries must be `Sendable`:

**Automatically Sendable**:
- All value types (structs, enums)
- Immutable classes (final class, all let properties)

**Requires Explicit Conformance**:
- Classes with mutable state (usually become actors)
- Protocol types (add `: Sendable` to protocol)

**Example**:
```swift
// ✅ Value type - automatically Sendable
struct Grade: Sendable {
    let original: String
    let scoreMin: Int
    let scoreMax: Int
}

// ✅ Final class with immutable dependencies - explicitly Sendable
final class SessionUseCase: SessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol  // Also Sendable

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }
}

// ✅ Actor - implicitly Sendable
actor SyncActor {
    private var isSyncing = false  // Mutable, but protected by actor
}
```

### Threading Rules

1. **UI updates happen on MainActor**:
   ```swift
   @MainActor
   func updateUI() {
       // Safe to update @State, @Observable properties
   }
   ```

2. **Network/sync operations happen in actors**:
   ```swift
   actor HTTPClient {
       func execute(...) async throws {
           // Isolated from UI thread
       }
   }
   ```

3. **SwiftData queries happen on ModelContext's thread**:
   ```swift
   // ModelContext is not Sendable, so queries must happen
   // on the same thread that owns the context
   ```

---

## Data Flow

### Write Path (User Action → Storage → Sync)

```
User Action
    │
    ▼
┌──────────────┐ @MainActor
│ SwiftUI View │
└──────┬───────┘
       │ await useCase.execute()
       ▼
┌─────────────────┐ Sendable
│    UseCase      │
└──────┬──────────┘
       │ await service.create()
       ▼
┌─────────────────┐ Actor
│    Service      │
└──────┬──────────┘
       │
       ├──► Insert into SwiftData (< 100ms)
       │
       └──► Enqueue in SyncActor (background)
                │
                ▼
           ┌────────────┐
           │ SyncActor  │
           └─────┬──────┘
                 │
                 ▼ (when online)
           ┌────────────┐
           │  Supabase  │
           └────────────┘
```

**Key Points**:
- UI calls UseCases directly (no ViewModel layer)
- UI updates immediately from SwiftData (< 100ms)
- Network sync happens asynchronously
- Failures don't block user

### Read Path (Storage → UI)

```
┌─────────────┐
│ SwiftData   │
└──────┬──────┘
       │ @Query
       ▼
┌─────────────┐ @MainActor
│ SwiftUI View│ observes and re-renders
└─────────────┘
```

**Key Points**:
- UI reads directly from SwiftData via @Query
- Never blocks on network
- Changes propagate automatically via SwiftData observation
- No intermediate ViewModel layer needed

### Sync Path (Background)

See [SYNC_STRATEGY.md](./SYNC_STRATEGY.md) for detailed sync documentation.

---

## Offline-First Pattern

### Core Principle
> "The local SwiftData store is the source of truth for the UI. Supabase is the system of record for multi-device sync."

### Implementation

1. **All writes go to SwiftData first**:
   ```swift
   func createSession(...) async throws -> SCSession {
       let session = SCSession(...)
       modelContext.insert(session)
       try modelContext.save()  // < 100ms

       // Background sync
       await syncActor.enqueue(.insertSession(session))

       return session
   }
   ```

2. **All reads come from SwiftData**:
   ```swift
   @Query(
       filter: #Predicate<SCSession> { $0.deletedAt == nil },
       sort: \.startedAt,
       order: .reverse
   )
   var sessions: [SCSession]
   ```

3. **Sync happens in background**:
   ```swift
   actor SyncActor {
       func pushPendingChanges() async throws {
           let pending = /* fetch where needsSync == true */

           for record in pending {
               try await supabaseClient.upsert(record)
               record.needsSync = false
           }
       }
   }
   ```

### Benefits
- Instant UI feedback
- Works offline
- Resilient to network failures
- Predictable user experience

---

## Dependency Injection

### Pattern: Environment-Based Injection

Dependencies are injected via SwiftUI Environment:

```swift
// ✅ GOOD: Dependencies injected via Environment
struct SessionView: View {
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase

    var body: some View {
        SCPrimaryButton(title: "Start Session") {
            await handleStartSession()
        }
    }

    private func handleStartSession() async {
        do {
            _ = try await startSessionUseCase.execute(
                userId: currentUserId,
                mentalReadiness: nil,
                physicalReadiness: nil
            )
        } catch {
            // Handle error
        }
    }
}

// ❌ BAD: Hidden dependencies (singletons, globals)
struct SessionView: View {
    var body: some View {
        SCPrimaryButton(title: "Start Session") {
            await SessionService.shared.startSession()  // Hidden dependency
        }
    }
}
```

### Setup Location: App Entry Point

```swift
// Define environment keys
extension EnvironmentValues {
    @Entry var startSessionUseCase: StartSessionUseCaseProtocol =
        DefaultStartSessionUseCase()
    @Entry var endSessionUseCase: EndSessionUseCaseProtocol =
        DefaultEndSessionUseCase()
}

@main
struct SwiftClimbApp: App {
    // 1. Create infrastructure
    let modelContainer: ModelContainer
    let syncActor = SyncActor()

    // 2. Create services
    let sessionService: SessionServiceProtocol
    let climbService: ClimbServiceProtocol

    // 3. Create use cases
    let startSessionUseCase: StartSessionUseCaseProtocol
    let endSessionUseCase: EndSessionUseCaseProtocol

    init() {
        modelContainer = try! SwiftDataContainer.shared.container
        let context = modelContainer.mainContext

        sessionService = SessionService(modelContext: context)
        // ...

        startSessionUseCase = StartSessionUseCase(
            sessionService: sessionService,
            syncActor: syncActor
        )

        endSessionUseCase = EndSessionUseCase(
            sessionService: sessionService,
            syncAtor: syncActor
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

### Benefits
- Testable (inject mocks via environment)
- Explicit dependencies in View
- Compile-time safety
- No hidden coupling
- Natural SwiftUI pattern

---

## Error Handling

### Error Types

Each layer defines appropriate errors:

**Domain Errors** (business logic violations):
```swift
enum SessionError: LocalizedError {
    case sessionAlreadyActive
    case sessionNotFound
    case invalidReadinessValue(Int)

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Cannot start a new session while one is active"
        case .sessionNotFound:
            return "Session not found"
        case .invalidReadinessValue(let value):
            return "Readiness must be 1-5, got \(value)"
        }
    }
}
```

**Infrastructure Errors** (system failures):
```swift
enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case unauthorized
    case serverError(Int)
    case decodingFailed(Error)
}
```

### Error Propagation

Errors propagate up the stack:
```
Service throws → UseCase handles or throws → View catches and displays
```

**Example**:
```swift
// Service: Throw specific error
actor SessionService {
    func createSession(...) async throws -> SCSession {
        if await getActiveSession(userId: userId) != nil {
            throw SessionError.sessionAlreadyActive
        }
        // ...
    }
}

// UseCase: Add context or pass through
final class StartSessionUseCase {
    func execute(...) async throws -> SCSession {
        try await sessionService.createSession(...)
        // Could add more context here if needed
    }
}

// View: Catch and display
struct SessionView: View {
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @State private var errorMessage: String?
    @State private var currentSession: SCSession?

    var body: some View {
        // ...
        if let error = errorMessage {
            Text(error)
                .foregroundStyle(.red)
        }
    }

    private func startSession() async {
        do {
            let session = try await startSessionUseCase.execute(...)
            self.currentSession = session
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
```

---

## Summary

SwiftClimb's architecture prioritizes:
1. **Offline-first UX** through SwiftData
2. **Concurrency safety** through actors
3. **Testability** through dependency injection
4. **Maintainability** through clear separation of concerns
5. **Type safety** through Swift 6 strict concurrency

For more specific topics, see:
- [SYNC_STRATEGY.md](./SYNC_STRATEGY.md) - Offline sync details
- [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) - UI component guide
- [../CONTRIBUTING.md](../CONTRIBUTING.md) - Coding standards

---

**Last Updated**: 2026-01-18
**Author**: Agent 4 (The Scribe)
