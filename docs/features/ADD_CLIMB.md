# Add Climb Feature

## Overview

The Add Climb feature provides a comprehensive form for capturing all relevant details about a climb during an active session. This is the primary data entry point for climbers, designed to capture everything in one interaction without requiring post-climb editing.

**Feature Status:** Implemented
**Related Files:**
- `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/AddClimbSheet.swift`
- `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/ThumbsToggle.swift`
- `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/AddClimbUseCase.swift`
- `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Enums.swift`

---

## Purpose

The Add Climb feature eliminates the need for separate "quick add" and "detailed edit" workflows by providing a single, intuitive form that captures:

1. Basic route information (name, grade)
2. Attempt tracking (count, outcome)
3. Performance metrics (mental, pacing, precision, technique)
4. Route characteristics (planned for future)
5. Personal notes

This design aligns with the offline-first architecture by ensuring all data is captured locally and queued for background sync.

---

## User Experience

### Form Structure

The Add Climb sheet is organized into five logical sections:

#### 1. Basic Info
Captures fundamental route details:
- **Route Name** (optional text field)
- **Grade Picker** (discipline-aware, scale-specific)

The grade picker adapts to the session's discipline:
- **Bouldering:** V Scale only
- **Sport/Trad/Top Rope:** YDS, French, or UIAA scales

#### 2. Attempts & Outcome
Tracks the climber's performance:
- **Attempts** (stepper: 1-99)
- **Outcome** (picker: Send or Project)
- **Tick Type** (auto-inferred, user-overridable)

**Key Behavior:** Tick type is automatically inferred from attempt count:
- 1 attempt → Flash
- 2+ attempts → Redpoint

Users can override this via a confirmation dialog if needed (e.g., changing Flash to Onsight).

#### 3. Performance
Captures subjective performance ratings using thumbs up/down toggles:
- **Mental** - Mental state during the climb
- **Pacing** - Energy management and rhythm
- **Precision** - Movement accuracy and technique execution
- **No Cut Loose** - (Bouldering only) Whether feet stayed on

Each metric uses a three-state toggle:
- **Thumbs Up** (green) - Felt good/strong
- **Neutral** (unselected) - Average or not notable
- **Thumbs Down** (red) - Struggled or needs work

#### 4. Characteristics (Coming Soon)
Placeholder section for future features:
- Wall Features (angle, texture)
- Holds & Moves (crimps, slopers, dynos)
- Skills Used (flexibility, endurance, power)

These sections display "Coming Soon" labels and are non-interactive.

#### 5. Notes
Free-form text field for personal observations, beta, conditions, or any other details.

---

## Technical Implementation

### Component Architecture

```
AddClimbSheet (SwiftUI View)
    │
    ├─► GradePicker (reusable component)
    ├─► ThumbsToggle (custom performance rating)
    └─► AddClimbData (data transfer object)
         │
         └─► AddClimbUseCase
              │
              ├─► ClimbService (creates climb entity)
              └─► AttemptService (creates attempt records)
```

### Data Flow

1. **User Input** → Form bindings (`@State`)
2. **Validation** → Grade parsing, attempt count validation
3. **Data Package** → `AddClimbData` DTO
4. **Use Case Execution** → `AddClimbUseCase.execute()`
5. **Local Persistence** → SwiftData via services
6. **Background Sync** → Queued by services (non-blocking)

### State Management

The `AddClimbSheet` manages its own state using SwiftUI's `@State`:

