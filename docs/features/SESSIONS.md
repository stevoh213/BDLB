# Sessions Feature

**Status**: Implemented
**Version**: 1.0
**Last Updated**: 2026-01-20

---

## Overview

The Sessions feature provides the core functionality for tracking climbing workouts in SwiftClimb. A session represents a single climbing session from start to finish, capturing readiness metrics before starting, all climbs and attempts during the session, and exertion feedback after completion.

**Key Capabilities:**
- Start/end session lifecycle management
- Optional mental and physical readiness tracking (1-5 scale)
- Real-time session duration display
- Climb and attempt tracking within session context
- Post-session metrics: RPE (1-10) and pump level (1-5)
- Session notes and privacy settings
- Offline-first with automatic background sync

---

## User Flow

### 1. Starting a Session

**Entry Point**: Session tab (empty state)

**Flow**:
1. User taps "Start Session" button
2. Start Session sheet presents two options:
   - **Quick Start**: Skip readiness tracking, start immediately
   - **Track Readiness**: Capture mental and physical readiness (1-5)
3. User configures optional readiness metrics with sliders
4. User taps "Start Session" to confirm
5. Session created locally in SwiftData (< 100ms)
6. UI transitions to active session view
7. Background sync queues session to Supabase

**States**:
- Empty state: No active session
- Loading: Creating session
- Active: Session running

### 2. Active Session Experience

**Display**:
- Session header with start time and elapsed duration
- Quick stats pills: Mental/Physical readiness, climb count, attempt count
- List of climbs with attempt indicators
- "Add Climb" button (sticky bottom button)
- "End" toolbar button (top-right)

**Interactions**:
- Real-time duration updates (updates every minute)
- Add climbs via bottom button
- View climb details (name, grade, attempts)
- End session via toolbar

**Duration Display**:
- Under 60 minutes: "X min"
- Over 60 minutes: "Xh Ym"
- Uses monospaced digits for consistent layout

### 3. Ending a Session

**Entry Point**: "End" button in toolbar

**Flow**:
1. User taps "End" button
2. End Session sheet displays:
   - Session summary (duration, climbs, attempts)
   - RPE picker (1-10 scale with visual indicator)
   - Pump level picker (1-5 with icons: drop, flame, bolt)
   - Notes text field (multiline)
3. User selects metrics and adds optional notes
4. User taps "Save" to confirm
5. Session marked as ended with `endedAt` timestamp
6. Session moves to Logbook history
7. Background sync updates Supabase

**Required**:
- None (all metrics optional)

**Optional**:
- RPE (Rate of Perceived Exertion): 1 (easy) to 10 (hard)
- Pump level: 1 (none) to 5 (maxed)
- Notes: Free-form text

### 4. Viewing Session History

**Entry Point**: Logbook tab

**Display**:
- Chronological list of completed sessions (newest first)
- Session card shows: date, duration, climb count, send count
- Tap row to view full session details

**Session Detail View**:
- Header: Date, duration, climbs, attempts
- Metrics grid: Mental/physical readiness, RPE, pump level
- Climbs list: All climbs with grades and attempts
- Notes section (if provided)
- Delete action in toolbar menu

**Actions**:
- Navigate to session detail
- Delete session (soft delete with confirmation)

---

## Architecture

### Data Model

#### SCSession (SwiftData @Model)

```swift
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var startedAt: Date
    var endedAt: Date?              // nil = active session

    // Pre-session metrics (optional)
    var mentalReadiness: Int?       // 1-5
    var physicalReadiness: Int?     // 1-5

    // Post-session metrics (optional)
    var rpe: Int?                   // 1-10 (Rate of Perceived Exertion)
    var pumpLevel: Int?             // 1-5
    var notes: String?

    // Privacy
    var isPrivate: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?            // Soft delete

    // Relationships
    @Relationship(deleteRule: .cascade)
    var climbs: [SCClimb]

    // Sync
    var needsSync: Bool
}
```

