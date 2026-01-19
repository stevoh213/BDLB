# Contributing to SwiftClimb

Thank you for your interest in contributing to SwiftClimb. This document outlines coding standards, conventions, and best practices established during the initial scaffolding phase.

## Table of Contents
1. [Development Environment](#development-environment)
2. [Code Style](#code-style)
3. [Swift Concurrency](#swift-concurrency)
4. [SwiftData Patterns](#swiftdata-patterns)
5. [Design System Usage](#design-system-usage)
6. [File Organization](#file-organization)
7. [Testing](#testing)
8. [Pull Request Process](#pull-request-process)

---

## Development Environment

### Requirements
- Xcode 16.0+ (for Swift 6.2 support)
- macOS 15.0+
- iOS 18.0+ deployment target
- Swift 6 language mode
- Strict Concurrency Checking enabled

### Build Settings
Ensure your Xcode project has these settings:
- **Swift Language Version**: Swift 6
- **Strict Concurrency Checking**: Complete (treat warnings as errors)
- **Warnings as Errors**: Yes
- **iOS Deployment Target**: 18.0

---

## Code Style

### General Principles
- **Clarity over brevity**: Code is read more often than written
- **Type safety**: Leverage Swift's type system
- **Explicitness**: Avoid implicit behavior when it reduces readability
- **Consistency**: Follow established patterns in the codebase

### Naming Conventions

#### Variables and Constants
```swift
// ✅ GOOD: Descriptive, clear intent
let sessionStartTimestamp: Date
var isCurrentlyPerformingSync: Bool
let userMentalReadinessScore: Int?

// ❌ BAD: Abbreviated, unclear
let ts: Date
var syncing: Bool
let score: Int?
```

#### Functions
```swift
// ✅ GOOD: Action-oriented, parameter labels clarify intent
func fetchSessionsUpdatedSince(_ date: Date) async throws -> [Session]
func calculateGradeScore(for grade: String, using scale: GradeScale) -> Int?

// ❌ BAD: Unclear action, missing parameter labels
func getSess(d: Date) async throws -> [Session]
func gradeScore(grade: String, scale: GradeScale) -> Int?
```

#### Types
```swift
// ✅ GOOD: Singular noun for classes/structs, descriptive protocols
final class SessionUseCase
struct Grade
protocol SessionServiceProtocol

// ❌ BAD: Plural nouns, unclear protocol names
final class SessionUseCases
struct Grades
protocol SessionService  // Missing "Protocol" suffix
```

#### SwiftData Models
All SwiftData `@Model` classes use `SC` prefix to avoid naming conflicts:
```swift
@Model
final class SCSession { }

@Model
final class SCClimb { }

// Rationale: Prevents conflicts with other frameworks and clearly
// identifies models in type signatures
```

### Code Formatting

#### Line Length
- Maximum 100 characters per line
- Break long function signatures across multiple lines

```swift
// ✅ GOOD: Multi-line for readability
func createSession(
    userId: UUID,
    mentalReadiness: Int?,
    physicalReadiness: Int?
) async throws -> SCSession

// ❌ BAD: Too long, hard to read
func createSession(userId: UUID, mentalReadiness: Int?, physicalReadiness: Int?) async throws -> SCSession
```

#### Indentation
- Use 4 spaces (not tabs)
- Indent continuations by 4 spaces

#### Blank Lines
- One blank line between functions
- Two blank lines between type definitions
- Group related code with `// MARK:` comments

```swift
final class SessionService {
    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Interface

    func createSession(...) async throws -> SCSession {
        // Implementation
    }

    func endSession(...) async throws {
        // Implementation
    }
}
```

### Comments and Documentation

#### File Headers
Each file should begin with a brief purpose statement:
```swift
// SessionService.swift
// Session lifecycle management using SwiftData

import SwiftData
import Foundation
```

#### Public API Documentation
All public types, methods, and properties must have documentation comments:
```swift
/// Manages climbing session lifecycle with offline-first persistence.
///
/// `SessionService` handles creating, updating, and querying sessions
/// in SwiftData. All operations are synchronous to the local database
/// and marked with `needsSync` for background synchronization.
///
/// - Note: This service operates on SwiftData's ModelContext and must
///   be called from the appropriate context's execution context.
final class SessionService: SessionServiceProtocol {

    /// Creates a new climbing session.
    ///
    /// - Parameters:
    ///   - userId: The user creating the session.
    ///   - mentalReadiness: Self-assessed mental readiness (1-5), or nil.
    ///   - physicalReadiness: Self-assessed physical readiness (1-5), or nil.
    ///
    /// - Returns: The newly created session.
    ///
    /// - Throws: `PersistenceError` if the session cannot be saved.
    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession
}
```

#### Inline Comments
Use inline comments for:
- Complex algorithms
- Non-obvious decisions
- Workarounds for bugs
- TODOs and FIXMEs

```swift
// Use 5-minute safety window to account for clock skew between
// device and server when pulling updates
let safetyWindow: TimeInterval = 5 * 60

// TODO: Replace fatalError with proper error handling once
// Supabase client is implemented
fatalError("Not implemented")
```

---

## Swift Concurrency

### Actor Isolation

**Rule**: All mutable state must be properly isolated.

#### Actors
Use actors for managing shared mutable state:
```swift
/// ✅ GOOD: Actor protects mutable state
actor SyncActor {
    private var lastSyncAt: Date?
    private var isSyncing = false

    func pullUpdates() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        // ...
    }
}
```

#### @MainActor
All SwiftUI views must be `@MainActor` (automatically applied by default):
```swift
/// ✅ GOOD: View automatically isolated to main actor
struct SessionView: View {
    @State private var currentSession: SCSession?
    @State private var isLoading = false

    var body: some View {
        // UI updates happen on main actor
    }

    func startSession() async {
        // This runs on main actor automatically
    }
}
```

### Sendable Conformance

**Rule**: Types crossing actor boundaries must be `Sendable`.

#### Automatic Conformance
Value types and immutable classes are automatically Sendable:
```swift
// ✅ Automatically Sendable
struct Grade: Sendable {
    let original: String
    let scoreMin: Int
    let scoreMax: Int
}

enum Discipline: Sendable {
    case boulder, sport, trad, topRope
}
```

#### Explicit Conformance
Classes need explicit Sendable conformance:
```swift
// ✅ GOOD: Final class with immutable properties
final class SessionUseCase: SessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }
}
```

#### @unchecked Sendable
**AVOID** `@unchecked Sendable` unless absolutely necessary:
```swift
// ⚠️ ACCEPTABLE: Stub implementation during development
// TODO: Replace with proper actor or Sendable implementation
final class SessionService: SessionServiceProtocol, @unchecked Sendable {
    func createSession(...) async throws -> SCSession {
        fatalError("Not implemented")
    }
}

// When implementing, replace with:
// Option 1: Actor
actor SessionService: SessionServiceProtocol { }

// Option 2: Final class with Sendable dependencies
final class SessionService: SessionServiceProtocol, Sendable {
    private let modelContext: ModelContext  // Assuming Sendable
}
```

**Document all uses of `@unchecked Sendable` in TECHNICAL_DEBT.md**

### Async/Await

#### Prefer structured concurrency
```swift
// ✅ GOOD: Structured concurrency with proper error handling
func syncAllData() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await self.syncProfiles() }
        group.addTask { try await self.syncSessions() }
        group.addTask { try await self.syncClimbs() }

        try await group.waitForAll()
    }
}

// ❌ BAD: Unstructured Task.init
func syncAllData() {
    Task {
        try await self.syncProfiles()
    }
    Task {
        try await self.syncSessions()
    }
    // No coordination, error handling unclear
}
```

---

## SwiftData Patterns

### Model Definition

#### Required Attributes
All `@Model` classes must include:
```swift
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?  // Soft delete support
    var needsSync: Bool   // Sync coordination

    // ... other properties
}
```

#### Relationships
Always specify delete rules and inverses:
```swift
@Model
final class SCSession {
    // Cascade delete: When session is deleted, delete all climbs
    @Relationship(deleteRule: .cascade, inverse: \SCClimb.session)
    var climbs: [SCClimb]
}

@Model
final class SCClimb {
    // Inverse relationship
    var session: SCSession?
}
```

#### Initialization
Provide default values for all properties:
```swift
init(
    id: UUID = UUID(),
    userId: UUID,
    startedAt: Date = Date(),
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    deletedAt: Date? = nil,
    needsSync: Bool = true
) {
    self.id = id
    self.userId = userId
    self.startedAt = startedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
    self.needsSync = needsSync
}
```

### Querying

#### Use descriptors, not raw queries
```swift
// ✅ GOOD: Type-safe fetch descriptor
let descriptor = FetchDescriptor<SCSession>(
    predicate: #Predicate { session in
        session.userId == userId && session.deletedAt == nil
    },
    sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
)
let sessions = try modelContext.fetch(descriptor)

// ❌ BAD: String-based query (error-prone)
// Don't do this
```

---

## Design System Usage

### Always Use Design Tokens

Never hardcode values that exist in design tokens:

```swift
// ✅ GOOD: Use design tokens
VStack(spacing: SCSpacing.md) {
    Text("Title")
        .font(SCTypography.title)
        .foregroundStyle(SCColors.primary)
}
.padding(SCSpacing.lg)
.background(
    RoundedRectangle(cornerRadius: SCCornerRadius.card)
        .fill(.regularMaterial)
)

// ❌ BAD: Hardcoded values
VStack(spacing: 12) {
    Text("Title")
        .font(.system(size: 28))
        .foregroundStyle(.blue)
}
.padding(16)
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(.blue.opacity(0.1))
)
```

### Component Reuse

Use existing design system components:
```swift
// ✅ GOOD: Reuse SCPrimaryButton
SCPrimaryButton(title: "Start Session") {
    await startSession()
}

// ❌ BAD: Custom button that duplicates design system
Button("Start Session") {
    await startSession()
}
.buttonStyle(.borderedProminent)
.frame(minHeight: 44)
// ... duplicating component logic
```

### Accessibility

All custom components must:
- Support Dynamic Type
- Meet minimum 44x44pt tap targets
- Respect Reduce Transparency
- Provide VoiceOver labels

```swift
struct CustomComponent: View {
    var body: some View {
        Text("Content")
            .font(SCTypography.body)  // Dynamic Type
            .frame(minWidth: 44, minHeight: 44)  // Tap target
            .background(
                // Respect Reduce Transparency
                UIAccessibility.isReduceTransparencyEnabled
                    ? SCColors.cardBackground
                    : .regularMaterial
            )
            .accessibilityLabel("Descriptive label")
    }
}
```

---

## File Organization

### Module Structure

Place files in the appropriate module:

```
SwiftClimb/
├── App/                      # Only app entry point and root view
├── Core/                     # Shared infrastructure
│   ├── DesignSystem/         # UI tokens and components
│   ├── Networking/           # HTTP/GraphQL clients
│   ├── Persistence/          # SwiftData configuration
│   └── Sync/                 # Sync coordination
├── Domain/                   # Business logic
│   ├── Models/               # SwiftData models and value types
│   ├── Services/             # Protocol definitions
│   └── UseCases/             # Business operations
├── Features/                 # Feature modules
│   ├── Session/              # SessionView.swift
│   ├── Logbook/              # LogbookView.swift
│   └── ...
└── Integrations/             # External services
    ├── Supabase/
    └── OpenBeta/
```

### File Naming

- **Views**: `{Feature}View.swift` (e.g., `SessionView.swift`)
- **Models**: `{ModelName}.swift` (e.g., `Session.swift`)
- **Services**: `{Domain}Service.swift` (e.g., `SessionService.swift`)
- **UseCases**: `{Action}{Domain}UseCase.swift` (e.g., `StartSessionUseCase.swift`)
- **Components**: `SC{ComponentName}.swift` (e.g., `SCPrimaryButton.swift`)

### One Type Per File

Each file should contain one primary type:
```swift
// ✅ GOOD: One model per file
// Session.swift
@Model
final class SCSession { }

// ✅ ACCEPTABLE: Related types together
// Grade.swift
struct Grade { }
enum GradeScale { }

// ❌ BAD: Unrelated types
// Models.swift
@Model final class SCSession { }
@Model final class SCClimb { }
@Model final class SCAttempt { }
```

---

## Testing

### Test Organization

Mirror the source structure in tests:
```
SwiftClimbTests/
├── Domain/
│   ├── Models/
│   ├── Services/
│   └── UseCases/
└── Core/
    └── Sync/
```

### Naming Convention

```swift
// Test class: {TypeUnderTest}Tests
final class SessionServiceTests: XCTestCase { }

// Test method: test_{method}_{scenario}_{expectedResult}
func test_createSession_withValidData_createsSession() async throws {
    // Arrange
    let service = SessionService(modelContext: testContext)

    // Act
    let session = try await service.createSession(
        userId: testUserId,
        mentalReadiness: 4,
        physicalReadiness: 5
    )

    // Assert
    XCTAssertEqual(session.userId, testUserId)
    XCTAssertEqual(session.mentalReadiness, 4)
    XCTAssertTrue(session.needsSync)
}
```

### What to Test

#### Unit Tests
- Business logic in UseCases
- Grade parsing and conversion
- Conflict resolution algorithms
- DTO ↔ Model conversions

#### Integration Tests
- SwiftData CRUD operations
- Cascade delete behavior
- Sync pull/push cycles
- Authentication flow

#### UI Tests
- Critical user flows (start session, log attempt, end session)
- Navigation between tabs
- Accessibility with VoiceOver

---

## Pull Request Process

### Before Submitting

1. **Build succeeds** with zero warnings
2. **All tests pass** (when test suite exists)
3. **Code follows style guide**
4. **New code has documentation comments**
5. **Technical debt documented** (if using `@unchecked Sendable` or TODOs)

### PR Template

```markdown
## Summary
Brief description of what this PR accomplishes.

## Changes
- List of key changes
- Reference issue numbers (#123)

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Screenshots (if UI changes)
[Screenshots here]

## Technical Debt
- Document any `@unchecked Sendable` uses
- List any TODOs introduced

## Checklist
- [ ] Code builds without warnings
- [ ] Tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)
```

### Review Focus Areas

Reviewers should check:
1. **Concurrency**: Proper actor isolation, no data races
2. **SwiftData**: Correct relationships and delete rules
3. **Design System**: Using tokens, not hardcoded values
4. **Error Handling**: Appropriate error types and recovery
5. **Accessibility**: VoiceOver labels, Dynamic Type support
6. **Performance**: No blocking operations on main thread

---

## Questions?

If you're unsure about any convention or pattern:
1. Check existing code for examples
2. Review architecture decision records in `SPECS/ADR/`
3. Ask in pull request comments
4. Refer to [ARCHITECTURE.md](./Documentation/ARCHITECTURE.md) for system design

---

**Thank you for contributing to SwiftClimb!**