```swift
// Basic Info
@State private var climbName: String = ""
@State private var selectedGrade: String = "V5"
@State private var selectedScale: GradeScale = .v

// Attempts & Outcome
@State private var attemptCount: Int = 1
@State private var outcome: ClimbOutcome = .send
@State private var tickType: SendType = .flash

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

### Tick Type Auto-Inference

The form automatically infers tick type based on attempt count:

```swift
private var inferredTickType: SendType {
    attemptCount == 1 ? .flash : .redpoint
}
```

The inferred tick type is:
- Displayed in the footer text
- Applied automatically when attempts change
- Overridable via a confirmation dialog

**User Override Flow:**
1. User taps the tick type row
2. Confirmation dialog shows: "Auto-detected as Flash. Change?"
3. Options presented:
   - "Keep as Flash" (default)
   - "Change to Onsight"
   - "Change to Redpoint"
   - "Change to Pinkpoint"
   - "Change to Project"
   - "Cancel"
4. Selection updates `tickType` state

### Attempt Creation Logic

The `AddClimbUseCase` automatically creates attempt records based on form input:

```swift
private func createAttempts(
    userId: UUID,
    sessionId: UUID,
    climbId: UUID,
    attemptCount: Int,
    outcome: ClimbOutcome,
    tickType: SendType?
) async throws {
    // For each attempt (1...attemptCount)
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

        // Create attempt via service
        _ = try await attemptService.logAttempt(...)
    }
}
```

**Example Scenarios:**

| Attempt Count | Outcome | Result Attempts |
|---------------|---------|-----------------|
| 1 | Send | 1 send (Flash) |
| 3 | Send | 2 tries + 1 send (Redpoint) |
| 5 | Project | 5 tries |

---

## New Enums

### ClimbOutcome

Represents the final outcome of a climb session (for form UI):

```swift
enum ClimbOutcome: String, Codable, CaseIterable, Sendable {
    case send       // Successfully completed the climb
    case project    // Still working on it / didn't complete
}
```

**Properties:**
- `displayName` - "Send" or "Project"
- `description` - Human-readable explanation
- `systemImage` - SF Symbol for UI display

### PerformanceRating

Represents subjective performance on specific aspects:

```swift
enum PerformanceRating: String, Codable, Sendable {
    case positive   // Thumbs up - felt good/strong
    case negative   // Thumbs down - struggled
}
```

**Design Note:** There is no `.neutral` case because `nil` represents neutral/unselected state.

---

## ThumbsToggle Component

A custom three-state toggle for performance metrics.

### Interface

```swift
struct ThumbsToggle: View {
    let label: String
    @Binding var value: PerformanceRating?
}
```

### Behavior

- **Thumbs Up Button** (left side):
  - Taps toggle between `.positive` and `nil`
  - Shows filled icon when selected
  - Green color when active, gray when inactive

- **Label** (center):
  - Displays the metric name (e.g., "Mental", "Pacing")

- **Thumbs Down Button** (right side):
  - Taps toggle between `.negative` and `nil`
  - Shows filled icon when selected
  - Red color when active, gray when inactive

### Animation

All state changes use a smooth ease-in-out animation:

```swift
withAnimation(.easeInOut(duration: 0.15)) {
    value = value == .positive ? nil : .positive
}
```

### Layout

```
[👍]         Mental         [👎]
 ↑            ↑              ↑
 Green     Centered        Red