**Computed Properties**:
- `isActive: Bool` - True when `endedAt == nil`
- `duration: TimeInterval?` - Calculated from start to end time
- `attemptCount: Int` - Sum of all attempts across climbs

**Validation**:
- Mental/physical readiness: 1-5 or nil
- RPE: 1-10 or nil
- Pump level: 1-5 or nil
- `endedAt` must be after `startedAt`

**Relationships**:
- One-to-many with `SCClimb` (cascade delete)
- Soft delete propagates through sync

### Service Layer

#### SessionService (Actor)

Thread-safe actor providing session lifecycle operations.

```swift
actor SessionService: SessionServiceProtocol {
    private let modelContainer: ModelContainer

    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID

    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws

    func getActiveSessionId(userId: UUID) async throws -> UUID?

    func getSessionHistory(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [UUID]

    func deleteSession(sessionId: UUID) async throws

    func updateSessionNotes(sessionId: UUID, notes: String?) async throws
}
```

**Key Behaviors**:
- All operations use `@MainActor` for ModelContext access
- Returns UUIDs instead of entities for separation of concerns
- Validates all input ranges before persistence
- Prevents creating duplicate active sessions
- Marks all changes with `needsSync = true`
- Uses `FetchDescriptor` with `#Predicate` for queries

**Error Handling**:
```swift
enum SessionError: LocalizedError {
    case sessionAlreadyActive      // Cannot start second session
    case sessionNotFound            // ID not found
    case sessionNotActive           // Already ended
    case invalidReadinessValue(Int) // Out of 1-5 range
    case invalidRPEValue(Int)       // Out of 1-10 range
    case invalidPumpLevelValue(Int) // Out of 1-5 range
    case endTimeBeforeStartTime     // Invalid time range
}
```

### Use Cases

All use cases are thin wrappers around `SessionService`, following the Sendable protocol pattern for concurrency safety.

#### StartSessionUseCase

```swift
protocol StartSessionUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID
}
```

**Flow**:
1. Calls `sessionService.createSession(...)` with validation
2. Service persists to SwiftData with `needsSync = true`
3. Returns session ID
4. SyncActor picks up change and syncs to Supabase in background

#### EndSessionUseCase

```swift
protocol EndSessionUseCaseProtocol: Sendable {
    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws
}
```

**Flow**:
1. Calls `sessionService.endSession(...)` with metrics
2. Service updates session with `endedAt`, marks `needsSync = true`
3. SyncActor syncs update to Supabase in background

#### GetActiveSessionUseCase

```swift
protocol GetActiveSessionUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws -> UUID?
}
```

Returns the active session ID for a user, or nil if none exists.

#### ListSessionsUseCase

```swift
protocol ListSessionsUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [UUID]
}
```

Returns paginated session history (completed sessions only, newest first).

#### DeleteSessionUseCase

```swift
protocol DeleteSessionUseCaseProtocol: Sendable {
    func execute(sessionId: UUID) async throws
}
```

Soft deletes a session by setting `deletedAt` timestamp.

### UI Components

#### SessionView (Main View)

Entry point for session feature. Uses SwiftUI `@Query` for reactive updates.

```swift
@MainActor
struct SessionView: View {
    @Query(
        filter: #Predicate<SCSession> {
            $0.endedAt == nil && $0.deletedAt == nil
        }
    )
    private var activeSessions: [SCSession]

    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase

    @State private var showStartSheet = false
    @State private var showEndSheet = false
}
```

**States**:
- No active session: Shows `EmptySessionState`
- Active session: Shows `ActiveSessionContent`
- Loading: Disables buttons, shows spinner

**Sheets**:
- Start session: `StartSessionSheet`
- End session: `EndSessionSheet`

#### EmptySessionState

Displayed when no session is active.

**Elements**:
- Large climbing icon (SF Symbol: `figure.climbing`)
- "Ready to Climb?" heading
- Descriptive text
- "Start Session" primary button

#### StartSessionSheet

