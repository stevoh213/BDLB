# Climb Logging Feature Specification

**Version:** 1.0
**Date:** 2026-01-21
**Author:** Agent 1 (The Architect)
**Status:** Ready for Implementation

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Requirements Summary](#3-requirements-summary)
4. [Data Model Changes](#4-data-model-changes)
5. [Database Migrations](#5-database-migrations)
6. [Service Layer Specifications](#6-service-layer-specifications)
7. [Use Case Specifications](#7-use-case-specifications)
8. [UI Component Specifications](#8-ui-component-specifications)
9. [Implementation Plan](#9-implementation-plan)
10. [Testing Strategy](#10-testing-strategy)

---

## 1. Executive Summary

This specification defines the Climb Logging feature for SwiftClimb, enabling users to:
- Start sessions with a discipline selection (bouldering, sport, trad, top rope)
- Add climbs with grades using a native picker wheel
- Log attempts with a two-tap flow (Add Attempt -> Fall/Send)
- Auto-infer send type (flash on first attempt, redpoint on subsequent)
- Edit climb details via tap-to-edit sheet

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Logging Flow | Hybrid | Quick-log attempts on existing climbs, form for new climbs |
| Required Fields | Grade only | Session, date, discipline inherited from session |
| Attempt Speed | Two-tap | Balance between speed and accuracy |
| Send Type | Auto-infer with override | First attempt = flash, subsequent = redpoint |
| Grade Input | Picker wheel | Native iOS feel, prevents invalid input |
| Climb Card Tap | Opens edit sheet | Full access to climb details and history |
| Tags | Deferred to Phase 2 | Focus on core logging MVP |
| Session Discipline | Set at start | All climbs inherit session discipline |

---

## 2. Current State Analysis

### Existing Models (Ready to Use)

| Model | Location | Status |
|-------|----------|--------|
| `SCSession` | `/SwiftClimb/Domain/Models/Session.swift` | **Needs `discipline` property** |
| `SCClimb` | `/SwiftClimb/Domain/Models/Climb.swift` | Complete |
| `SCAttempt` | `/SwiftClimb/Domain/Models/Attempt.swift` | Complete |
| `Discipline` | `/SwiftClimb/Domain/Models/Enums.swift` | Complete |
| `AttemptOutcome` | `/SwiftClimb/Domain/Models/Enums.swift` | Complete (`.try`, `.send`) |
| `SendType` | `/SwiftClimb/Domain/Models/Enums.swift` | Complete |
| `Grade` | `/SwiftClimb/Domain/Models/Grade.swift` | Complete with parsing |
| `GradeScale` | `/SwiftClimb/Domain/Models/Enums.swift` | Complete |

### Existing Services (Stub Implementations)

| Service | Location | Status |
|---------|----------|--------|
| `SessionService` | `/SwiftClimb/Domain/Services/SessionService.swift` | **Fully implemented** |
| `ClimbService` | `/SwiftClimb/Domain/Services/ClimbService.swift` | Stub - needs implementation |
| `AttemptService` | `/SwiftClimb/Domain/Services/AttemptService.swift` | Stub - needs implementation |

### Existing Use Cases (Stub Implementations)

| Use Case | Location | Status |
|----------|----------|--------|
| `StartSessionUseCase` | `/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift` | **Needs discipline parameter** |
| `AddClimbUseCase` | `/SwiftClimb/Domain/UseCases/AddClimbUseCase.swift` | Stub - needs implementation |
| `LogAttemptUseCase` | `/SwiftClimb/Domain/UseCases/LogAttemptUseCase.swift` | Stub - needs implementation |

### Existing UI Components

| Component | Location | Status |
|-----------|----------|--------|
| `SessionView` | `/SwiftClimb/Features/Session/SessionView.swift` | Active session management |
| `StartSessionSheet` | `/SwiftClimb/Features/Session/Components/StartSessionSheet.swift` | **Needs discipline picker** |
| `ActiveSessionContent` | `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` | Has placeholder climb list |
| `ClimbRow` | In `ActiveSessionContent.swift` | Basic implementation exists |
| `AttemptPill` | In `ActiveSessionContent.swift` | Basic implementation exists |

### Database Migrations

| Migration | Location | Status |
|-----------|----------|--------|
| Sessions table | `/Database/migrations/20260120_create_sessions_table.sql` | **Needs discipline column** |
| Climbs table | Not created | Needs creation |
| Attempts table | Not created | Needs creation |

---

## 3. Requirements Summary

### Functional Requirements

1. **Session Start with Discipline**
   - User MUST select discipline when starting a session
   - Discipline determines available grade scales
   - All climbs in session inherit the discipline

2. **Add Climb Flow**
   - Tap "Add Climb" button in active session
   - Sheet presents grade picker (only required field)
   - Optional name field for identification
   - Climb inherits: session ID, user ID, discipline, timestamp

3. **Attempt Logging**
   - Two-tap flow: "Add Attempt" -> "Fall" or "Send"
   - For sends: auto-infer send type based on attempt history
   - First successful attempt = flash (or onsight for route)
   - Subsequent successful attempts = redpoint
   - User can override send type if needed

4. **Climb Detail/Edit**
   - Tap climb card to open detail sheet
   - View attempt history
   - Edit climb properties (name, grade, notes)
   - Add attempts from detail view

### Non-Functional Requirements

1. **Performance**: Attempt logging < 100ms (offline-first)
2. **Offline**: All operations work without network
3. **Concurrency**: Swift 6 strict concurrency compliant
4. **Sync**: All changes marked for background sync

---

## 4. Data Model Changes

### 4.1 SCSession Model Update

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Session.swift`

**Change:** Add `discipline` property

```swift
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var discipline: Discipline  // NEW: Required discipline for session
    var startedAt: Date
    var endedAt: Date?
    var mentalReadiness: Int?
    var physicalReadiness: Int?
    var rpe: Int?
    var pumpLevel: Int?
    var notes: String?
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade)
    var climbs: [SCClimb]

    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        discipline: Discipline,  // NEW: Required parameter
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        mentalReadiness: Int? = nil,
        physicalReadiness: Int? = nil,
        rpe: Int? = nil,
        pumpLevel: Int? = nil,
        notes: String? = nil,
        isPrivate: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climbs: [SCClimb] = [],
        needsSync: Bool = true
    ) {
        // ... initialization
    }
}

extension SCSession {
    /// Returns the appropriate grade scale for this session's discipline
    var defaultGradeScale: GradeScale {
        switch discipline {
        case .bouldering:
            return .v
        case .sport, .trad, .topRope:
            return .yds  // Default to YDS for routes, user can override
        }
    }
}
```

### 4.2 Grade Scale Helper Extension

**Add to:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Enums.swift`

```swift
extension Discipline {
    /// Returns available grade scales for this discipline
    var availableGradeScales: [GradeScale] {
        switch self {
        case .bouldering:
            return [.v]  // Boulder only uses V scale
        case .sport, .trad, .topRope:
            return [.yds, .french, .uiaa]  // Routes can use various scales
        }
    }

    /// Returns the default grade scale for this discipline
    var defaultGradeScale: GradeScale {
        switch self {
        case .bouldering:
            return .v
        case .sport, .trad, .topRope:
            return .yds
        }
    }
}
```

### 4.3 Grade Values for Picker

**Add to:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Grade.swift`

```swift
extension Grade {
    /// All valid V-scale grades for picker
    static let vScaleGrades: [String] = [
        "VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7",
        "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15", "V16", "V17"
    ]

    /// All valid YDS grades for picker
    static let ydsGrades: [String] = [
        "5.5", "5.6", "5.7", "5.8", "5.9", "5.9+",
        "5.10a", "5.10b", "5.10c", "5.10d",
        "5.11a", "5.11b", "5.11c", "5.11d",
        "5.12a", "5.12b", "5.12c", "5.12d",
        "5.13a", "5.13b", "5.13c", "5.13d",
        "5.14a", "5.14b", "5.14c", "5.14d",
        "5.15a", "5.15b", "5.15c", "5.15d"
    ]

    /// All valid French grades for picker
    static let frenchGrades: [String] = [
        "4a", "4b", "4c", "5a", "5b", "5c",
        "6a", "6a+", "6b", "6b+", "6c", "6c+",
        "7a", "7a+", "7b", "7b+", "7c", "7c+",
        "8a", "8a+", "8b", "8b+", "8c", "8c+",
        "9a", "9a+", "9b", "9b+", "9c"
    ]

    /// All valid UIAA grades for picker
    static let uiaaGrades: [String] = [
        "III", "IV", "IV+", "V", "V+", "VI", "VI+",
        "VII", "VII+", "VIII", "VIII+", "IX", "IX+",
        "X", "X+", "XI", "XI+", "XII"
    ]

    /// Returns grades for a given scale
    static func grades(for scale: GradeScale) -> [String] {
        switch scale {
        case .v: return vScaleGrades
        case .yds: return ydsGrades
        case .french: return frenchGrades
        case .uiaa: return uiaaGrades
        }
    }
}
```

---

## 5. Database Migrations

### 5.1 Add Discipline to Sessions Table

**File:** `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260121_add_discipline_to_sessions.sql`

```sql
-- Migration: Add discipline column to sessions table
-- Version: 20260121
-- Description: Sessions now require a discipline selection

-- Add discipline column (nullable initially for migration)
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS discipline TEXT;

-- Set default for existing sessions (bouldering as safe default)
UPDATE public.sessions
SET discipline = 'bouldering'
WHERE discipline IS NULL;

-- Make column non-nullable
ALTER TABLE public.sessions
ALTER COLUMN discipline SET NOT NULL;

-- Add check constraint
ALTER TABLE public.sessions
ADD CONSTRAINT valid_discipline
CHECK (discipline IN ('bouldering', 'sport', 'trad', 'top_rope'));

-- Create index for filtering by discipline
CREATE INDEX IF NOT EXISTS idx_sessions_discipline ON sessions(discipline);
```

### 5.2 Create Climbs Table

**File:** `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260121_create_climbs_table.sql`

```sql
-- Migration: Create climbs table with RLS
-- Version: 20260121
-- Description: Sets up the climbs table for individual climb tracking within sessions

-- Create table
CREATE TABLE IF NOT EXISTS public.climbs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    discipline TEXT NOT NULL CHECK (discipline IN ('bouldering', 'sport', 'trad', 'top_rope')),
    is_outdoor BOOLEAN NOT NULL DEFAULT false,
    name TEXT,
    grade_original TEXT,
    grade_scale TEXT CHECK (grade_scale IN ('V', 'YDS', 'FRENCH', 'UIAA')),
    grade_score_min INTEGER,
    grade_score_max INTEGER,
    open_beta_climb_id TEXT,
    open_beta_area_id TEXT,
    location_display TEXT,
    belay_partner_user_id UUID REFERENCES auth.users(id),
    belay_partner_name TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_climbs_user_id ON climbs(user_id);
CREATE INDEX IF NOT EXISTS idx_climbs_session_id ON climbs(session_id);
CREATE INDEX IF NOT EXISTS idx_climbs_created_at ON climbs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_climbs_updated_at ON climbs(updated_at);
CREATE INDEX IF NOT EXISTS idx_climbs_grade_score ON climbs(grade_score_min);

-- Enable RLS
ALTER TABLE climbs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (for idempotent re-runs)
DROP POLICY IF EXISTS "Users can view own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can insert own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can update own climbs" ON climbs;
DROP POLICY IF EXISTS "Users can delete own climbs" ON climbs;
DROP POLICY IF EXISTS "Authenticated users can view public session climbs" ON climbs;

-- Create policies
CREATE POLICY "Users can view own climbs" ON climbs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own climbs" ON climbs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own climbs" ON climbs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own climbs" ON climbs
    FOR DELETE USING (auth.uid() = user_id);

-- View public climbs through public sessions
CREATE POLICY "Authenticated users can view public session climbs" ON climbs
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM sessions
            WHERE sessions.id = climbs.session_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_climbs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS climbs_updated_at_trigger ON climbs;
CREATE TRIGGER climbs_updated_at_trigger
    BEFORE UPDATE ON climbs
    FOR EACH ROW
    EXECUTE FUNCTION update_climbs_updated_at();
```

### 5.3 Create Attempts Table

**File:** `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260121_create_attempts_table.sql`

```sql
-- Migration: Create attempts table with RLS
-- Version: 20260121
-- Description: Sets up the attempts table for tracking individual climb attempts

-- Create table
CREATE TABLE IF NOT EXISTS public.attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES public.climbs(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number >= 1),
    outcome TEXT NOT NULL CHECK (outcome IN ('try', 'send')),
    send_type TEXT CHECK (send_type IN ('onsight', 'flash', 'redpoint', 'pinkpoint', 'project')),
    occurred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    -- Only allow send_type when outcome is 'send'
    CONSTRAINT send_type_requires_send CHECK (
        (outcome = 'send' AND send_type IS NOT NULL) OR
        (outcome = 'try' AND send_type IS NULL)
    ),

    -- Unique attempt number per climb
    CONSTRAINT unique_attempt_number UNIQUE (climb_id, attempt_number)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_session_id ON attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_attempts_climb_id ON attempts(climb_id);
CREATE INDEX IF NOT EXISTS idx_attempts_created_at ON attempts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_attempts_updated_at ON attempts(updated_at);

-- Enable RLS
ALTER TABLE attempts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can insert own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can update own attempts" ON attempts;
DROP POLICY IF EXISTS "Users can delete own attempts" ON attempts;
DROP POLICY IF EXISTS "Authenticated users can view public session attempts" ON attempts;

-- Create policies
CREATE POLICY "Users can view own attempts" ON attempts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own attempts" ON attempts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own attempts" ON attempts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own attempts" ON attempts
    FOR DELETE USING (auth.uid() = user_id);

-- View public attempts through public sessions
CREATE POLICY "Authenticated users can view public session attempts" ON attempts
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND deleted_at IS NULL
        AND EXISTS (
            SELECT 1 FROM sessions
            WHERE sessions.id = attempts.session_id
            AND sessions.is_private = false
            AND sessions.deleted_at IS NULL
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_attempts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS attempts_updated_at_trigger ON attempts;
CREATE TRIGGER attempts_updated_at_trigger
    BEFORE UPDATE ON attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_attempts_updated_at();
```

---

## 6. Service Layer Specifications

### 6.1 SessionService Updates

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/SessionService.swift`

**Changes Required:**

1. Update `createSession` signature to require discipline
2. Update protocol and implementation

```swift
protocol SessionServiceProtocol: Sendable {
    func createSession(
        userId: UUID,
        discipline: Discipline,  // NEW: Required parameter
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID

    // ... rest unchanged
}
```

### 6.2 ClimbService Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/ClimbService.swift`

```swift
import Foundation
import SwiftData

// MARK: - Errors

enum ClimbError: LocalizedError {
    case sessionNotFound
    case sessionNotActive
    case climbNotFound
    case invalidGrade(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .sessionNotActive:
            return "Cannot add climb to ended session"
        case .climbNotFound:
            return "Climb not found"
        case .invalidGrade(let grade):
            return "Invalid grade: \(grade)"
        }
    }
}

// MARK: - Protocol

protocol ClimbServiceProtocol: Sendable {
    /// Create a new climb in a session
    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> SCClimb

    /// Update climb properties
    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws

    /// Soft delete a climb
    func deleteClimb(climbId: UUID) async throws

    /// Get climb by ID
    func getClimb(climbId: UUID) async throws -> SCClimb?

    /// Get all climbs for a session
    func getClimbs(sessionId: UUID) async throws -> [SCClimb]
}

struct ClimbUpdates: Sendable {
    var name: String?
    var grade: Grade?
    var notes: String?
    var belayPartnerName: String?
    var locationDisplay: String?

    init(
        name: String? = nil,
        grade: Grade? = nil,
        notes: String? = nil,
        belayPartnerName: String? = nil,
        locationDisplay: String? = nil
    ) {
        self.name = name
        self.grade = grade
        self.notes = notes
        self.belayPartnerName = belayPartnerName
        self.locationDisplay = locationDisplay
    }
}

// MARK: - Implementation

actor ClimbService: ClimbServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> SCClimb {
        try await MainActor.run {
            // Verify session exists and is active
            let sessionPredicate = #Predicate<SCSession> { $0.id == sessionId }
            let sessionDescriptor = FetchDescriptor<SCSession>(predicate: sessionPredicate)

            guard let session = try modelContext.fetch(sessionDescriptor).first else {
                throw ClimbError.sessionNotFound
            }

            guard session.endedAt == nil else {
                throw ClimbError.sessionNotActive
            }

            // Create climb
            let climb = SCClimb(
                userId: userId,
                sessionId: sessionId,
                discipline: discipline,
                isOutdoor: isOutdoor,
                name: name,
                gradeOriginal: grade?.original,
                gradeScale: grade?.scale,
                gradeScoreMin: grade?.scoreMin,
                gradeScoreMax: grade?.scoreMax,
                openBetaClimbId: openBetaClimbId,
                openBetaAreaId: openBetaAreaId,
                locationDisplay: locationDisplay,
                session: session,
                needsSync: true
            )

            modelContext.insert(climb)
            session.climbs.append(climb)
            session.updatedAt = Date()
            session.needsSync = true

            try modelContext.save()

            return climb
        }
    }

    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> { $0.id == climbId }
            let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)

            guard let climb = try modelContext.fetch(descriptor).first else {
                throw ClimbError.climbNotFound
            }

            // Apply updates
            if let name = updates.name {
                climb.name = name
            }
            if let grade = updates.grade {
                climb.gradeOriginal = grade.original
                climb.gradeScale = grade.scale
                climb.gradeScoreMin = grade.scoreMin
                climb.gradeScoreMax = grade.scoreMax
            }
            if let notes = updates.notes {
                climb.notes = notes
            }
            if let belayPartner = updates.belayPartnerName {
                climb.belayPartnerName = belayPartner
            }
            if let location = updates.locationDisplay {
                climb.locationDisplay = location
            }

            climb.updatedAt = Date()
            climb.needsSync = true

            try modelContext.save()
        }
    }

    func deleteClimb(climbId: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> { $0.id == climbId }
            let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)

            guard let climb = try modelContext.fetch(descriptor).first else {
                throw ClimbError.climbNotFound
            }

            // Soft delete
            let now = Date()
            climb.deletedAt = now
            climb.updatedAt = now
            climb.needsSync = true

            // Also soft delete all attempts
            for attempt in climb.attempts {
                attempt.deletedAt = now
                attempt.updatedAt = now
                attempt.needsSync = true
            }

            try modelContext.save()
        }
    }

    func getClimb(climbId: UUID) async throws -> SCClimb? {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> {
                $0.id == climbId && $0.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCClimb>(predicate: predicate)
            return try modelContext.fetch(descriptor).first
        }
    }

    func getClimbs(sessionId: UUID) async throws -> [SCClimb] {
        try await MainActor.run {
            let predicate = #Predicate<SCClimb> {
                $0.sessionId == sessionId && $0.deletedAt == nil
            }
            var descriptor = FetchDescriptor<SCClimb>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
            return try modelContext.fetch(descriptor)
        }
    }
}
```

### 6.3 AttemptService Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/AttemptService.swift`

```swift
import Foundation
import SwiftData

// MARK: - Errors

enum AttemptError: LocalizedError {
    case climbNotFound
    case attemptNotFound
    case invalidAttemptNumber
    case sendTypeRequiredForSend

    var errorDescription: String? {
        switch self {
        case .climbNotFound:
            return "Climb not found"
        case .attemptNotFound:
            return "Attempt not found"
        case .invalidAttemptNumber:
            return "Invalid attempt number"
        case .sendTypeRequiredForSend:
            return "Send type is required for successful sends"
        }
    }
}

// MARK: - Protocol

protocol AttemptServiceProtocol: Sendable {
    /// Log a new attempt on a climb
    /// Performance target: < 100ms
    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt

    /// Soft delete an attempt
    func deleteAttempt(attemptId: UUID) async throws

    /// Get all attempts for a climb
    func getAttempts(climbId: UUID) async throws -> [SCAttempt]

    /// Get the next attempt number for a climb
    func getNextAttemptNumber(climbId: UUID) async throws -> Int

    /// Infer send type based on attempt history
    func inferSendType(climbId: UUID, discipline: Discipline) async throws -> SendType
}

// MARK: - Implementation

actor AttemptService: AttemptServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func logAttempt(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        sendType: SendType?
    ) async throws -> SCAttempt {
        // Validate: sends require send type
        if outcome == .send && sendType == nil {
            throw AttemptError.sendTypeRequiredForSend
        }

        return try await MainActor.run {
            // Verify climb exists
            let climbPredicate = #Predicate<SCClimb> { $0.id == climbId }
            let climbDescriptor = FetchDescriptor<SCClimb>(predicate: climbPredicate)

            guard let climb = try modelContext.fetch(climbDescriptor).first else {
                throw AttemptError.climbNotFound
            }

            // Calculate next attempt number
            let existingAttempts = climb.attempts.filter { $0.deletedAt == nil }
            let attemptNumber = existingAttempts.count + 1

            // Create attempt
            let attempt = SCAttempt(
                userId: userId,
                sessionId: sessionId,
                climbId: climbId,
                attemptNumber: attemptNumber,
                outcome: outcome,
                sendType: sendType,
                occurredAt: Date(),
                climb: climb,
                needsSync: true
            )

            modelContext.insert(attempt)
            climb.attempts.append(attempt)
            climb.updatedAt = Date()
            climb.needsSync = true

            try modelContext.save()

            return attempt
        }
    }

    func deleteAttempt(attemptId: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> { $0.id == attemptId }
            let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)

            guard let attempt = try modelContext.fetch(descriptor).first else {
                throw AttemptError.attemptNotFound
            }

            // Soft delete
            let now = Date()
            attempt.deletedAt = now
            attempt.updatedAt = now
            attempt.needsSync = true

            // Update climb
            if let climb = attempt.climb {
                climb.updatedAt = now
                climb.needsSync = true
            }

            try modelContext.save()
        }
    }

    func getAttempts(climbId: UUID) async throws -> [SCAttempt] {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            var descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.attemptNumber, order: .forward)]
            return try modelContext.fetch(descriptor)
        }
    }

    func getNextAttemptNumber(climbId: UUID) async throws -> Int {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)
            let attempts = try modelContext.fetch(descriptor)
            return attempts.count + 1
        }
    }

    func inferSendType(climbId: UUID, discipline: Discipline) async throws -> SendType {
        try await MainActor.run {
            let predicate = #Predicate<SCAttempt> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let descriptor = FetchDescriptor<SCAttempt>(predicate: predicate)
            let attempts = try modelContext.fetch(descriptor)

            // If no previous attempts, it's a flash (first try with beta)
            // For bouldering, flash is standard. For routes, could be onsight
            // but we default to flash (safer assumption - user saw others try it)
            if attempts.isEmpty {
                return .flash
            }

            // If there are previous attempts, it's a redpoint
            return .redpoint
        }
    }
}
```

---

## 7. Use Case Specifications

### 7.1 StartSessionUseCase Update

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift`

```swift
import Foundation

protocol StartSessionUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        discipline: Discipline,  // NEW: Required parameter
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID
}

final class StartSessionUseCase: StartSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(
        userId: UUID,
        discipline: Discipline,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> UUID {
        let sessionId = try await sessionService.createSession(
            userId: userId,
            discipline: discipline,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )

        return sessionId
    }
}
```

### 7.2 AddClimbUseCase Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/AddClimbUseCase.swift`

```swift
import Foundation

protocol AddClimbUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        gradeString: String,
        gradeScale: GradeScale,
        name: String?,
        isOutdoor: Bool,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> SCClimb
}

final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        gradeString: String,
        gradeScale: GradeScale,
        name: String?,
        isOutdoor: Bool = false,
        openBetaClimbId: String? = nil,
        openBetaAreaId: String? = nil,
        locationDisplay: String? = nil
    ) async throws -> SCClimb {
        // Parse grade from string
        guard let grade = Grade.parse(gradeString) else {
            throw ClimbError.invalidGrade(gradeString)
        }

        return try await climbService.createClimb(
            userId: userId,
            sessionId: sessionId,
            discipline: discipline,
            isOutdoor: isOutdoor,
            name: name,
            grade: grade,
            openBetaClimbId: openBetaClimbId,
            openBetaAreaId: openBetaAreaId,
            locationDisplay: locationDisplay
        )
    }
}
```

### 7.3 LogAttemptUseCase Implementation

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/LogAttemptUseCase.swift`

```swift
import Foundation

protocol LogAttemptUseCaseProtocol: Sendable {
    /// Log an attempt with auto-inferred send type
    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        discipline: Discipline,
        sendTypeOverride: SendType?
    ) async throws -> SCAttempt
}

final class LogAttemptUseCase: LogAttemptUseCaseProtocol, Sendable {
    private let attemptService: AttemptServiceProtocol

    init(attemptService: AttemptServiceProtocol) {
        self.attemptService = attemptService
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        outcome: AttemptOutcome,
        discipline: Discipline,
        sendTypeOverride: SendType? = nil
    ) async throws -> SCAttempt {
        // Determine send type for successful sends
        var sendType: SendType? = nil

        if outcome == .send {
            if let override = sendTypeOverride {
                sendType = override
            } else {
                // Auto-infer based on attempt history
                sendType = try await attemptService.inferSendType(
                    climbId: climbId,
                    discipline: discipline
                )
            }
        }

        return try await attemptService.logAttempt(
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            outcome: outcome,
            sendType: sendType
        )
    }
}
```

### 7.4 UpdateClimbUseCase (New)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/UpdateClimbUseCase.swift`

```swift
import Foundation

protocol UpdateClimbUseCaseProtocol: Sendable {
    func execute(
        climbId: UUID,
        name: String?,
        gradeString: String?,
        notes: String?,
        belayPartnerName: String?,
        locationDisplay: String?
    ) async throws
}

final class UpdateClimbUseCase: UpdateClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(
        climbId: UUID,
        name: String?,
        gradeString: String?,
        notes: String?,
        belayPartnerName: String?,
        locationDisplay: String?
    ) async throws {
        var grade: Grade? = nil
        if let gradeString = gradeString {
            grade = Grade.parse(gradeString)
        }

        let updates = ClimbUpdates(
            name: name,
            grade: grade,
            notes: notes,
            belayPartnerName: belayPartnerName,
            locationDisplay: locationDisplay
        )

        try await climbService.updateClimb(climbId: climbId, updates: updates)
    }
}
```

### 7.5 DeleteClimbUseCase (New)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/DeleteClimbUseCase.swift`

```swift
import Foundation

protocol DeleteClimbUseCaseProtocol: Sendable {
    func execute(climbId: UUID) async throws
}

final class DeleteClimbUseCase: DeleteClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol

    init(climbService: ClimbServiceProtocol) {
        self.climbService = climbService
    }

    func execute(climbId: UUID) async throws {
        try await climbService.deleteClimb(climbId: climbId)
    }
}
```

### 7.6 DeleteAttemptUseCase (New)

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/DeleteAttemptUseCase.swift`

```swift
import Foundation

protocol DeleteAttemptUseCaseProtocol: Sendable {
    func execute(attemptId: UUID) async throws
}

final class DeleteAttemptUseCase: DeleteAttemptUseCaseProtocol, Sendable {
    private let attemptService: AttemptServiceProtocol

    init(attemptService: AttemptServiceProtocol) {
        self.attemptService = attemptService
    }

    func execute(attemptId: UUID) async throws {
        try await attemptService.deleteAttempt(attemptId: attemptId)
    }
}
```

---

## 8. UI Component Specifications

### 8.1 DisciplinePicker Component

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/DisciplinePicker.swift`

```swift
import SwiftUI

/// Segmented picker for selecting climbing discipline
struct DisciplinePicker: View {
    @Binding var selection: Discipline

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Discipline")
                .font(SCTypography.body.weight(.medium))

            Picker("Discipline", selection: $selection) {
                ForEach(Discipline.allCases, id: \.self) { discipline in
                    Text(discipline.displayName)
                        .tag(discipline)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    @Previewable @State var discipline: Discipline = .bouldering

    DisciplinePicker(selection: $discipline)
        .padding()
}
```

### 8.2 GradePicker Component

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/GradePicker.swift`

```swift
import SwiftUI

/// Native iOS picker wheel for grade selection
struct GradePicker: View {
    let discipline: Discipline
    @Binding var selectedGrade: String
    @Binding var selectedScale: GradeScale

    private var availableGrades: [String] {
        Grade.grades(for: selectedScale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            // Scale selector (only for routes with multiple scales)
            if discipline != .bouldering {
                HStack {
                    Text("Scale")
                        .font(SCTypography.body.weight(.medium))

                    Spacer()

                    Picker("Scale", selection: $selectedScale) {
                        ForEach(discipline.availableGradeScales, id: \.self) { scale in
                            Text(scale.displayName).tag(scale)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Grade picker wheel
            Picker("Grade", selection: $selectedGrade) {
                ForEach(availableGrades, id: \.self) { grade in
                    Text(grade).tag(grade)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .onChange(of: selectedScale) { _, newScale in
            // Reset to middle-ish grade when scale changes
            let grades = Grade.grades(for: newScale)
            let midIndex = grades.count / 2
            selectedGrade = grades[midIndex]
        }
    }
}

#Preview("Boulder") {
    @Previewable @State var grade = "V5"
    @Previewable @State var scale: GradeScale = .v

    GradePicker(
        discipline: .bouldering,
        selectedGrade: $grade,
        selectedScale: $scale
    )
    .padding()
}

#Preview("Sport") {
    @Previewable @State var grade = "5.11a"
    @Previewable @State var scale: GradeScale = .yds

    GradePicker(
        discipline: .sport,
        selectedGrade: $grade,
        selectedScale: $scale
    )
    .padding()
}
```

### 8.3 StartSessionSheet Update

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/StartSessionSheet.swift`

**Changes:** Add discipline selection

```swift
import SwiftUI

struct StartSessionSheet: View {
    let onStart: (Discipline, Int?, Int?) -> Void  // UPDATED signature
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var discipline: Discipline = .bouldering  // NEW
    @State private var mentalReadiness: Int?
    @State private var physicalReadiness: Int?
    @State private var selectedDetent: PresentationDetent = .medium

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SCSpacing.lg) {
                // Discipline picker (always visible)
                DisciplinePicker(selection: $discipline)
                    .padding(.horizontal)

                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }

                Spacer()

                startButton
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Collapsed State

    @ViewBuilder
    private var collapsedContent: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Quick Start")
                .font(SCTypography.body)

            Text("Skip readiness tracking and jump right in")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: SCSpacing.xs) {
                Image(systemName: "chevron.up")
                    .font(.caption)
                Text("Pull up to track readiness")
                    .font(SCTypography.metadata)
            }
            .foregroundStyle(SCColors.textTertiary)
            .padding(.top, SCSpacing.sm)
        }
        .padding(.vertical, SCSpacing.lg)
    }

    // MARK: - Expanded State

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: SCSpacing.lg) {
            Text("How are you feeling today?")
                .font(SCTypography.sectionHeader)

            ReadinessSlider(
                title: "Mental Readiness",
                value: $mentalReadiness,
                icon: "brain.head.profile"
            )

            ReadinessSlider(
                title: "Physical Readiness",
                value: $physicalReadiness,
                icon: "figure.stand"
            )

            VStack(spacing: SCSpacing.xs) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                Text("Pull down to skip")
                    .font(SCTypography.metadata)
            }
            .foregroundStyle(SCColors.textTertiary)
            .padding(.top, SCSpacing.sm)
        }
    }

    // MARK: - Start Button

    @ViewBuilder
    private var startButton: some View {
        SCPrimaryButton(
            title: isLoading ? "Starting..." : "Start \(discipline.displayName) Session",
            action: {
                onStart(discipline, mentalReadiness, physicalReadiness)
            },
            isLoading: isLoading,
            isFullWidth: true
        )
        .disabled(isLoading)
        .padding(.horizontal)
        .padding(.bottom, SCSpacing.md)
    }
}
```

### 8.4 AddClimbSheet Component

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/AddClimbSheet.swift`

```swift
import SwiftUI

/// Sheet for adding a new climb to the active session
struct AddClimbSheet: View {
    let session: SCSession
    let onAdd: (String, GradeScale, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedGrade: String = "V5"
    @State private var selectedScale: GradeScale = .v
    @State private var climbName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GradePicker(
                        discipline: session.discipline,
                        selectedGrade: $selectedGrade,
                        selectedScale: $selectedScale
                    )
                } header: {
                    Text("Grade")
                } footer: {
                    Text("Required - select the grade of the climb")
                }

                Section {
                    TextField("e.g., Red corner problem", text: $climbName)
                } header: {
                    Text("Name (Optional)")
                } footer: {
                    Text("A name helps identify this climb later")
                }
            }
            .navigationTitle("Add Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await addClimb() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            // Set initial grade based on discipline
            let grades = Grade.grades(for: session.discipline.defaultGradeScale)
            selectedScale = session.discipline.defaultGradeScale
            selectedGrade = grades[grades.count / 2]  // Start in middle
        }
    }

    private func addClimb() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let name = climbName.isEmpty ? nil : climbName
            try await onAdd(selectedGrade, selectedScale, name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddClimbSheet(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onAdd: { _, _, _ in }
    )
}
```

### 8.5 AttemptLogButtons Component

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/AttemptLogButtons.swift`

```swift
import SwiftUI

/// Two-tap attempt logging flow: Add Attempt -> Fall/Send
struct AttemptLogButtons: View {
    let climb: SCClimb
    let onLogAttempt: (AttemptOutcome, SendType?) async throws -> Void

    @State private var showOutcomeChoice = false
    @State private var showSendTypeOverride = false
    @State private var inferredSendType: SendType = .flash
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: SCSpacing.sm) {
            if showOutcomeChoice {
                outcomeButtons
            } else {
                addAttemptButton
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Send Type",
            isPresented: $showSendTypeOverride,
            titleVisibility: .visible
        ) {
            sendTypeOptions
        } message: {
            Text("This will be logged as a \(inferredSendType.displayName). Change?")
        }
    }

    // MARK: - Add Attempt Button

    @ViewBuilder
    private var addAttemptButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                inferSendType()
                showOutcomeChoice = true
            }
        } label: {
            Label("Add Attempt", systemImage: "plus.circle")
                .font(SCTypography.body.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }

    // MARK: - Outcome Buttons (Fall/Send)

    @ViewBuilder
    private var outcomeButtons: some View {
        HStack(spacing: SCSpacing.md) {
            // Fall button
            Button {
                Task { await logAttempt(.try, sendType: nil) }
            } label: {
                Label("Fall", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isLoading)

            // Send button
            Button {
                // Show send type confirmation
                showSendTypeOverride = true
            } label: {
                Label("Send", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isLoading)

            // Cancel button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOutcomeChoice = false
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Send Type Options

    @ViewBuilder
    private var sendTypeOptions: some View {
        Button("Log as \(inferredSendType.displayName)") {
            Task { await logAttempt(.send, sendType: inferredSendType) }
        }

        ForEach(SendType.allCases.filter { $0 != inferredSendType }, id: \.self) { type in
            Button("Change to \(type.displayName)") {
                Task { await logAttempt(.send, sendType: type) }
            }
        }

        Button("Cancel", role: .cancel) {
            showOutcomeChoice = false
        }
    }

    // MARK: - Helper Methods

    private func inferSendType() {
        let attemptCount = climb.attempts.filter { $0.deletedAt == nil }.count
        inferredSendType = attemptCount == 0 ? .flash : .redpoint
    }

    private func logAttempt(_ outcome: AttemptOutcome, sendType: SendType?) async {
        isLoading = true
        defer {
            isLoading = false
            showOutcomeChoice = false
        }

        do {
            try await onLogAttempt(outcome, sendType)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AttemptLogButtons(
        climb: SCClimb(
            userId: UUID(),
            sessionId: UUID(),
            discipline: .bouldering,
            isOutdoor: false
        ),
        onLogAttempt: { _, _ in }
    )
    .padding()
}
```

### 8.6 ClimbDetailSheet Component

**File:** `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/ClimbDetailSheet.swift`

```swift
import SwiftUI

/// Full edit sheet for climb details and attempt history
struct ClimbDetailSheet: View {
    @Bindable var climb: SCClimb
    let session: SCSession
    let onUpdate: (ClimbUpdates) async throws -> Void
    let onDelete: () async throws -> Void
    let onLogAttempt: (AttemptOutcome, SendType?) async throws -> Void
    let onDeleteAttempt: (UUID) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var editedName: String = ""
    @State private var editedGrade: String = ""
    @State private var editedScale: GradeScale = .v
    @State private var editedNotes: String = ""
    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var sortedAttempts: [SCAttempt] {
        climb.attempts
            .filter { $0.deletedAt == nil }
            .sorted { $0.attemptNumber < $1.attemptNumber }
    }

    var body: some View {
        NavigationStack {
            List {
                // Climb Info Section
                Section("Climb Details") {
                    if isEditing {
                        editingContent
                    } else {
                        displayContent
                    }
                }

                // Attempts Section
                Section("Attempts (\(sortedAttempts.count))") {
                    if sortedAttempts.isEmpty {
                        Text("No attempts yet")
                            .foregroundStyle(SCColors.textSecondary)
                    } else {
                        ForEach(sortedAttempts) { attempt in
                            AttemptRow(attempt: attempt)
                        }
                        .onDelete(perform: deleteAttempts)
                    }

                    // Add attempt inline
                    AttemptLogButtons(
                        climb: climb,
                        onLogAttempt: onLogAttempt
                    )
                }

                // Delete Section
                Section {
                    Button("Delete Climb", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(climb.name ?? climb.gradeOriginal ?? "Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task { await saveChanges() }
                        } else {
                            startEditing()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Delete Climb?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteClimb() }
                }
            } message: {
                Text("This will delete the climb and all its attempts. This cannot be undone.")
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Display Content

    @ViewBuilder
    private var displayContent: some View {
        LabeledContent("Grade", value: climb.gradeOriginal ?? "Unknown")

        if let name = climb.name, !name.isEmpty {
            LabeledContent("Name", value: name)
        }

        LabeledContent("Discipline", value: climb.discipline.displayName)

        if climb.hasSend {
            LabeledContent("Status") {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }

        if let notes = climb.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: SCSpacing.xs) {
                Text("Notes")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
                Text(notes)
            }
        }
    }

    // MARK: - Editing Content

    @ViewBuilder
    private var editingContent: some View {
        TextField("Name", text: $editedName)

        GradePicker(
            discipline: session.discipline,
            selectedGrade: $editedGrade,
            selectedScale: $editedScale
        )

        TextField("Notes", text: $editedNotes, axis: .vertical)
            .lineLimit(3...6)
    }

    // MARK: - Helper Methods

    private func startEditing() {
        editedName = climb.name ?? ""
        editedGrade = climb.gradeOriginal ?? ""
        editedScale = climb.gradeScale ?? session.discipline.defaultGradeScale
        editedNotes = climb.notes ?? ""
        isEditing = true
    }

    private func saveChanges() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let updates = ClimbUpdates(
                name: editedName.isEmpty ? nil : editedName,
                grade: Grade.parse(editedGrade),
                notes: editedNotes.isEmpty ? nil : editedNotes
            )
            try await onUpdate(updates)
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteClimb() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAttempts(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let attempt = sortedAttempts[index]
                try? await onDeleteAttempt(attempt.id)
            }
        }
    }
}

/// Row displaying attempt details
struct AttemptRow: View {
    let attempt: SCAttempt

    var body: some View {
        HStack {
            Text("#\(attempt.attemptNumber)")
                .font(SCTypography.body.monospacedDigit())
                .foregroundStyle(SCColors.textSecondary)

            Image(systemName: attempt.outcome.systemImage)
                .foregroundStyle(attempt.isSend ? .green : .red)

            Text(attempt.outcome.displayName)
                .font(SCTypography.body)

            if let sendType = attempt.sendType {
                Text("(\(sendType.displayName))")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }

            Spacer()

            if let time = attempt.occurredAt {
                Text(time, style: .time)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
    }
}
```

### 8.7 Updated ClimbRow Component

**File:** Update in `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift`

```swift
/// Row displaying a climb with attempts - tappable for editing
struct ClimbRow: View {
    let climb: SCClimb
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SCGlassCard {
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(climb.name ?? climb.discipline.displayName)
                                .font(SCTypography.body.weight(.medium))

                            if let grade = climb.gradeOriginal {
                                Text(grade)
                                    .font(SCTypography.secondary)
                                    .foregroundStyle(SCColors.textSecondary)
                            }
                        }

                        Spacer()

                        if climb.hasSend {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(SCColors.textTertiary)
                    }

                    // Attempt pills
                    if !climb.attempts.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(climb.attempts
                                .filter { $0.deletedAt == nil }
                                .sorted(by: { $0.attemptNumber < $1.attemptNumber })
                            ) { attempt in
                                AttemptPill(attempt: attempt)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

### 8.8 Updated ActiveSessionContent

Update the climbs list to use tap-to-edit and integrate the add climb flow.

```swift
// In ActiveSessionContent.swift - update the body and add state

@State private var showAddClimb = false
@State private var selectedClimb: SCClimb?

// Update climbsList
@ViewBuilder
private var climbsList: some View {
    LazyVStack(spacing: SCSpacing.sm) {
        ForEach(session.climbs.filter { $0.deletedAt == nil }) { climb in
            ClimbRow(climb: climb) {
                selectedClimb = climb
            }
        }
    }
}

// Add sheet modifiers
.sheet(isPresented: $showAddClimb) {
    AddClimbSheet(
        session: session,
        onAdd: handleAddClimb
    )
}
.sheet(item: $selectedClimb) { climb in
    ClimbDetailSheet(
        climb: climb,
        session: session,
        onUpdate: { updates in try await handleUpdateClimb(climb.id, updates) },
        onDelete: { try await handleDeleteClimb(climb.id) },
        onLogAttempt: { outcome, sendType in
            try await handleLogAttempt(climb.id, outcome, sendType)
        },
        onDeleteAttempt: handleDeleteAttempt
    )
}
```

---

## 9. Implementation Plan

### Phase 1: Data Layer (Day 1)

**Order matters - dependencies must be built first.**

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 1.1 | Add discipline property to SCSession | `/SwiftClimb/Domain/Models/Session.swift` | None |
| 1.2 | Add grade picker values to Grade | `/SwiftClimb/Domain/Models/Grade.swift` | None |
| 1.3 | Add discipline grade scale helpers | `/SwiftClimb/Domain/Models/Enums.swift` | None |
| 1.4 | Create sessions discipline migration | `/Database/migrations/20260121_add_discipline_to_sessions.sql` | 1.1 |
| 1.5 | Create climbs table migration | `/Database/migrations/20260121_create_climbs_table.sql` | 1.4 |
| 1.6 | Create attempts table migration | `/Database/migrations/20260121_create_attempts_table.sql` | 1.5 |

### Phase 2: Service Layer (Day 2)

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 2.1 | Update SessionService for discipline | `/SwiftClimb/Domain/Services/SessionService.swift` | 1.1 |
| 2.2 | Implement ClimbService | `/SwiftClimb/Domain/Services/ClimbService.swift` | 1.5 |
| 2.3 | Implement AttemptService | `/SwiftClimb/Domain/Services/AttemptService.swift` | 1.6, 2.2 |

### Phase 3: Use Case Layer (Day 2)

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 3.1 | Update StartSessionUseCase | `/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift` | 2.1 |
| 3.2 | Implement AddClimbUseCase | `/SwiftClimb/Domain/UseCases/AddClimbUseCase.swift` | 2.2 |
| 3.3 | Implement LogAttemptUseCase | `/SwiftClimb/Domain/UseCases/LogAttemptUseCase.swift` | 2.3 |
| 3.4 | Create UpdateClimbUseCase | `/SwiftClimb/Domain/UseCases/UpdateClimbUseCase.swift` | 2.2 |
| 3.5 | Create DeleteClimbUseCase | `/SwiftClimb/Domain/UseCases/DeleteClimbUseCase.swift` | 2.2 |
| 3.6 | Create DeleteAttemptUseCase | `/SwiftClimb/Domain/UseCases/DeleteAttemptUseCase.swift` | 2.3 |

### Phase 4: Environment Keys (Day 2)

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 4.1 | Add UpdateClimbUseCase key | `/SwiftClimb/App/Environment+UseCases.swift` | 3.4 |
| 4.2 | Add DeleteClimbUseCase key | `/SwiftClimb/App/Environment+UseCases.swift` | 3.5 |
| 4.3 | Add DeleteAttemptUseCase key | `/SwiftClimb/App/Environment+UseCases.swift` | 3.6 |

### Phase 5: UI Components (Day 3)

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 5.1 | Create DisciplinePicker | `/SwiftClimb/Features/Session/Components/DisciplinePicker.swift` | None |
| 5.2 | Create GradePicker | `/SwiftClimb/Features/Session/Components/GradePicker.swift` | 1.2, 1.3 |
| 5.3 | Update StartSessionSheet | `/SwiftClimb/Features/Session/Components/StartSessionSheet.swift` | 5.1, 3.1 |
| 5.4 | Create AddClimbSheet | `/SwiftClimb/Features/Session/Components/AddClimbSheet.swift` | 5.2 |
| 5.5 | Create AttemptLogButtons | `/SwiftClimb/Features/Session/Components/AttemptLogButtons.swift` | None |
| 5.6 | Create ClimbDetailSheet | `/SwiftClimb/Features/Session/Components/ClimbDetailSheet.swift` | 5.2, 5.5 |
| 5.7 | Update ClimbRow | `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` | None |
| 5.8 | Update ActiveSessionContent | `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` | 5.4, 5.6, 5.7 |

### Phase 6: Integration (Day 3)

| Step | Task | File | Dependencies |
|------|------|------|--------------|
| 6.1 | Update SessionView for discipline | `/SwiftClimb/Features/Session/SessionView.swift` | 5.3 |
| 6.2 | Wire up climb use cases | `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` | 4.1-4.3 |
| 6.3 | Update SwiftClimbApp DI | `/SwiftClimb/App/SwiftClimbApp.swift` | All services |

### Phase 7: Testing (Day 4)

| Step | Task | Dependencies |
|------|------|--------------|
| 7.1 | Test session start with discipline | All phases |
| 7.2 | Test add climb flow | All phases |
| 7.3 | Test attempt logging | All phases |
| 7.4 | Test send type inference | All phases |
| 7.5 | Test climb edit/delete | All phases |

---

## 10. Testing Strategy

### Unit Tests (Services)

```swift
@Suite("ClimbService Tests")
struct ClimbServiceTests {
    @Test("createClimb creates climb with correct properties")
    func createClimb() async throws {
        // Given a session exists
        // When createClimb is called
        // Then climb is created with correct session/user/discipline
    }

    @Test("createClimb throws when session not found")
    func createClimbSessionNotFound() async throws {
        // Given no session exists
        // When createClimb is called
        // Then ClimbError.sessionNotFound is thrown
    }

    @Test("createClimb throws when session ended")
    func createClimbSessionEnded() async throws {
        // Given session has endedAt set
        // When createClimb is called
        // Then ClimbError.sessionNotActive is thrown
    }
}

@Suite("AttemptService Tests")
struct AttemptServiceTests {
    @Test("logAttempt creates attempt with correct number")
    func logAttemptNumber() async throws {
        // Given a climb with 2 attempts
        // When logAttempt is called
        // Then attempt is created with attemptNumber = 3
    }

    @Test("inferSendType returns flash for first attempt")
    func inferSendTypeFirst() async throws {
        // Given a climb with 0 attempts
        // When inferSendType is called
        // Then .flash is returned
    }

    @Test("inferSendType returns redpoint after attempts")
    func inferSendTypeSubsequent() async throws {
        // Given a climb with 1+ attempts
        // When inferSendType is called
        // Then .redpoint is returned
    }
}
```

### Integration Tests (Use Cases)

```swift
@Suite("LogAttemptUseCase Tests")
struct LogAttemptUseCaseTests {
    @Test("execute auto-infers flash for first send")
    func autoInferFlash() async throws {
        // Given a new climb
        // When logging a send without override
        // Then attempt has sendType = .flash
    }

    @Test("execute uses override when provided")
    func respectOverride() async throws {
        // Given a new climb
        // When logging a send with override = .onsight
        // Then attempt has sendType = .onsight
    }
}
```

### UI Tests (Preview-Based)

All UI components include `#Preview` blocks for visual testing:
- DisciplinePicker: Verify segmented control behavior
- GradePicker: Verify picker wheel scrolling
- StartSessionSheet: Verify discipline selection and detent behavior
- AddClimbSheet: Verify grade selection and submission
- AttemptLogButtons: Verify two-tap flow and confirmation dialog
- ClimbDetailSheet: Verify edit mode, attempt list, delete confirmation

---

## Acceptance Criteria

### Must Have (MVP)

- [ ] User can start session with discipline selection
- [ ] User can add climb with grade picker wheel
- [ ] Climb inherits discipline from session
- [ ] User can log attempt with two-tap flow (Add -> Fall/Send)
- [ ] Send type auto-inferred (flash/redpoint)
- [ ] User can override send type when needed
- [ ] User can tap climb to open edit sheet
- [ ] User can edit climb name, grade, notes
- [ ] User can delete climb
- [ ] User can delete individual attempts
- [ ] All operations work offline
- [ ] All operations complete in < 100ms (local)
- [ ] All changes marked for sync

### Nice to Have (Can defer)

- [ ] Undo attempt logging
- [ ] Swipe-to-delete on climb rows
- [ ] Haptic feedback on attempt log
- [ ] Animation polish on outcome buttons

---

## File Summary

### New Files to Create

1. `/Database/migrations/20260121_add_discipline_to_sessions.sql`
2. `/Database/migrations/20260121_create_climbs_table.sql`
3. `/Database/migrations/20260121_create_attempts_table.sql`
4. `/SwiftClimb/Domain/UseCases/UpdateClimbUseCase.swift`
5. `/SwiftClimb/Domain/UseCases/DeleteClimbUseCase.swift`
6. `/SwiftClimb/Domain/UseCases/DeleteAttemptUseCase.swift`
7. `/SwiftClimb/Features/Session/Components/DisciplinePicker.swift`
8. `/SwiftClimb/Features/Session/Components/GradePicker.swift`
9. `/SwiftClimb/Features/Session/Components/AddClimbSheet.swift`
10. `/SwiftClimb/Features/Session/Components/AttemptLogButtons.swift`
11. `/SwiftClimb/Features/Session/Components/ClimbDetailSheet.swift`

### Files to Modify

1. `/SwiftClimb/Domain/Models/Session.swift` - Add discipline property
2. `/SwiftClimb/Domain/Models/Grade.swift` - Add picker grade arrays
3. `/SwiftClimb/Domain/Models/Enums.swift` - Add discipline grade scale helpers
4. `/SwiftClimb/Domain/Services/SessionService.swift` - Add discipline parameter
5. `/SwiftClimb/Domain/Services/ClimbService.swift` - Full implementation
6. `/SwiftClimb/Domain/Services/AttemptService.swift` - Full implementation
7. `/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift` - Add discipline parameter
8. `/SwiftClimb/Domain/UseCases/AddClimbUseCase.swift` - Full implementation
9. `/SwiftClimb/Domain/UseCases/LogAttemptUseCase.swift` - Full implementation
10. `/SwiftClimb/App/Environment+UseCases.swift` - Add new use case keys
11. `/SwiftClimb/Features/Session/Components/StartSessionSheet.swift` - Add discipline picker
12. `/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` - Integration
13. `/SwiftClimb/Features/Session/SessionView.swift` - Update for discipline
14. `/SwiftClimb/App/SwiftClimbApp.swift` - Wire up new use cases

---

**End of Specification**

*This document should be handed to Agent 2 (The Builder) for implementation.*
