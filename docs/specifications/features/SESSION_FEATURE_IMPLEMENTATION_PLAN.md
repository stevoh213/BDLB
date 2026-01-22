# Sessions Feature Implementation Plan

**Version**: 1.0
**Status**: Implemented
**Created**: 2026-01-20
**Updated**: 2026-01-20
**Author**: Agent 1 (The Architect)
**Documented**: Agent 4 (The Scribe)

---

## Executive Summary

This document provides a comprehensive implementation plan for the **Sessions feature** in SwiftClimb. A session represents a climbing workout from start to finish, capturing readiness metrics, climbs, attempts, and post-session feedback. The implementation follows SwiftClimb's offline-first architecture with actor-based services and MV pattern.

### Current State Analysis

**What Exists:**
- `SCSession` SwiftData model with complete field definitions
- `SCClimb` and `SCAttempt` models with relationships
- `SessionService` stub implementation (not functional)
- `StartSessionUseCase` and `EndSessionUseCase` stubs
- `SessionView` basic placeholder UI
- `LogbookView` with session list display
- `SessionsTable` actor for Supabase operations
- `SyncActor` with session sync logic
- `SessionDTO` for Supabase communication
- Environment keys for use case injection

**What Needs Implementation:**
1. Functional `SessionService` actor with SwiftData operations
2. Complete use case implementations
3. Additional use cases (GetActiveSession, ListSessions, DeleteSession)
4. Enhanced UI for active session management
5. Start session flow with readiness capture
6. End session flow with RPE/notes capture
7. Session detail view
8. Supabase table migration (if not already deployed)

---

## Table of Contents