Half-sheet modal for starting a session.

**Modes**:
1. **Quick Start** (default): Skip readiness, start immediately
2. **Track Readiness**: Show sliders for mental/physical readiness

**Toggle**: "Track my readiness" button switches to readiness mode

**Readiness Sliders**:
- Mental readiness (1-5): Brain icon, "Low" to "High" labels
- Physical readiness (1-5): Figure icon, "Low" to "High" labels
- Real-time value display: "X/5"

**Actions**:
- "Cancel" (dismiss)
- "Start Session" (primary button, shows loading state)

#### ActiveSessionContent

Main view for active session.

**Layout**:
- Session header (glass card)
  - Start time
  - Elapsed duration (updates every minute)
- Quick stats (horizontal scroll)
  - Mental/physical readiness pills (if provided)
  - Climb count pill
  - Attempt count pill
- Climbs list (or empty state)
  - Each climb shows: name, grade, attempt pills
- Add climb button (sticky bottom)

**Components**:
- `MetricStatPill`: Icon + value + label in pill format
- `ClimbRow`: Climb card with attempts
- `AttemptPill`: Visual attempt indicator (checkmark/X)

#### EndSessionSheet

Full-height modal for ending session.

**Sections**:
1. **Session Summary** (glass card)
   - Duration, climb count, attempt count
2. **RPE Picker**
   - Horizontal 1-10 number buttons
   - Selected state highlighted
   - "Easy" to "Hard" labels
3. **Pump Level Picker**
   - Five buttons with icons and labels
   - Icons: drop, drop.fill, flame, flame.fill, bolt.fill
   - Labels: None, Light, Moderate, Heavy, Maxed
4. **Notes**
   - Multiline text field
   - Placeholder: "How did it go?"

**Actions**:
- "Cancel" (dismiss)
- "Save" (end session and dismiss)

#### SessionDetailView

Full-screen detail view for completed sessions.

**Layout**:
- Header card: Date, duration, climbs, attempts
- Metrics grid (2 columns): Mental/physical, RPE, pump level
- Climbs section: All climbs with attempts
- Notes section (if provided)

**Toolbar**:
- Menu button (ellipsis)
  - Delete session action (destructive role)

**Delete Confirmation**:
- Confirmation dialog
- Warning: "This will delete the session and all its climbs. This action cannot be undone."

---

## Database

### Supabase Table Schema

**Table**: `sessions`

```sql
CREATE TABLE public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    mental_readiness SMALLINT CHECK (mental_readiness >= 1 AND mental_readiness <= 5),
    physical_readiness SMALLINT CHECK (physical_readiness >= 1 AND physical_readiness <= 5),
    rpe SMALLINT CHECK (rpe >= 1 AND rpe <= 10),
    pump_level SMALLINT CHECK (pump_level >= 1 AND pump_level <= 5),
    notes TEXT,
    is_private BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT valid_end_time CHECK (ended_at IS NULL OR ended_at > started_at)
);
```

### Indexes

```sql
-- User sessions lookup
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- Chronological ordering
CREATE INDEX idx_sessions_started_at ON sessions(started_at DESC);

-- Sync queries
CREATE INDEX idx_sessions_updated_at ON sessions(updated_at);

-- Active session queries (composite partial index)
CREATE INDEX idx_sessions_user_active ON sessions(user_id)
    WHERE ended_at IS NULL AND deleted_at IS NULL;
```

### RLS Policies

```sql
-- Users can view their own sessions
CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create sessions
CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their sessions
CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their sessions
CREATE POLICY "Users can delete own sessions" ON sessions
    FOR DELETE USING (auth.uid() = user_id);

-- Authenticated users can view public sessions
CREATE POLICY "Authenticated users can view public sessions" ON sessions
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND is_private = false
        AND deleted_at IS NULL
    );
```

### Triggers

```sql
-- Auto-update updated_at timestamp
CREATE TRIGGER sessions_updated_at_trigger
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_sessions_updated_at();
```