(if active)  Label    (if active)
```

---

## AddClimbData Transfer Object

A simple data container for passing form data to the use case:

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

**Design Rationale:**
- Keeps view logic separate from business logic
- Provides clear contract between UI and use case
- Makes testing easier (can create DTO without view state)
- Optional fields allow partial data entry

---

## Integration Points

### Session Integration

The Add Climb sheet is presented from `SessionView`:

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

### Dependency Injection

The use case is injected via SwiftUI Environment:

```swift
extension EnvironmentValues {
    @Entry var addClimbUseCase: AddClimbUseCaseProtocol = AddClimbUseCase(
        climbService: /* ... */,
        attemptService: /* ... */
    )
}
```

Views access it with:

```swift
@Environment(\.addClimbUseCase) private var addClimbUseCase
```

---

## Error Handling

### Validation Errors

- **Invalid Grade:** Thrown by `AddClimbUseCase` if grade parsing fails
- **Missing Session:** Service-level validation ensures session exists
- **Offline Errors:** Network failures don't block - sync happens in background

### User Feedback

All errors display via an alert dialog:

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

## Accessibility

### VoiceOver Support

All interactive elements have proper accessibility:
- Text fields announce their purpose
- Pickers announce current selection and available options
- Thumbs toggles announce state (positive/neutral/negative)

### Dynamic Type

All text respects system Dynamic Type settings via `SCTypography` tokens.

### Color Contrast

Performance rating colors (green/red) are paired with icons for color-blind accessibility.

---

## Future Enhancements

### Characteristics Section

Planned features for route tagging:

1. **Wall Features**
   - Angle (slab, vertical, overhang, roof)
   - Texture (smooth, textured, rough)
   - Height (short, medium, tall)

2. **Holds & Moves**
   - Hold types (crimps, slopers, jugs, pinches, pockets)
   - Move types (dyno, mantle, compression, heel hook, toe hook)

3. **Skills Used**
   - Technical skills (flexibility, balance, core tension)
   - Physical demands (power, endurance, finger strength)
   - Mental aspects (problem-solving, fear management)

### Performance Metrics Expansion

Future performance metrics could include:
- **Breathing** - Controlled vs. labored
- **Footwork** - Clean vs. sloppy
- **Commitment** - Confident vs. hesitant
- **Recovery** - Quick vs. slow between attempts

### Beta Sharing

Integration with social features to share/receive climb beta:
- Link beta to specific holds or moves
- Attach photos with markup
- Video analysis

---

## Testing Considerations

### Unit Tests

Key areas for testing:

1. **Tick Type Inference**
   - 1 attempt → Flash
   - 2+ attempts → Redpoint
   - User override persists

2. **Attempt Creation Logic**
   - Send outcome: last attempt is send, rest are tries
   - Project outcome: all attempts are tries
   - Attempt count accuracy

3. **Grade Parsing**
   - Valid grades accepted
   - Invalid grades rejected with error
   - All supported scales parse correctly

4. **Performance Rating Toggles**
   - Nil → Positive → Nil
   - Nil → Negative → Nil
   - State isolation (one rating doesn't affect another)

### Integration Tests

1. **End-to-End Flow**
   - Submit form → Climb created
   - Submit form → Attempts created
   - Submit form → Sync queued

2. **Offline Behavior**
   - Form works without network
   - Data persists locally
   - Sync happens when connected

### UI Tests

1. **Form Interaction**
   - All fields accessible
   - Validation feedback appears
   - Success dismisses sheet

2. **Tick Type Override**
   - Dialog presents correctly
   - Selection updates state
   - Cancel preserves inferred value

---

## Performance Considerations

### Form Efficiency

- All state is lightweight value types
- No expensive computations in `body`
- Grade picker lazy-loads only visible grades

### Attempt Creation

- Attempts created in sequence (not parallel) to maintain order
- Each attempt is a separate database operation (can be optimized if needed)
- No network blocking - all operations are local SwiftData

### Animation Performance

- Simple ease-in-out animations (< 200ms)
- No view recreation during toggles
- Minimal state changes per interaction

---

## Design Decisions

### Why Auto-Infer Tick Type?

**Rationale:** Most climbers follow the standard definitions:
- 1 attempt = Flash (first try with beta)
- 2+ attempts = Redpoint (worked then sent)

Auto-inference reduces cognitive load and taps required for 95% of cases.

**Override Mechanism:** Power users can still specify Onsight, Pinkpoint, or Project when needed.

### Why Three-State Toggles Instead of Sliders?

**Rationale:**
- Faster interaction (one tap vs. drag)
- Binary outcomes match climber mental models ("felt good" vs. "struggled")
- Neutral state (unselected) is explicit
- More accessible than sliders

### Why Create All Attempts Upfront?

**Rationale:**
- Simpler mental model (attempts are immutable once created)
- Matches climber workflow (log after completing all attempts)
- Enables future analytics on attempt patterns
- Consistent with offline-first (no half-synced state)

### Why Separate Outcome and Tick Type?

**Rationale:**
- Outcome answers "Did I complete it?"
- Tick Type answers "How did I complete it?"
- Separation allows for "Project" outcome without tick type
- Clearer form validation (tick type only required for sends)

---

## Known Limitations

1. **No Attempt Editing:** Once created, attempts cannot be modified. Users must delete the climb and re-add it.
2. **No Photo Attachment:** Currently no support for attaching images to climbs.
3. **Characteristics Stub:** Wall features, holds, and skills are placeholders.
4. **No Geo-Tagging:** Outdoor climb location must be selected separately (OpenBeta integration not yet in form).

---

## Summary

The Add Climb feature provides a comprehensive, single-interaction data capture experience that:
- Eliminates the need for post-climb editing
- Automatically infers common patterns (tick types)
- Provides intuitive performance tracking (thumbs toggles)
- Maintains offline-first architecture (local persistence, background sync)
- Prepares for future enhancements (characteristics, beta sharing)

This design balances power-user flexibility with quick, casual logging workflows.
