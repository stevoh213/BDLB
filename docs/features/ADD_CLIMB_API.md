# Add Climb API Reference

## Overview

This document provides technical API documentation for the Add Climb feature, including types, protocols, and implementation details.

---

## Table of Contents

1. [Types](#types)
2. [Components](#components)
3. [Use Cases](#use-cases)
4. [Services](#services)
5. [Data Models](#data-models)

---

## Types

### AddClimbData

Data transfer object for passing form data from UI to use case.

```swift
struct AddClimbData {
    let name: String?
    let gradeString: String
    let gradeScale: GradeScale
    let attemptCount: Int
    let outcome: ClimbOutcome
    let tickType: SendType?
    let notes: String?
    let mentalRating: PerformanceRating?
    let pacingRating: PerformanceRating?
    let precisionRating: PerformanceRating?
    let noCutLooseRating: PerformanceRating?
}
```

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | `String?` | No | Route or problem name (nil = unnamed) |
| `gradeString` | `String` | Yes | Raw grade string (e.g., "V5", "5.12a") |
| `gradeScale` | `GradeScale` | Yes | Grade scale enum (.v, .yds, .french, .uiaa) |
| `attemptCount` | `Int` | Yes | Number of attempts (1-99) |
| `outcome` | `ClimbOutcome` | Yes | Send or Project |
| `tickType` | `SendType?` | No | Type of send (nil for projects) |
| `notes` | `String?` | No | Personal notes about the climb |
| `mentalRating` | `PerformanceRating?` | No | Mental performance (positive/negative/nil) |
| `pacingRating` | `PerformanceRating?` | No | Pacing performance |
| `precisionRating` | `PerformanceRating?` | No | Precision performance |
| `noCutLooseRating` | `PerformanceRating?` | No | No cut loose performance (boulder only) |

---

### ClimbOutcome

Enum representing the final outcome of a climb session.

```swift
enum ClimbOutcome: String, Codable, CaseIterable, Sendable {
    case send       // Successfully completed the climb
    case project    // Still working on it / didn't complete
}
```

**Properties:**

```swift
var displayName: String {
    switch self {
    case .send: return "Send"
    case .project: return "Project"
    }
}

var description: String {
    switch self {
    case .send: return "You completed the climb"
    case .project: return "Still working on it"
    }
}

var systemImage: String {
    switch self {
    case .send: return "checkmark.circle.fill"
    case .project: return "arrow.clockwise"
    }
}
```

**Conformances:**
- `String` (raw value)
- `Codable`
- `CaseIterable`
- `Sendable`

---

### PerformanceRating

Enum representing subjective performance on specific aspects.

```swift
enum PerformanceRating: String, Codable, Sendable {
    case positive   // Thumbs up - felt good/strong
    case negative   // Thumbs down - struggled
}
```

**Properties:**

```swift
var displayName: String {
    switch self {
    case .positive: return "Good"
    case .negative: return "Struggled"
    }
}
```

**Conformances:**
- `String` (raw value)
- `Codable`
- `Sendable`

**Design Note:** Neutral state is represented by `nil`, not a `.neutral` case.

---

## Components

### AddClimbSheet

SwiftUI sheet view for adding a new climb with all details.

```swift
struct AddClimbSheet: View {
    let session: SCSession
    let onAdd: (AddClimbData) async throws -> Void
}
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `session` | `SCSession` | The active climbing session |
| `onAdd` | `(AddClimbData) async throws -> Void` | Callback when user saves the form |

**State Management:**

The sheet manages its own state using `@State` properties:

```swift
// Basic Info
@State private var climbName: String = ""
@State private var selectedGrade: String = "V5"
@State private var selectedScale: GradeScale = .v

// Attempts & Outcome
@State private var attemptCount: Int = 1
@State private var outcome: ClimbOutcome = .send
@State private var tickType: SendType = .flash
@State private var showTickTypeOverride = false

// Performance
@State private var mentalRating: PerformanceRating? = nil
@State private var pacingRating: PerformanceRating? = nil
@State private var precisionRating: PerformanceRating? = nil
@State private var noCutLooseRating: PerformanceRating? = nil

// Notes
@State private var notes: String = ""

// UI State
@State private var isLoading = false
@State private var errorMessage: String?
```

**Computed Properties:**

```swift
private var inferredTickType: SendType {
    attemptCount == 1 ? .flash : .redpoint
}
```

**Methods:**

```swift
private func setupInitialValues()
private func saveClimb() async
```

**Usage Example:**

```swift
.sheet(isPresented: $showAddClimb) {
    AddClimbSheet(
        session: session,
        onAdd: { data in
            try await addClimbUseCase.execute(
                userId: session.userId,
                sessionId: session.id,
                discipline: session.discipline,
                data: data,
                isOutdoor: false,
                openBetaClimbId: nil,
                openBetaAreaId: nil,
                locationDisplay: nil
            )
        }
    )
}
```

---

### ThumbsToggle

Three-state toggle for performance metrics with thumbs up/down UI.

```swift
struct ThumbsToggle: View {
    let label: String
    @Binding var value: PerformanceRating?
}
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | Display label for the metric (e.g., "Mental") |
| `value` | `Binding<PerformanceRating?>` | Current rating (nil = neutral) |

**Behavior:**

- Tapping thumbs up toggles between `.positive` and `nil`
- Tapping thumbs down toggles between `.negative` and `nil`
- Animations use `.easeInOut(duration: 0.15)`

**Styling:**

- Active thumbs up: Green filled icon
- Active thumbs down: Red filled icon
- Inactive: Gray outline icon

**Usage Example:**

```swift
Section("Performance") {
    ThumbsToggle(label: "Mental", value: $mentalRating)
    ThumbsToggle(label: "Pacing", value: $pacingRating)
    ThumbsToggle(label: "Precision", value: $precisionRating)
}
```

---

## Use Cases

### AddClimbUseCaseProtocol

Protocol defining the add climb operation.

```swift
protocol AddClimbUseCaseProtocol: Sendable {
    /// Executes the add climb use case with full climb data
    /// - Returns: The ID of the newly created climb
    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        data: AddClimbData,
        isOutdoor: Bool,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> UUID
}
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userId` | `UUID` | Yes | ID of the user adding the climb |
| `sessionId` | `UUID` | Yes | ID of the active session |
| `discipline` | `Discipline` | Yes | Climbing discipline |
| `data` | `AddClimbData` | Yes | Form data from UI |
| `isOutdoor` | `Bool` | Yes | Indoor (false) or outdoor (true) |
| `openBetaClimbId` | `String?` | No | OpenBeta climb reference |
| `openBetaAreaId` | `String?` | No | OpenBeta area reference |
| `locationDisplay` | `String?` | No | Human-readable location |

**Returns:**
- `UUID` - ID of the newly created climb

**Throws:**
- `ClimbError.invalidGrade(_)` - If grade parsing fails
- `ServiceError` - If service-level validation fails

---

### AddClimbUseCase

Implementation of `AddClimbUseCaseProtocol`.

```swift
final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let attemptService: AttemptServiceProtocol

    init(
        climbService: ClimbServiceProtocol,
        attemptService: AttemptServiceProtocol
    )
}
```

**Dependencies:**

- `climbService` - Creates and persists climb entity
- `attemptService` - Creates and persists attempt entities

**Implementation Flow:**

1. Parse grade from string using `Grade.parse()`
2. Create climb via `climbService.createClimb()`
3. Create attempts via `createAttempts()`
4. Return climb ID

**Attempt Creation Logic:**

```swift
private func createAttempts(
    userId: UUID,
    sessionId: UUID,
    climbId: UUID,
    attemptCount: Int,
    outcome: ClimbOutcome,
    tickType: SendType?
) async throws {
    for attemptNumber in 1...attemptCount {
        let isLastAttempt = attemptNumber == attemptCount

        if outcome == .send && isLastAttempt {
            // Last attempt is a send
            attemptOutcome = .send
            attemptSendType = tickType
        } else {
            // All other attempts are tries
            attemptOutcome = .try
            attemptSendType = nil
        }

        _ = try await attemptService.logAttempt(
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            outcome: attemptOutcome,
            sendType: attemptSendType
        )
    }
}
```

**Attempt Creation Examples:**

| Attempt Count | Outcome | Result |
|---------------|---------|--------|
| 1 | Send | 1 send (with tick type) |
| 3 | Send | 2 tries + 1 send (with tick type) |
| 5 | Project | 5 tries (no tick type) |

---

## Services

### ClimbServiceProtocol

Protocol for climb persistence operations.

```swift
protocol ClimbServiceProtocol: Sendable {
    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?,
        notes: String?
    ) async throws -> UUID
}
```

**Responsibilities:**
- Validates climb data
- Persists climb to SwiftData
- Marks climb for background sync
- Returns climb ID

---

### AttemptServiceProtocol

Protocol for attempt persistence operations.

```swift
protocol AttemptServiceProtocol: Sendable {
    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> UUID
}
```

**Responsibilities:**
- Auto-calculates attempt number (next in sequence)
- Validates attempt data
- Persists attempt to SwiftData
- Marks attempt for background sync
- Returns attempt ID

---

## Data Models

### SCClimb

SwiftData model representing a climb.

```swift
@Model
final class SCClimb {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var sessionId: UUID
    var discipline: Discipline
    var isOutdoor: Bool
    var name: String?
    var gradeOriginal: String?
    var gradeScale: GradeScale?
    var gradeScoreMin: Int?
    var gradeScoreMax: Int?
    var openBetaClimbId: String?
    var openBetaAreaId: String?
    var locationDisplay: String?
    var belayPartnerUserId: UUID?
    var belayPartnerName: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCSession.climbs)
    var session: SCSession?

    @Relationship(deleteRule: .cascade)
    var attempts: [SCAttempt]

    @Relationship(deleteRule: .cascade)
    var techniqueImpacts: [SCTechniqueImpact]

    @Relationship(deleteRule: .cascade)
    var skillImpacts: [SCSkillImpact]

    @Relationship(deleteRule: .cascade)
    var wallStyleImpacts: [SCWallStyleImpact]

    var needsSync: Bool
}
```

**Key Properties:**

- **id** - Unique identifier (UUID)
- **gradeOriginal** - Raw grade string as entered by user
- **gradeScore(Min|Max)** - Numeric score range for comparisons
- **isOutdoor** - Gym (false) vs. outdoor (true)
- **openBetaClimbId** - Reference to OpenBeta database
- **needsSync** - Marks record for background sync
- **deletedAt** - Soft delete timestamp

**Relationships:**
- Many-to-one with `SCSession`
- One-to-many with `SCAttempt` (cascade delete)
- One-to-many with tag impact junction tables (cascade delete)

**Computed Properties:**

```swift
extension SCClimb {
    var hasSend: Bool {
        return attempts.contains { $0.outcome == .send }
    }

    var attemptCount: Int {
        return attempts.count
    }
}
```

---

### SCAttempt

SwiftData model representing an attempt on a climb.

```swift
@Model
final class SCAttempt {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var sessionId: UUID
    var climbId: UUID
    var attemptNumber: Int  // >= 1
    var outcome: AttemptOutcome
    var sendType: SendType?
    var occurredAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCClimb.attempts)
    var climb: SCClimb?

    var needsSync: Bool
}
```

**Key Properties:**

- **id** - Unique identifier (UUID)
- **attemptNumber** - Sequential number (1, 2, 3, ...)
- **outcome** - Send or Try
- **sendType** - Flash, Onsight, Redpoint, etc. (only for sends)
- **occurredAt** - Timestamp of attempt (optional)
- **needsSync** - Marks record for background sync
- **deletedAt** - Soft delete timestamp

**Relationships:**
- Many-to-one with `SCClimb`

**Computed Properties:**

```swift
extension SCAttempt {
    var isSend: Bool {
        return outcome == .send
    }
}
```

---

## Environment Injection

### Environment Key

```swift
extension EnvironmentValues {
    @Entry var addClimbUseCase: AddClimbUseCaseProtocol = AddClimbUseCase(
        climbService: /* injected */,
        attemptService: /* injected */
    )
}
```

### Accessing in Views

```swift
@Environment(\.addClimbUseCase) private var addClimbUseCase
```

### Providing at App Root

```swift
@main
struct SwiftClimbApp: App {
    let addClimbUseCase: AddClimbUseCaseProtocol

    init() {
        // Create services
        let climbService = ClimbService(...)
        let attemptService = AttemptService(...)

        // Create use case
        addClimbUseCase = AddClimbUseCase(
            climbService: climbService,
            attemptService: attemptService
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.addClimbUseCase, addClimbUseCase)
        }
    }
}
```

---

## Error Handling

### ClimbError

```swift
enum ClimbError: Error, LocalizedError {
    case invalidGrade(String)

    var errorDescription: String? {
        switch self {
        case .invalidGrade(let gradeString):
            return "Invalid grade: \(gradeString)"
        }
    }
}
```

### UI Error Display

Errors are displayed via an alert in `AddClimbSheet`:

```swift
.alert("Error", isPresented: .init(
    get: { errorMessage != nil },
    set: { if !$0 { errorMessage = nil } }
)) {
    Button("OK") { errorMessage = nil }
} message: {
    Text(errorMessage ?? "")
}
```

---

## Threading & Concurrency

### Actor Isolation

- **AddClimbSheet** - `@MainActor` (SwiftUI view)
- **AddClimbUseCase** - `Sendable` (can cross actor boundaries)
- **ClimbService** - Actor (thread-safe SwiftData access)
- **AttemptService** - Actor (thread-safe SwiftData access)

### Async Operations

All operations are async and properly awaited:

```swift
private func saveClimb() async {
    isLoading = true
    defer { isLoading = false }

    do {
        let data = AddClimbData(...)
        try await onAdd(data)  // Async call
        dismiss()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Task Lifecycle

The sheet uses `.task` modifier for initialization:

```swift
.onAppear {
    setupInitialValues()  // Synchronous setup
}
```

---

## Testing Strategies

### Unit Tests

Test use case logic independently:

```swift
@Test func createsClimbWithCorrectData() async throws {
    let mockClimbService = MockClimbService()
    let mockAttemptService = MockAttemptService()
    let useCase = AddClimbUseCase(
        climbService: mockClimbService,
        attemptService: mockAttemptService
    )

    let data = AddClimbData(
        name: "Test Route",
        gradeString: "V5",
        gradeScale: .v,
        attemptCount: 3,
        outcome: .send,
        tickType: .redpoint,
        notes: nil,
        mentalRating: .positive,
        pacingRating: nil,
        precisionRating: .negative,
        noCutLooseRating: nil
    )

    let climbId = try await useCase.execute(
        userId: UUID(),
        sessionId: UUID(),
        discipline: .bouldering,
        data: data,
        isOutdoor: false,
        openBetaClimbId: nil,
        openBetaAreaId: nil,
        locationDisplay: nil
    )

    #expect(climbId != nil)
    #expect(mockAttemptService.attempts.count == 3)
    #expect(mockAttemptService.attempts.last?.outcome == .send)
}
```

### Integration Tests

Test the full stack with real SwiftData:

```swift
@Test func addClimbIntegration() async throws {
    let container = try ModelContainer(
        for: SCSession.self, SCClimb.self, SCAttempt.self
    )
    let modelContext = ModelContext(container)

    let climbService = ClimbService(modelContext: modelContext)
    let attemptService = AttemptService(modelContext: modelContext)
    let useCase = AddClimbUseCase(
        climbService: climbService,
        attemptService: attemptService
    )

    // Create session
    let session = SCSession(userId: UUID(), discipline: .bouldering)
    modelContext.insert(session)
    try modelContext.save()

    // Add climb
    let data = AddClimbData(...)
    let climbId = try await useCase.execute(
        userId: session.userId,
        sessionId: session.id,
        discipline: session.discipline,
        data: data,
        isOutdoor: false,
        openBetaClimbId: nil,
        openBetaAreaId: nil,
        locationDisplay: nil
    )

    // Verify
    let predicate = #Predicate<SCClimb> { $0.id == climbId }
    let climbs = try modelContext.fetch(FetchDescriptor(predicate: predicate))
    #expect(climbs.count == 1)
    #expect(climbs.first?.attempts.count == data.attemptCount)
}
```

### UI Tests

Test user interactions:

```swift
@Test func tickTypeOverrideFlow() async throws {
    // 1. Launch app with active session
    // 2. Tap "Add Climb"
    // 3. Set attempt count to 1 (auto-infers Flash)
    // 4. Tap tick type row
    // 5. Verify dialog shows "Auto-detected as Flash"
    // 6. Tap "Change to Onsight"
    // 7. Verify tick type updates to Onsight
    // 8. Tap Save
    // 9. Verify climb created with onsight tick type
}
```

---

## Performance Considerations

### Form Rendering

- Grade picker uses lazy loading for large grade lists
- ThumbsToggle animations are lightweight (< 200ms)
- No expensive computations in `body`

### Data Persistence

- SwiftData writes are local and fast (< 100ms)
- Attempts are created sequentially to maintain order
- Background sync is non-blocking

### Memory Usage

- All state is lightweight value types or optionals
- No large data structures in form state
- Dismissal clears all form state

---

## Summary

The Add Climb API provides:

- Type-safe data transfer objects
- Clear separation between UI and business logic
- Actor-based concurrency for thread safety
- Offline-first persistence with background sync
- Comprehensive error handling
- Testable components at all layers

This architecture supports fast, reliable climb logging with rich detail capture.