### Sync Integration

**SessionsTable Actor**:
```swift
actor SessionsTable {
    func upsertSession(_ dto: SessionDTO) async throws -> SessionDTO
    func fetchUpdatedSince(since: Date, userId: UUID) async throws -> [SessionDTO]
    func fetchSession(id: UUID) async throws -> SessionDTO?
    func deleteSession(id: UUID) async throws
}
```

**SessionDTO**:
- Maps SwiftData `SCSession` to Supabase snake_case columns
- Handles date encoding/decoding
- Sendable for actor boundary crossing

**Sync Strategy**:
- Sessions created locally first (offline-first)
- `needsSync = true` flags pending changes
- SyncActor polls for changes and syncs in background
- On sync success, `needsSync` cleared
- Conflicts: Last-write-wins (newer `updated_at` wins)

---

## File Locations

### Domain Layer

**Models**:
- `/SwiftClimb/Domain/Models/Session.swift` - SCSession SwiftData model

**Services**:
- `/SwiftClimb/Domain/Services/SessionService.swift` - SessionService actor + protocol

**Use Cases**:
- `/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift`
- `/SwiftClimb/Domain/UseCases/EndSessionUseCase.swift`
- `/SwiftClimb/Domain/UseCases/GetActiveSessionUseCase.swift`
- `/SwiftClimb/Domain/UseCases/ListSessionsUseCase.swift`
- `/SwiftClimb/Domain/UseCases/DeleteSessionUseCase.swift`

### Features Layer

**Views**:
- `/SwiftClimb/Features/Session/SessionView.swift` - Main session view
- `/SwiftClimb/Features/Session/SessionDetailView.swift` - Session detail

**Components**:
- `/SwiftClimb/Features/Session/Components/EmptySessionState.swift`
- `/SwiftClimb/Features/Session/Components/StartSessionSheet.swift`
- `/SwiftClimb/Features/Session/Components/EndSessionSheet.swift`
- `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift`

### Integration Layer

**Supabase**:
- `/SwiftClimb/Integrations/Supabase/Tables/SessionsTable.swift` - Supabase operations

### App Layer

**Dependency Injection**:
- `/SwiftClimb/App/Environment+UseCases.swift` - Environment keys for all use cases

### Database

**Migrations**:
- `/Database/migrations/20260120_create_sessions_table.sql` - Table creation + RLS

---

## Future Enhancements

### Location/Venue Support

**Goal**: Associate sessions with climbing gyms or outdoor crags.

**Changes Needed**:
- Add `locationId: UUID?` to `SCSession`
- Create `SCLocation` model (gym/crag)
- Update StartSessionSheet to include location picker
- Add location search/recent locations UI

**Database**:
```sql
ALTER TABLE sessions ADD COLUMN location_id UUID REFERENCES locations(id);
```

### Weather Integration

**Goal**: Record weather conditions for outdoor sessions.

**Changes Needed**:
- Fetch weather at session start (OpenWeatherMap API)
- Store weather data in session (temperature, conditions, wind)
- Display weather in SessionDetailView

**Database**:
```sql
ALTER TABLE sessions ADD COLUMN weather_temp REAL;
ALTER TABLE sessions ADD COLUMN weather_conditions TEXT;
ALTER TABLE sessions ADD COLUMN weather_wind_speed REAL;
```

### Photos

**Goal**: Attach photos to sessions.

**Changes Needed**:
- Add `photoURLs: [String]` to `SCSession`
- Photo picker in ActiveSessionContent
- Upload to Supabase Storage
- Gallery view in SessionDetailView

**Storage**:
- Bucket: `session-photos`
- Path: `{user_id}/{session_id}/{photo_id}.jpg`
- RLS: Same as sessions (user owns their photos)

### Live Activities

**Goal**: Display active session in Dynamic Island / Lock Screen.

**Changes Needed**:
- Create `SessionActivity` ActivityKit activity
- Start activity when session begins
- Update with climb/attempt counts
- End activity when session ends