1. [Data Model Design](#1-data-model-design)
2. [Database Layer](#2-database-layer)
3. [Service Layer](#3-service-layer)
4. [Use Cases](#4-use-cases)
5. [UI/UX Design](#5-uiux-design)
6. [Integration Points](#6-integration-points)
7. [Implementation Phases](#7-implementation-phases)
8. [Testing Strategy](#8-testing-strategy)
9. [Risk Assessment](#9-risk-assessment)

---

## 1. Data Model Design

### 1.1 SCSession Model (Existing - Verified Complete)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Models/Session.swift`

The existing model is well-designed and complete:

```swift
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var startedAt: Date
    var endedAt: Date?
    var mentalReadiness: Int?  // 1-5
    var physicalReadiness: Int? // 1-5
    var rpe: Int?              // 1-10 (Rate of Perceived Exertion)
    var pumpLevel: Int?        // 1-5
    var notes: String?
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?       // Soft delete for sync

    @Relationship(deleteRule: .cascade)
    var climbs: [SCClimb]

    var needsSync: Bool        // Sync metadata
}
```

**Computed Properties** (existing):
- `isActive: Bool` - Session is active when `endedAt == nil`
- `duration: TimeInterval?` - Calculated from `startedAt` to `endedAt`
- `attemptCount: Int` - Sum of attempts across all climbs

**Design Decision**: The model is complete. No modifications needed.

### 1.2 Relationships

```
SCSession (1) -----> (*) SCClimb
    |                      |
    |                      v
    |               SCClimb (1) -----> (*) SCAttempt
    |                      |
    |                      v
    |               SCClimb (*) -----> (*) Tags (via Impact tables)
    v
 userId links to SCProfile
```

**Cascade Behavior**:
- Deleting a session deletes all climbs (cascade)
- Deleting a climb deletes all attempts (cascade)
- Soft deletes propagate through sync

### 1.3 Validation Rules

| Field | Validation | Error Message |
|-------|------------|---------------|
| `mentalReadiness` | 1-5 or nil | "Mental readiness must be between 1 and 5" |
| `physicalReadiness` | 1-5 or nil | "Physical readiness must be between 1 and 5" |
| `rpe` | 1-10 or nil | "RPE must be between 1 and 10" |
| `pumpLevel` | 1-5 or nil | "Pump level must be between 1 and 5" |
| `endedAt` | Must be after `startedAt` | "End time must be after start time" |

---

## 2. Database Layer

### 2.1 Supabase Table Schema

**Table**: `sessions`

```sql
-- sessions table (may already exist)
CREATE TABLE IF NOT EXISTS public.sessions (
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_active ON sessions(user_id)
    WHERE ended_at IS NULL AND deleted_at IS NULL;
```

### 2.2 Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own sessions
CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own sessions
CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own sessions
CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete (soft) their own sessions
CREATE POLICY "Users can delete own sessions" ON sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy: Public sessions are viewable by authenticated users
CREATE POLICY "Authenticated users can view public sessions" ON sessions
    FOR SELECT
    USING (
        auth.role() = 'authenticated'
        AND is_private = false
        AND deleted_at IS NULL
    );
```

### 2.3 Migration File

**File**: `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260120_create_sessions_table.sql`

```sql
-- Migration: Create sessions table with RLS
-- Version: 20260120
-- Description: Sets up the sessions table for climbing session tracking

-- Create table (idempotent)
CREATE TABLE IF NOT EXISTS public.sessions (
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_active ON sessions(user_id)
    WHERE ended_at IS NULL AND deleted_at IS NULL;

-- Enable RLS
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (for idempotent re-runs)
DROP POLICY IF EXISTS "Users can view own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON sessions;
DROP POLICY IF EXISTS "Authenticated users can view public sessions" ON sessions;

-- Create policies
CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions" ON sessions
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can view public sessions" ON sessions
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND is_private = false
        AND deleted_at IS NULL
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sessions_updated_at_trigger ON sessions;
CREATE TRIGGER sessions_updated_at_trigger
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_sessions_updated_at();
```

---

## 3. Service Layer

### 3.1 SessionServiceProtocol Enhancement

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/SessionService.swift`

Update the protocol and implement the actor:

```swift
import Foundation
import SwiftData

// MARK: - Errors

enum SessionError: LocalizedError {
    case sessionAlreadyActive
    case sessionNotFound
    case sessionNotActive
    case invalidReadinessValue(Int)
    case invalidRPEValue(Int)
    case invalidPumpLevelValue(Int)
    case endTimeBeforeStartTime

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Cannot start a new session while one is active"
        case .sessionNotFound:
            return "Session not found"
        case .sessionNotActive:
            return "Session is not active"
        case .invalidReadinessValue(let value):
            return "Readiness must be between 1 and 5, got \(value)"
        case .invalidRPEValue(let value):
            return "RPE must be between 1 and 10, got \(value)"
        case .invalidPumpLevelValue(let value):
            return "Pump level must be between 1 and 5, got \(value)"
        case .endTimeBeforeStartTime:
            return "End time must be after start time"
        }
    }
}

// MARK: - Protocol

/// Session lifecycle management
protocol SessionServiceProtocol: Sendable {
    /// Create a new climbing session
    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession

    /// End an active session with feedback
    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws

    /// Get the active session for a user (if any)
    func getActiveSession(userId: UUID) async throws -> SCSession?

    /// Get session history with pagination
    func getSessionHistory(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [SCSession]

    /// Get a specific session by ID
    func getSession(id: UUID) async throws -> SCSession?

    /// Soft delete a session
    func deleteSession(sessionId: UUID) async throws

    /// Update session notes (can be done during active session)
    func updateSessionNotes(sessionId: UUID, notes: String?) async throws
}

// MARK: - Implementation

actor SessionServiceImpl: SessionServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func createSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession {
        // Validate readiness values
        if let mental = mentalReadiness, !(1...5).contains(mental) {
            throw SessionError.invalidReadinessValue(mental)
        }
        if let physical = physicalReadiness, !(1...5).contains(physical) {
            throw SessionError.invalidReadinessValue(physical)
        }

        let context = ModelContext(modelContainer)

        // Check for existing active session
        let predicate = #Predicate<SCSession> { session in
            session.userId == userId &&
            session.endedAt == nil &&
            session.deletedAt == nil
        }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        if let _ = try context.fetch(descriptor).first {
            throw SessionError.sessionAlreadyActive
        }

        // Create new session
        let session = SCSession(
            userId: userId,
            startedAt: Date(),
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness,
            needsSync: true
        )

        context.insert(session)
        try context.save()

        return session
    }

    func endSession(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // Validate values
        if let rpe = rpe, !(1...10).contains(rpe) {
            throw SessionError.invalidRPEValue(rpe)
        }
        if let pump = pumpLevel, !(1...5).contains(pump) {
            throw SessionError.invalidPumpLevelValue(pump)
        }

        let context = ModelContext(modelContainer)

        // Fetch session
        let predicate = #Predicate<SCSession> { $0.id == sessionId }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        guard let session = try context.fetch(descriptor).first else {
            throw SessionError.sessionNotFound
        }

        guard session.endedAt == nil else {
            throw SessionError.sessionNotActive
        }

        // Update session
        let now = Date()
        session.endedAt = now
        session.rpe = rpe
        session.pumpLevel = pumpLevel
        session.notes = notes
        session.updatedAt = now
        session.needsSync = true

        try context.save()
    }

    func getActiveSession(userId: UUID) async throws -> SCSession? {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SCSession> { session in
            session.userId == userId &&
            session.endedAt == nil &&
            session.deletedAt == nil
        }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        return try context.fetch(descriptor).first
    }

    func getSessionHistory(
        userId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [SCSession] {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SCSession> { session in
            session.userId == userId &&
            session.endedAt != nil &&
            session.deletedAt == nil
        }

        var descriptor = FetchDescriptor<SCSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        return try context.fetch(descriptor)
    }

    func getSession(id: UUID) async throws -> SCSession? {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SCSession> { $0.id == id && $0.deletedAt == nil }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        return try context.fetch(descriptor).first
    }

    func deleteSession(sessionId: UUID) async throws {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SCSession> { $0.id == sessionId }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        guard let session = try context.fetch(descriptor).first else {
            throw SessionError.sessionNotFound
        }

        // Soft delete
        let now = Date()
        session.deletedAt = now
        session.updatedAt = now
        session.needsSync = true

        try context.save()
    }

    func updateSessionNotes(sessionId: UUID, notes: String?) async throws {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SCSession> { $0.id == sessionId }
        let descriptor = FetchDescriptor<SCSession>(predicate: predicate)

        guard let session = try context.fetch(descriptor).first else {
            throw SessionError.sessionNotFound
        }

        session.notes = notes
        session.updatedAt = Date()
        session.needsSync = true

        try context.save()
    }
}
```

---

## 4. Use Cases

### 4.1 StartSessionUseCase

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift`

```swift
import Foundation

/// Start a new climbing session
protocol StartSessionUseCaseProtocol: Sendable {
    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession
}

final class StartSessionUseCase: StartSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let syncActor: SyncActor?

    init(sessionService: SessionServiceProtocol, syncActor: SyncActor? = nil) {
        self.sessionService = sessionService
        self.syncActor = syncActor
    }

    func execute(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession {
        // 1. Create session via service (validates and persists)
        let session = try await sessionService.createSession(
            userId: userId,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )

        // 2. Enqueue for background sync
        await syncActor?.enqueue(.insertSession(sessionId: session.id))

        return session
    }
}
```

### 4.2 EndSessionUseCase

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/EndSessionUseCase.swift`

```swift
import Foundation

/// End an active climbing session
protocol EndSessionUseCaseProtocol: Sendable {
    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws
}

final class EndSessionUseCase: EndSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let syncActor: SyncActor?

    init(sessionService: SessionServiceProtocol, syncActor: SyncActor? = nil) {
        self.sessionService = sessionService
        self.syncActor = syncActor
    }

    func execute(
        sessionId: UUID,
        rpe: Int?,
        pumpLevel: Int?,
        notes: String?
    ) async throws {
        // 1. End session via service
        try await sessionService.endSession(
            sessionId: sessionId,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes
        )

        // 2. Enqueue for background sync
        await syncActor?.enqueue(.updateSession(sessionId: sessionId))
    }
}
```

### 4.3 GetActiveSessionUseCase (New)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/GetActiveSessionUseCase.swift`

```swift
import Foundation

/// Get the currently active session for a user
protocol GetActiveSessionUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws -> SCSession?
}

final class GetActiveSessionUseCase: GetActiveSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(userId: UUID) async throws -> SCSession? {
        return try await sessionService.getActiveSession(userId: userId)
    }
}
```

### 4.4 ListSessionsUseCase (New)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/ListSessionsUseCase.swift`

```swift
import Foundation

/// List completed sessions with pagination
protocol ListSessionsUseCaseProtocol: Sendable {
    func execute(userId: UUID, limit: Int, offset: Int) async throws -> [SCSession]
}

final class ListSessionsUseCase: ListSessionsUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol

    init(sessionService: SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func execute(userId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [SCSession] {
        return try await sessionService.getSessionHistory(
            userId: userId,
            limit: limit,
            offset: offset
        )
    }
}
```

### 4.5 DeleteSessionUseCase (New)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/DeleteSessionUseCase.swift`

```swift
import Foundation

/// Soft delete a session
protocol DeleteSessionUseCaseProtocol: Sendable {
    func execute(sessionId: UUID) async throws
}

final class DeleteSessionUseCase: DeleteSessionUseCaseProtocol, Sendable {
    private let sessionService: SessionServiceProtocol
    private let syncActor: SyncActor?

    init(sessionService: SessionServiceProtocol, syncActor: SyncActor? = nil) {
        self.sessionService = sessionService
        self.syncActor = syncActor
    }

    func execute(sessionId: UUID) async throws {
        // 1. Soft delete via service
        try await sessionService.deleteSession(sessionId: sessionId)

        // 2. Enqueue for background sync
        await syncActor?.enqueue(.deleteSession(sessionId: sessionId))
    }
}
```

### 4.6 Environment Keys Addition

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/Environment+UseCases.swift`

Add these new environment keys:

```swift
// MARK: - Get Active Session Use Case

private struct GetActiveSessionUseCaseKey: EnvironmentKey {
    static let defaultValue: GetActiveSessionUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var getActiveSessionUseCase: GetActiveSessionUseCaseProtocol? {
        get { self[GetActiveSessionUseCaseKey.self] }
        set { self[GetActiveSessionUseCaseKey.self] = newValue }
    }
}

// MARK: - List Sessions Use Case

private struct ListSessionsUseCaseKey: EnvironmentKey {
    static let defaultValue: ListSessionsUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var listSessionsUseCase: ListSessionsUseCaseProtocol? {
        get { self[ListSessionsUseCaseKey.self] }
        set { self[ListSessionsUseCaseKey.self] = newValue }
    }
}

// MARK: - Delete Session Use Case

private struct DeleteSessionUseCaseKey: EnvironmentKey {
    static let defaultValue: DeleteSessionUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var deleteSessionUseCase: DeleteSessionUseCaseProtocol? {
        get { self[DeleteSessionUseCaseKey.self] }
        set { self[DeleteSessionUseCaseKey.self] = newValue }
    }
}
```

---

## 5. UI/UX Design

### 5.1 Session Tab View Structure

```
SessionView (Tab)
    |
    +-- EmptyState (no active session)
    |       |
    |       +-- StartSessionSheet
    |               |
    |               +-- ReadinessCapture (optional)
    |
    +-- ActiveSessionView (session active)
            |
            +-- SessionHeader (duration, stats)
            |
            +-- ClimbList (from session.climbs)
            |       |
            |       +-- ClimbRow
            |               |
            |               +-- AttemptPills
            |
            +-- AddClimbButton
            |
            +-- EndSessionButton
                    |
                    +-- EndSessionSheet
                            |
                            +-- RPE Capture
                            +-- Pump Level
                            +-- Notes
```

### 5.2 SessionView (Enhanced)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/SessionView.swift`

```swift
import SwiftUI
import SwiftData

@MainActor
struct SessionView: View {
    // MARK: - SwiftData Query
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt == nil && $0.deletedAt == nil },
        sort: \SCSession.startedAt,
        order: .reverse
    )
    private var activeSessions: [SCSession]

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - State
    @State private var showStartSheet = false
    @State private var showEndSheet = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var activeSession: SCSession? {
        activeSessions.first
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSession {
                    ActiveSessionContent(
                        session: session,
                        onEndSession: { showEndSheet = true }
                    )
                } else {
                    EmptySessionState(onStartSession: { showStartSheet = true })
                }
            }
            .navigationTitle("Session")
            .toolbar {
                if activeSession != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End") {
                            showEndSheet = true
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showStartSheet) {
            StartSessionSheet(
                onStart: startNewSession,
                isLoading: isLoading
            )
        }
        .sheet(isPresented: $showEndSheet) {
            if let session = activeSession {
                EndSessionSheet(
                    session: session,
                    onEnd: endCurrentSession,
                    isLoading: isLoading
                )
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

    // MARK: - Actions

    private func startNewSession(mentalReadiness: Int?, physicalReadiness: Int?) {
        guard let useCase = startSessionUseCase,
              let userId = currentUserId else {
            errorMessage = "Session service not available"
            return
        }

        isLoading = true

        Task {
            do {
                _ = try await useCase.execute(
                    userId: userId,
                    mentalReadiness: mentalReadiness,
                    physicalReadiness: physicalReadiness
                )
                showStartSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func endCurrentSession(rpe: Int?, pumpLevel: Int?, notes: String?) {
        guard let useCase = endSessionUseCase,
              let session = activeSession else {
            errorMessage = "Session service not available"
            return
        }

        isLoading = true

        Task {
            do {
                try await useCase.execute(
                    sessionId: session.id,
                    rpe: rpe,
                    pumpLevel: pumpLevel,
                    notes: notes
                )
                showEndSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

### 5.3 EmptySessionState Component

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/EmptySessionState.swift`

```swift
import SwiftUI

struct EmptySessionState: View {
    let onStartSession: () -> Void

    var body: some View {
        VStack(spacing: SCSpacing.lg) {
            Spacer()

            Image(systemName: "figure.climbing")
                .font(.system(size: 80))
                .foregroundStyle(SCColors.textSecondary)

            VStack(spacing: SCSpacing.sm) {
                Text("Ready to Climb?")
                    .font(SCTypography.screenHeader)

                Text("Start a session to track your climbs and progress")
                    .font(SCTypography.body)
                    .foregroundStyle(SCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SCPrimaryButton(
                title: "Start Session",
                action: onStartSession,
                isFullWidth: true
            )
            .padding(.horizontal, SCSpacing.xl)

            Spacer()
        }
        .padding()
    }
}
```

### 5.4 StartSessionSheet Component

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/StartSessionSheet.swift`

```swift
import SwiftUI

struct StartSessionSheet: View {
    let onStart: (Int?, Int?) -> Void
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var mentalReadiness: Int?
    @State private var physicalReadiness: Int?
    @State private var showReadinessCapture = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SCSpacing.lg) {
                Text("How are you feeling today?")
                    .font(SCTypography.sectionHeader)
                    .padding(.top, SCSpacing.md)

                if showReadinessCapture {
                    readinessSection
                } else {
                    quickStartSection
                }

                Spacer()

                VStack(spacing: SCSpacing.sm) {
                    SCPrimaryButton(
                        title: isLoading ? "Starting..." : "Start Session",
                        action: {
                            onStart(mentalReadiness, physicalReadiness)
                        },
                        isLoading: isLoading,
                        isFullWidth: true
                    )
                    .disabled(isLoading)

                    if !showReadinessCapture {
                        Button("Track my readiness") {
                            withAnimation {
                                showReadinessCapture = true
                            }
                        }
                        .font(SCTypography.secondary)
                    }
                }
                .padding(.horizontal)
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
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var quickStartSection: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Quick Start")
                .font(SCTypography.body)

            Text("Skip readiness tracking and jump right in")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .padding(.vertical, SCSpacing.xl)
    }

    @ViewBuilder
    private var readinessSection: some View {
        VStack(spacing: SCSpacing.lg) {
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
        }
        .padding(.vertical, SCSpacing.md)
    }
}

struct ReadinessSlider: View {
    let title: String
    @Binding var value: Int?
    let icon: String

    private let labels = ["Low", "", "Medium", "", "High"]

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(SCTypography.body.weight(.medium))
                Spacer()
                if let value = value {
                    Text("\(value)/5")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(value ?? 3) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 1...5,
                step: 1
            )

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(SCTypography.caption)
                        .foregroundStyle(SCColors.textSecondary)
                    if index < labels.count - 1 {
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }
}
```

### 5.5 EndSessionSheet Component

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/EndSessionSheet.swift`

```swift
import SwiftUI

struct EndSessionSheet: View {
    let session: SCSession
    let onEnd: (Int?, Int?, String?) -> Void
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rpe: Int = 5
    @State private var pumpLevel: Int = 3
    @State private var notes: String = ""

    private var sessionDuration: String {
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    // Session Summary
                    SCGlassCard {
                        VStack(spacing: SCSpacing.sm) {
                            Text("Session Summary")
                                .font(SCTypography.cardTitle)

                            HStack(spacing: SCSpacing.lg) {
                                StatItem(value: sessionDuration, label: "Duration")
                                StatItem(value: "\(session.climbs.count)", label: "Climbs")
                                StatItem(value: "\(session.attemptCount)", label: "Attempts")
                            }
                        }
                    }

                    // RPE Picker
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Rate of Perceived Exertion")
                            .font(SCTypography.body.weight(.medium))

                        RPEPicker(value: $rpe)
                    }

                    // Pump Level
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Pump Level")
                            .font(SCTypography.body.weight(.medium))

                        PumpLevelPicker(value: $pumpLevel)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Session Notes")
                            .font(SCTypography.body.weight(.medium))

                        TextField("How did it go?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .navigationTitle("End Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onEnd(rpe, pumpLevel, notes.isEmpty ? nil : notes)
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SCTypography.sectionHeader)
            Text(label)
                .font(SCTypography.caption)
                .foregroundStyle(SCColors.textSecondary)
        }
    }
}

struct RPEPicker: View {
    @Binding var value: Int

    var body: some View {
        VStack(spacing: SCSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { rpe in
                    Button {
                        value = rpe
                    } label: {
                        Text("\(rpe)")
                            .font(SCTypography.body.weight(value == rpe ? .bold : .regular))
                            .frame(width: 32, height: 44)
                            .background(value == rpe ? Color.accentColor : SCColors.surfaceSecondary)
                            .foregroundStyle(value == rpe ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Easy")
                Spacer()
                Text("Hard")
            }
            .font(SCTypography.caption)
            .foregroundStyle(SCColors.textSecondary)
        }
    }
}

struct PumpLevelPicker: View {
    @Binding var value: Int

    private let labels = ["None", "Light", "Moderate", "Heavy", "Maxed"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { level in
                Button {
                    value = level
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: pumpIcon(for: level))
                            .font(.title2)
                        Text(labels[level - 1])
                            .font(SCTypography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SCSpacing.sm)
                    .background(value == level ? Color.accentColor.opacity(0.2) : SCColors.surfaceSecondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(value == level ? Color.accentColor : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pumpIcon(for level: Int) -> String {
        switch level {
        case 1: return "drop"
        case 2: return "drop.fill"
        case 3: return "flame"
        case 4: return "flame.fill"
        case 5: return "bolt.fill"
        default: return "drop"
        }
    }
}
```

### 5.6 ActiveSessionContent Component

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift`

```swift
import SwiftUI

struct ActiveSessionContent: View {
    @Bindable var session: SCSession
    let onEndSession: () -> Void

    @State private var showAddClimb = false

    private var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.md) {
                // Session Header
                sessionHeader

                // Quick Stats
                quickStats

                // Climbs List
                if session.climbs.isEmpty {
                    emptyClimbsState
                } else {
                    climbsList
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            addClimbButton
        }
    }

    @ViewBuilder
    private var sessionHeader: some View {
        SCGlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Session")
                        .font(SCTypography.cardTitle)
                    Text("Started \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(elapsedTime)
                        .font(SCTypography.sectionHeader)
                        .monospacedDigit()
                    Text("elapsed")
                        .font(SCTypography.caption)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var quickStats: some View {
        HStack(spacing: SCSpacing.md) {
            if let mental = session.mentalReadiness {
                SCMetricPill(
                    icon: "brain.head.profile",
                    value: "\(mental)/5",
                    label: "Mental"
                )
            }

            if let physical = session.physicalReadiness {
                SCMetricPill(
                    icon: "figure.stand",
                    value: "\(physical)/5",
                    label: "Physical"
                )
            }

            SCMetricPill(
                icon: "number",
                value: "\(session.climbs.count)",
                label: "Climbs"
            )

            SCMetricPill(
                icon: "arrow.counterclockwise",
                value: "\(session.attemptCount)",
                label: "Attempts"
            )
        }
    }

    @ViewBuilder
    private var emptyClimbsState: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 50))
                .foregroundStyle(SCColors.textSecondary)

            Text("No climbs yet")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Tap below to add your first climb")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SCSpacing.xl)
    }

    @ViewBuilder
    private var climbsList: some View {
        LazyVStack(spacing: SCSpacing.sm) {
            ForEach(session.climbs.filter { $0.deletedAt == nil }) { climb in
                ClimbRow(climb: climb)
            }
        }
    }

    @ViewBuilder
    private var addClimbButton: some View {
        SCPrimaryButton(
            title: "Add Climb",
            action: { showAddClimb = true },
            isFullWidth: true
        )
        .padding()
        .background(.regularMaterial)
    }
}

struct ClimbRow: View {
    let climb: SCClimb

    var body: some View {
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
                }

                // Attempt pills
                HStack(spacing: 4) {
                    ForEach(climb.attempts.sorted(by: { $0.attemptNumber < $1.attemptNumber })) { attempt in
                        AttemptPill(attempt: attempt)
                    }
                }
            }
        }
    }
}

struct AttemptPill: View {
    let attempt: SCAttempt

    var body: some View {
        Image(systemName: attempt.isSend ? "checkmark.circle.fill" : "xmark.circle")
            .font(.caption)
            .foregroundStyle(attempt.isSend ? .green : .red)
            .padding(4)
            .background(
                (attempt.isSend ? Color.green : Color.red).opacity(0.1)
            )
            .cornerRadius(4)
    }
}
```

### 5.7 Session Detail View (for Logbook)

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/SessionDetailView.swift`

```swift
import SwiftUI

struct SessionDetailView: View {
    let session: SCSession

    @Environment(\.deleteSessionUseCase) private var deleteSessionUseCase
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var formattedDuration: String {
        guard let duration = session.duration else { return "N/A" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.lg) {
                // Header Card
                headerCard

                // Metrics
                metricsSection

                // Climbs
                climbsSection

                // Notes
                if let notes = session.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("This will delete the session and all its climbs. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        SCGlassCard {
            VStack(spacing: SCSpacing.sm) {
                if let endedAt = session.endedAt {
                    Text(endedAt.formatted(date: .long, time: .shortened))
                        .font(SCTypography.sectionHeader)
                }

                HStack(spacing: SCSpacing.lg) {
                    StatBlock(value: formattedDuration, label: "Duration")
                    StatBlock(value: "\(session.climbs.count)", label: "Climbs")
                    StatBlock(value: "\(session.attemptCount)", label: "Attempts")
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Metrics")
                .font(SCTypography.cardTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SCSpacing.sm) {
                if let mental = session.mentalReadiness {
                    MetricCard(
                        icon: "brain.head.profile",
                        title: "Mental Readiness",
                        value: "\(mental)/5"
                    )
                }

                if let physical = session.physicalReadiness {
                    MetricCard(
                        icon: "figure.stand",
                        title: "Physical Readiness",
                        value: "\(physical)/5"
                    )
                }

                if let rpe = session.rpe {
                    MetricCard(
                        icon: "heart.fill",
                        title: "RPE",
                        value: "\(rpe)/10"
                    )
                }

                if let pump = session.pumpLevel {
                    MetricCard(
                        icon: "flame.fill",
                        title: "Pump Level",
                        value: "\(pump)/5"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var climbsSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Climbs")
                .font(SCTypography.cardTitle)

            if session.climbs.isEmpty {
                Text("No climbs logged")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(session.climbs.filter { $0.deletedAt == nil }) { climb in
                    ClimbRow(climb: climb)
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Notes")
                .font(SCTypography.cardTitle)

            Text(notes)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(SCColors.surfaceSecondary)
                .cornerRadius(SCCornerRadius.card)
        }
    }

    private func deleteSession() {
        guard let useCase = deleteSessionUseCase else { return }

        isDeleting = true

        Task {
            do {
                try await useCase.execute(sessionId: session.id)
                dismiss()
            } catch {
                // Handle error - session might already be deleted
            }
            isDeleting = false
        }
    }
}

private struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SCTypography.sectionHeader)
            Text(label)
                .font(SCTypography.caption)
                .foregroundStyle(SCColors.textSecondary)
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: SCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SCTypography.caption)
                    .foregroundStyle(SCColors.textSecondary)
                Text(value)
                    .font(SCTypography.body.weight(.semibold))
            }

            Spacer()
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }
}
```

---

## 6. Integration Points

### 6.1 Climb Integration

Sessions and climbs are tightly coupled:

```swift
// When adding a climb, it must reference the active session
func addClimbToSession(session: SCSession, climb: SCClimb) {
    climb.sessionId = session.id
    session.climbs.append(climb)
}

// Views should show climbs within session context
@Query(
    filter: #Predicate<SCClimb> { climb in
        climb.sessionId == activeSessionId && climb.deletedAt == nil
    }
)
var sessionClimbs: [SCClimb]
```

### 6.2 Sync Integration

The existing `SyncActor` already handles session sync. The `SyncOperation` enum needs these cases:

```swift
enum SyncOperation: Sendable {
    case insertSession(sessionId: UUID)
    case updateSession(sessionId: UUID)
    case deleteSession(sessionId: UUID)
    // ... other operations
}
```

### 6.3 Future Integration Points

| Feature | Integration Point |
|---------|-------------------|
| **Location** | Add `locationId: UUID?` to SCSession for gym/crag association |
| **Weather** | Fetch weather at session start, store in new columns |
| **Photos** | Add `photoURLs: [String]` to SCSession |
| **Live Activity** | Create ActivityKit integration for active sessions |
| **Apple Watch** | Share active session state via WatchConnectivity |

---

## 7. Implementation Phases

### Phase 1: Core Service Implementation (Priority: HIGH) ✅

**Duration**: 2-3 hours
**Status**: COMPLETED
**Files to modify/create**:

1. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/Services/SessionService.swift`
   - Replace stub with full `SessionServiceImpl` actor ✅
   - Add `SessionError` enum ✅

2. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Core/Sync/SyncOperation.swift`
   - Add session sync operation cases if missing ✅

**Acceptance Criteria**:
- [x] `SessionServiceImpl` creates sessions with validation
- [x] `SessionServiceImpl` ends sessions with validation
- [x] `SessionServiceImpl` queries active session correctly
- [x] `SessionServiceImpl` lists session history with pagination
- [x] `SessionServiceImpl` soft deletes sessions
- [x] All operations mark `needsSync = true`

**Implementation Notes**:
- Implemented as `SessionService` actor with `@MainActor` context access
- All validation logic in place (readiness 1-5, RPE 1-10, pump level 1-5)
- Active session check prevents duplicate sessions
- Uses `FetchDescriptor` with predicates for all queries
- Returns UUIDs instead of full entities for better separation of concerns

### Phase 2: Use Case Completion (Priority: HIGH) ✅

**Duration**: 1-2 hours
**Status**: COMPLETED
**Files to modify/create**:

1. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/StartSessionUseCase.swift`
   - Complete implementation with sync integration ✅

2. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/EndSessionUseCase.swift`
   - Complete implementation with sync integration ✅

3. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/GetActiveSessionUseCase.swift` (NEW) ✅

4. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/ListSessionsUseCase.swift` (NEW) ✅

5. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Domain/UseCases/DeleteSessionUseCase.swift` (NEW) ✅

6. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/Environment+UseCases.swift`
   - Add new environment keys ✅

7. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/App/SwiftClimbApp.swift`
   - Wire up new use cases in dependency injection ✅

**Acceptance Criteria**:
- [x] All use cases implemented with proper error handling
- [x] Use cases enqueue sync operations (via needsSync flag)
- [x] Environment keys accessible in views
- [x] Use cases wired up in SwiftClimbApp

**Implementation Notes**:
- All use cases follow Sendable protocol pattern
- Sync happens automatically via needsSync flag (SyncActor polls for changes)
- Use cases are thin wrappers around SessionService
- Environment keys properly typed and documented

### Phase 3: UI Implementation (Priority: HIGH) ✅

**Duration**: 3-4 hours
**Status**: COMPLETED
**Files to modify/create**:

1. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/SessionView.swift`
   - Enhanced with sheet presentation ✅

2. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/EmptySessionState.swift` (NEW) ✅

3. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/StartSessionSheet.swift` (NEW) ✅

4. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/EndSessionSheet.swift` (NEW) ✅

5. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/Components/ActiveSessionContent.swift` (NEW) ✅

6. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Session/SessionDetailView.swift` (NEW) ✅

**Acceptance Criteria**:
- [x] Empty state shows with "Start Session" CTA
- [x] Start session sheet captures optional readiness
- [x] Active session shows duration, stats, climbs
- [x] End session sheet captures RPE, pump level, notes
- [x] Session detail view shows full session info
- [x] All UI follows design system tokens

**Implementation Notes**:
- SessionView uses @Query for reactive UI updates
- Sheets properly use @Bindable for SCSession
- ActiveSessionContent displays real-time elapsed time
- MetricStatPill component for consistent stat display
- ClimbRow and AttemptPill provide visual climb feedback
- All components use SCTypography, SCColors, SCSpacing tokens

### Phase 4: Logbook Enhancement (Priority: MEDIUM)

**Duration**: 1-2 hours
**Files to modify**:

1. `/Users/skelley/Projects/SwiftClimb/SwiftClimb/Features/Logbook/LogbookView.swift`
   - Add navigation to SessionDetailView
   - Add swipe-to-delete

**Acceptance Criteria**:
- [ ] Tapping session row navigates to detail
- [ ] Swipe-to-delete with confirmation
- [ ] Premium gating preserved

### Phase 5: Database Migration (Priority: HIGH - if not deployed) ✅

**Duration**: 30 minutes
**Status**: COMPLETED
**Files to create**:

1. `/Users/skelley/Projects/SwiftClimb/Database/migrations/20260120_create_sessions_table.sql` ✅

**Acceptance Criteria**:
- [x] Table created with all columns
- [x] RLS policies applied
- [x] Indexes created
- [x] Updated_at trigger created

**Implementation Notes**:
- Migration is idempotent (uses IF NOT EXISTS)
- Five RLS policies: own sessions (CRUD), public sessions (SELECT)
- Four indexes: user_id, started_at, updated_at, active sessions composite
- Automatic updated_at trigger on row updates
- Database constraints match SwiftData validation (readiness 1-5, RPE 1-10, etc.)

---

## 8. Testing Strategy

### 8.1 Unit Tests

**File**: `/Users/skelley/Projects/SwiftClimb/SwiftClimbTests/SessionServiceTests.swift`

```swift
@Suite("SessionService Tests")
struct SessionServiceTests {
    @Test("Creating a session succeeds with valid data")
    func createSessionSuccess() async throws {
        let container = try ModelContainer(for: SCSession.self, configurations: .init(isStoredInMemoryOnly: true))
        let service = SessionServiceImpl(modelContainer: container)

        let session = try await service.createSession(
            userId: UUID(),
            mentalReadiness: 4,
            physicalReadiness: 5
        )

        #expect(session.mentalReadiness == 4)
        #expect(session.physicalReadiness == 5)
        #expect(session.isActive)
        #expect(session.needsSync)
    }

    @Test("Creating a session fails with invalid readiness")
    func createSessionInvalidReadiness() async {
        let container = try! ModelContainer(for: SCSession.self, configurations: .init(isStoredInMemoryOnly: true))
        let service = SessionServiceImpl(modelContainer: container)

        await #expect(throws: SessionError.self) {
            try await service.createSession(
                userId: UUID(),
                mentalReadiness: 10,  // Invalid
                physicalReadiness: 5
            )
        }
    }

    @Test("Cannot start session when one is already active")
    func cannotStartDuplicateSession() async throws {
        let container = try ModelContainer(for: SCSession.self, configurations: .init(isStoredInMemoryOnly: true))
        let service = SessionServiceImpl(modelContainer: container)
        let userId = UUID()

        // Start first session
        _ = try await service.createSession(
            userId: userId,
            mentalReadiness: nil,
            physicalReadiness: nil
        )

        // Try to start second session
        await #expect(throws: SessionError.sessionAlreadyActive) {
            try await service.createSession(
                userId: userId,
                mentalReadiness: nil,
                physicalReadiness: nil
            )
        }
    }

    @Test("Ending a session sets endedAt and metrics")
    func endSessionSuccess() async throws {
        let container = try ModelContainer(for: SCSession.self, configurations: .init(isStoredInMemoryOnly: true))
        let service = SessionServiceImpl(modelContainer: container)

        let session = try await service.createSession(
            userId: UUID(),
            mentalReadiness: nil,
            physicalReadiness: nil
        )

        try await service.endSession(
            sessionId: session.id,
            rpe: 7,
            pumpLevel: 3,
            notes: "Great session!"
        )

        let updated = try await service.getSession(id: session.id)
        #expect(updated?.endedAt != nil)
        #expect(updated?.rpe == 7)
        #expect(updated?.pumpLevel == 3)
        #expect(updated?.notes == "Great session!")
    }
}
```

### 8.2 Integration Tests

Test sync flow with mock Supabase:

```swift
@Suite("Session Sync Tests")
struct SessionSyncTests {
    @Test("Session marked needsSync after creation")
    func sessionNeedsSyncAfterCreate() async throws {
        // Test that needsSync is true after creation
    }

    @Test("Session needsSync cleared after successful sync")
    func sessionSyncClears() async throws {
        // Test sync clears needsSync flag
    }
}
```

### 8.3 UI Tests

Manual testing checklist:

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

---

## 9. Risk Assessment

### High Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftData relationship issues | Data corruption | Test cascade deletes thoroughly |
| Concurrent session state | UI inconsistency | Use @Query for reactive updates |
| Sync conflicts | Data loss | Last-write-wins with needsSync priority |

### Medium Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Performance with many climbs | UI lag | Use LazyVStack, limit initial fetch |
| Validation bypass | Invalid data | Validate at service level |
| Timer updates | Battery drain | Use minimal update interval (1 min) |

### Low Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| UI accessibility | Unusable for some users | Use semantic typography, tap targets |
| Network offline during end | UX confusion | Show sync status indicator |

---

## Appendix A: File Inventory

### Files to Create

| File | Purpose |
|------|---------|
| `Features/Session/Components/EmptySessionState.swift` | Empty state UI |
| `Features/Session/Components/StartSessionSheet.swift` | Start flow UI |
| `Features/Session/Components/EndSessionSheet.swift` | End flow UI |
| `Features/Session/Components/ActiveSessionContent.swift` | Active session UI |
| `Features/Session/SessionDetailView.swift` | Session detail for logbook |
| `Domain/UseCases/GetActiveSessionUseCase.swift` | Get active session |
| `Domain/UseCases/ListSessionsUseCase.swift` | List sessions |
| `Domain/UseCases/DeleteSessionUseCase.swift` | Delete session |
| `Database/migrations/20260120_create_sessions_table.sql` | Supabase migration |

### Files to Modify

| File | Changes |
|------|---------|
| `Domain/Services/SessionService.swift` | Replace stub with actor implementation |
| `Domain/UseCases/StartSessionUseCase.swift` | Complete implementation |
| `Domain/UseCases/EndSessionUseCase.swift` | Complete implementation |
| `Features/Session/SessionView.swift` | Enhanced with sheets |
| `Features/Logbook/LogbookView.swift` | Add navigation to detail |
| `App/Environment+UseCases.swift` | Add new environment keys |
| `App/SwiftClimbApp.swift` | Wire up new use cases |
| `Core/Sync/SyncOperation.swift` | Add session operations (if missing) |

---

## Appendix B: Dependency Graph

```
SwiftClimbApp
    |
    +-- SessionServiceImpl (actor)
    |       |
    |       +-- ModelContainer
    |
    +-- StartSessionUseCase
    |       |
    |       +-- SessionServiceImpl
    |       +-- SyncActor
    |
    +-- EndSessionUseCase
    |       |
    |       +-- SessionServiceImpl
    |       +-- SyncActor
    |
    +-- DeleteSessionUseCase
    |       |
    |       +-- SessionServiceImpl
    |       +-- SyncActor
    |
    +-- SessionView
            |
            +-- @Query<SCSession>
            +-- StartSessionUseCase (via Environment)
            +-- EndSessionUseCase (via Environment)
```

---

**Document Status**: Ready for Implementation
**Next Steps**: Begin Phase 1 (Core Service Implementation)
**Estimated Total Effort**: 8-12 hours