**Platforms**:
- iOS 16.1+ (Dynamic Island)
- iPhone 14 Pro and later for full experience

### Apple Watch

**Goal**: View active session and log climbs from watch.

**Changes Needed**:
- WatchOS companion app
- WatchConnectivity for session sync
- Simplified UI for watch screen
- Quick attempt logging

**Platforms**:
- watchOS 9.0+
- Requires paired iPhone

---

## Known Limitations

### Current Constraints

1. **Single Active Session**
   - Only one session can be active per user
   - Attempting to start a second throws `SessionError.sessionAlreadyActive`
   - **Rationale**: Prevents data confusion and simplifies UX

2. **No Session Editing**
   - Once ended, session metrics cannot be changed
   - Notes can be updated during active session only
   - **Workaround**: Delete and recreate session

3. **No Session Pause/Resume**
   - Sessions run continuously from start to end
   - No pause/resume functionality
   - **Workaround**: End session early, start new one

4. **No Offline Delete**
   - Deletes require network connection to propagate soft delete
   - Local-only deletes could cause sync conflicts
   - **Behavior**: Delete queued for next sync

5. **No Bulk Operations**
   - Cannot delete multiple sessions at once
   - No batch export/import
   - **Future**: Add bulk actions to LogbookView

### Performance Considerations

1. **Large Sessions**
   - Sessions with 100+ climbs may cause UI lag
   - LazyVStack helps but not a full solution
   - **Recommendation**: Paginate climbs list for very large sessions

2. **Elapsed Time Updates**
   - Currently updates UI every second during active session
   - Could impact battery on long sessions
   - **Future**: Update every minute instead

3. **Sync Latency**
   - Background sync may take several seconds
   - User may not see confirmation
   - **Future**: Add sync status indicator

---

## Architectural Decisions

### Why Offline-First?

**Decision**: SwiftData is the source of truth, Supabase is a backup.

**Rationale**:
- Climbing gyms often have poor cellular reception
- Users expect instant feedback when logging
- Network failures should not block progress
- SwiftUI `@Query` provides reactive updates for free

**Trade-offs**:
- More complex sync logic
- Potential for conflicts (mitigated by last-write-wins)
- Cannot rely on server-side validation

### Why Actor-Based Services?

**Decision**: All services are actors, not classes with locks.

**Rationale**:
- Swift 6 strict concurrency requires Sendable types
- Actors provide automatic thread-safety
- Eliminates entire class of data races
- Clean async/await integration

**Trade-offs**:
- Slight performance overhead for actor isolation
- Cannot use `@MainActor` methods directly (must use `MainActor.run`)
- Learning curve for developers unfamiliar with actors

### Why Return UUIDs Instead of Entities?

**Decision**: Service methods return `UUID` instead of `SCSession`.

**Rationale**:
- SwiftData entities are not Sendable
- Actors cannot return non-Sendable types
- Views use `@Query` anyway, not direct entity references
- Clear separation between service and view layers

**Trade-offs**:
- Views must re-fetch using UUID
- Slightly more verbose code
- Cannot return entity for immediate use

### Why No ViewModels?

**Decision**: Views call use cases directly, no ViewModel layer.

**Rationale**:
- SwiftUI `@Query` provides reactive state
- Use cases are Sendable and injectable
- ViewModels add boilerplate without value in this architecture
- Follows SwiftClimb MV pattern (not MVVM)

**Trade-offs**:
- View logic lives in view (not separate testable class)
- Testing requires UI testing or use case testing
- Some developers may prefer explicit ViewModels

---

## Testing Strategy

### Unit Tests

**SessionService Tests** (`SessionServiceTests.swift`):
- Create session with valid data
- Reject invalid readiness values
- Prevent duplicate active sessions
- End session updates metrics
- Soft delete sets deletedAt
- Update notes during session

**Use Case Tests**:
- StartSessionUseCase marks needsSync
- EndSessionUseCase validates RPE range
- DeleteSessionUseCase performs soft delete
- All use cases handle service errors

### Integration Tests

**Sync Tests** (`SessionSyncTests.swift`):
- Session syncs to Supabase after creation
- needsSync cleared after successful sync
- Conflicts resolved with last-write-wins
- Soft deletes propagate to Supabase

### UI Tests

**Manual Testing Checklist**:
- [ ] Start session with no readiness
- [ ] Start session with readiness capture
- [ ] Cannot start second session while one is active
- [ ] Active session shows elapsed time
- [ ] Active session shows climb count
- [ ] End session with all metrics
- [ ] End session with no metrics
- [ ] Session appears in logbook after ending
- [ ] Session detail shows all data
- [ ] Delete session from detail view
- [ ] Offline: Session created without network
- [ ] Online: Session syncs to Supabase

**Automated UI Tests** (Future):
- Use XCTest UI testing framework
- Test sheet presentation/dismissal
- Verify data persistence across app restarts
- Test error state displays

---

## Accessibility

### VoiceOver Support

**Tested Scenarios**:
- Navigate session view with VoiceOver
- Start session with VoiceOver
- Adjust readiness sliders with VoiceOver
- End session with VoiceOver

**Labels**:
- All buttons have descriptive labels
- Stats pills announce value and label
- Attempt pills announce "sent" or "fell"

### Dynamic Type

**All text uses**:
- `SCTypography` design system tokens
- Scales with user's preferred text size
- Tested at largest accessibility sizes

### Color Contrast

**All UI elements**:
- Meet WCAG AA standards for contrast
- Success/error states use icons + color
- No color-only information

---

## Monitoring & Metrics

### Key Metrics to Track

**Usage**:
- Sessions started per week
- Average session duration
- Readiness capture rate (% of sessions)
- RPE/pump level capture rate

**Performance**:
- Time to create session (target: < 100ms)
- Time to end session (target: < 100ms)
- Sync latency (target: < 5s)
- Failed sync operations

**Engagement**:
- Sessions per user per month
- Climbs per session
- Attempts per climb
- Session completion rate (% not abandoned)

### Error Monitoring

**Critical Errors**:
- SessionError.sessionAlreadyActive (indicates UX confusion)
- Sync failures (network or RLS issues)
- Data corruption (invalid metrics)

**Logging**:
- Log all session lifecycle events
- Log sync operations with timing
- Log validation failures with context

---

## Changelog

### Version 1.0 (2026-01-20)

**Initial Release**:
- Full session lifecycle (start, active, end)
- Readiness tracking (mental, physical)
- Post-session metrics (RPE, pump level, notes)
- Offline-first with Supabase sync
- Session history and detail views
- Soft delete functionality
- Complete UI with design system tokens

**Files Created**: 11
**Files Modified**: 4
**Total Lines**: ~2,500

---

## Support & Troubleshooting

### Common Issues

**Issue**: "Cannot start a new session while one is active"
**Solution**: End the current session before starting a new one. Check the Session tab to see if there's an active session.

**Issue**: Session not appearing in Logbook
**Solution**: Ensure the session was ended (has an `endedAt` timestamp). Active sessions only show in Session tab.

**Issue**: Changes not syncing to Supabase
**Solution**: Check network connection. Sync happens in background. Look for `needsSync = true` in debugger.

**Issue**: Delete session doesn't remove from UI immediately
**Solution**: This is a soft delete. Deleted sessions are filtered from queries. Hard delete happens during sync.

### Debug Mode

**Enable verbose logging**:
```swift
// In SessionService
#if DEBUG
print("[SessionService] Creating session for user \(userId)")
#endif
```

**Check sync status**:
```swift
// In SwiftData query
@Query(filter: #Predicate<SCSession> { $0.needsSync == true })
var unsyncedSessions: [SCSession]
```

---

**Document Maintained By**: Agent 4 (The Scribe)
**Last Review**: 2026-01-20
**Next Review**: When feature is extended or modified
