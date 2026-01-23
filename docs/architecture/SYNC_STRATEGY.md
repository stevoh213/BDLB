# Sync Strategy Guide

This document explains SwiftClimb's offline-first synchronization strategy in detail, including implementation patterns, edge cases, and troubleshooting.

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Write Path](#write-path)
4. [Read Path](#read-path)
5. [Pull Sync](#pull-sync)
6. [Push Sync](#push-sync)
7. [Conflict Resolution](#conflict-resolution)
8. [Soft Deletes](#soft-deletes)
9. [Retry Strategy](#retry-strategy)
10. [Edge Cases](#edge-cases)
11. [Troubleshooting](#troubleshooting)

---

## Overview

### Core Principle
> **SwiftData is the source of truth for the UI. Supabase is the system of record for multi-device sync.**

This means:
- All UI reads come from SwiftData
- All user writes go to SwiftData first
- Sync to Supabase happens asynchronously in the background
- Network failures never block the user

### Benefits
- ✅ Instant UI feedback (< 100ms writes)
- ✅ Works completely offline
- ✅ Resilient to network failures
- ✅ Predictable user experience
- ✅ Battery efficient (batched sync)

### Trade-offs
- ⚠️ Eventual consistency (brief staleness possible)
- ⚠️ Conflict resolution needed (last-write-wins)
- ⚠️ Storage overhead (local + remote)
- ⚠️ Sync state management complexity

---

## Architecture

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         User Action                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │      SwiftUI View              │
        │         (@MainActor)           │
        └────────────────┬───────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │         UseCase                │
        └────────────────┬───────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │         Service                │
        └───────┬──────────────────┬─────┘
                │                  │
         1. Local write     2. Enqueue sync
         (< 100ms)          (background)
                │                  │
                ▼                  ▼
    ┌───────────────────┐  ┌─────────────┐
    │    SwiftData      │  │  SyncActor  │
    │  (ModelContext)   │  └──────┬──────┘
    └─────────┬─────────┘         │
              │                   │ 3. Push when online
              │                   ▼
              │          ┌─────────────────┐
              │          │ SupabaseClient  │
              │          └────────┬────────┘
              │                   │
              │                   ▼
              │          ┌─────────────────┐
              │          │    Supabase     │
              │          │    Postgres     │
              │          └────────┬────────┘
              │                   │
              │ 4. Pull updates   │
              │   (periodic)      │
              │◄──────────────────┘
              │
              ▼
    ┌───────────────────┐
    │   SwiftUI View    │
    │  (auto-updates)   │
    └───────────────────┘
```

### Key Components

**SyncActor**: Coordinates all sync operations
- Manages sync state (last sync timestamp, in-flight operations)
- Queues pending changes
- Executes pull and push operations
- Handles retry logic

**SupabaseClientActor**: Manages backend communication
- Handles authentication
- Executes HTTP requests
- Manages auth token refresh

**ChangeTracker**: Detects SwiftData changes
- Monitors `needsSync` flag
- Notifies SyncActor of pending changes

**ConflictResolver**: Resolves sync conflicts
- Implements last-write-wins strategy
- Compares timestamps
- Merges remote changes into local data

---

## Write Path

When a user creates, updates, or deletes data:

### Step 1: Immediate Local Write

```swift
actor SessionService: SessionServiceProtocol {
    private let modelContext: ModelContext

    func createSession(...) async throws -> SCSession {
        // Create model
        let session = SCSession(
            userId: userId,
            startedAt: Date(),
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness,
            needsSync: true  // Mark for sync
        )

        // Insert into SwiftData
        modelContext.insert(session)

        // Save immediately (< 100ms)
        try modelContext.save()

        return session
    }
}
```

**Key Points**:
- SwiftData write completes in < 100ms (requirement)
- `needsSync = true` marks record for background sync
- UI updates immediately from SwiftData

### Step 2: Enqueue for Background Sync

```swift
final class StartSessionUseCase: Sendable {
    private let sessionService: SessionServiceProtocol
    private let syncActor: SyncActor

    func execute(...) async throws -> SCSession {
        // 1. Write to SwiftData (from service)
        let session = try await sessionService.createSession(...)

        // 2. Enqueue for background sync
        await syncActor.enqueue(.insertSession(session.id))

        return session
    }
}
```

**Key Points**:
- UseCase coordinates between service and sync
- Enqueue operation is non-blocking
- User sees result immediately, sync happens later

### Step 3: Background Push (When Online)

```swift
actor SyncActor {
    func pushPendingChanges() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // 1. Fetch records where needsSync == true
        let pending = await fetchPendingRecords()

        // 2. Push to Supabase
        for record in pending {
            do {
                try await supabaseClient.upsert(record)

                // 3. Clear needsSync flag on success
                record.needsSync = false
                try await modelContext.save()
            } catch {
                // 4. Add to retry queue on failure
                retryQueue.append(record)
            }
        }
    }
}
```

**Key Points**:
- Happens in background (doesn't block UI)
- Batches multiple changes for efficiency
- Failures are queued for retry
- Success clears `needsSync` flag

---

## Read Path

### UI Always Reads from SwiftData

```swift
struct LogbookView: View {
    @Query(
        filter: #Predicate<SCSession> {
            $0.deletedAt == nil  // Exclude soft-deleted
        },
        sort: \.startedAt,
        order: .reverse
    )
    var sessions: [SCSession]

    var body: some View {
        List(sessions) { session in
            SessionRow(session: session)
        }
    }
}
```

**Key Points**:
- `@Query` automatically observes changes
- View re-renders when SwiftData updates
- Never blocks on network
- Always shows current local state

### Background Pull Updates SwiftData

When sync pulls new data from Supabase, it merges into SwiftData:

```swift
actor SyncActor {
    func pullUpdates() async throws {
        // 1. Query Supabase for updates since last sync
        let lastSync = lastSyncAt ?? Date.distantPast
        let safetyWindow: TimeInterval = 5 * 60  // 5 minutes

        let updates = try await supabaseClient.fetchUpdates(
            since: lastSync.addingTimeInterval(-safetyWindow)
        )

        // 2. Merge into SwiftData
        for remoteRecord in updates {
            let localRecord = await findLocal(id: remoteRecord.id)

            if let local = localRecord {
                // Conflict: Both local and remote exist
                await conflictResolver.resolve(
                    local: local,
                    remote: remoteRecord
                )
            } else {
                // New record from remote
                await insertFromRemote(remoteRecord)
            }
        }

        // 3. Update last sync timestamp
        lastSyncAt = Date()
    }
}
```

**Key Points**:
- Pull happens in background (app foreground, manual refresh, periodic)
- 5-minute safety window prevents clock skew issues
- Conflict resolution handles concurrent edits
- UI updates automatically via SwiftData observation

---

## Pull Sync

### When Pull Happens

1. **App Foreground**: When app becomes active
2. **Manual Refresh**: User pulls to refresh
3. **Periodic Timer**: Every N minutes (configurable)

```swift
// In app lifecycle
struct SwiftClimbApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    try? await syncActor.pullUpdates()
                }
            }
        }
    }
}
```

### Query Strategy

```sql
-- Supabase query (conceptual)
SELECT * FROM sessions
WHERE updated_at > :lastSyncAt - INTERVAL '5 minutes'
  AND (deleted_at IS NULL OR deleted_at > :lastSyncAt)
ORDER BY updated_at ASC
```

**Why 5-minute safety window?**
- Device clocks can be slightly off
- Server timestamps might differ from client
- Ensures we don't miss records due to clock skew

### Handling Pagination

For large data sets, paginate:

```swift
actor SyncActor {
    private let pageSize = 100

    func pullUpdates() async throws {
        var offset = 0
        var hasMore = true

        while hasMore {
            let updates = try await supabaseClient.fetchUpdates(
                since: lastSyncAt,
                limit: pageSize,
                offset: offset
            )

            for record in updates {
                await merge(record)
            }

            hasMore = updates.count == pageSize
            offset += pageSize
        }
    }
}
```

---

## Push Sync

### When Push Happens

1. **After Write**: Immediately after user action
2. **Retry Timer**: Exponential backoff for failures
3. **App Foreground**: Retry pending operations

### Batch Operations

```swift
actor SyncActor {
    func pushPendingChanges() async throws {
        // 1. Group by table for dependency order
        let pendingByTable = await groupPendingByTable()

        // 2. Push in dependency order (profiles → sessions → climbs → attempts)
        for table in dependencyOrder {
            guard let records = pendingByTable[table] else { continue }

            // 3. Batch upserts
            try await supabaseClient.batchUpsert(
                table: table,
                records: records
            )

            // 4. Clear needsSync on success
            for record in records {
                record.needsSync = false
            }
            try await modelContext.save()
        }
    }
}
```

**Dependency Order**:
```
1. profiles       (root)
2. sessions       (depends on profile)
3. climbs         (depends on session)
4. attempts       (depends on climb)
5. tags           (reference data, read-only)
6. climb_impacts  (depends on climbs + tags)
7. follows        (depends on profiles)
8. posts          (depends on profiles)
9. kudos          (depends on posts)
10. comments      (depends on posts)
```

### Handling Foreign Key Violations

```swift
// If climb push fails due to missing session:
do {
    try await supabaseClient.upsert(climb)
} catch SupabaseError.foreignKeyViolation(let key) {
    if key == "session_id" {
        // Session hasn't synced yet, retry later
        retryQueue.append(.insertClimb(climb.id))
    }
}
```

---

## Conflict Resolution

### Last-Write-Wins Strategy

When both local and remote have changes:

```swift
actor ConflictResolver {
    func resolve(
        local: SCSession,
        remote: SessionDTO
    ) async {
        // Case 1: Local has pending changes (needsSync = true)
        if local.needsSync {
            // Local wins - our change is newer or not yet pushed
            // Don't overwrite with remote
            return
        }

        // Case 2: Remote is newer
        if remote.updated_at > local.updatedAt {
            // Remote wins - merge remote into local
            local.endedAt = remote.ended_at
            local.rpe = remote.rpe
            local.pumpLevel = remote.pump_level
            local.notes = remote.notes
            local.updatedAt = remote.updated_at
            // needsSync stays false (already synced)
        }

        // Case 3: Local is newer (local.updatedAt > remote.updated_at)
        // Local wins - do nothing, our data is fresher
    }
}
```

### Conflict Scenarios

**Scenario 1: Edit on Two Devices While Offline**

Device A:
- Edits session at 10:00 AM
- Marks `needsSync = true`
- Goes offline

Device B:
- Edits same session at 10:05 AM
- Marks `needsSync = true`
- Pushes to Supabase → `updated_at = 10:05`

Device A comes online:
- Pulls updates, sees remote `updated_at = 10:05`
- Local has `needsSync = true` (pending change)
- **Local wins** (local.needsSync takes precedence)
- Device A pushes → `updated_at = 10:06`
- Device A's change wins (last write wins)

**Scenario 2: Concurrent Adds (No Conflict)**

Both devices add attempts to same climb:
- Attempts have unique UUIDs
- Both sync successfully
- No conflict (different records)

**Scenario 3: Clock Skew**

Device clock is 10 minutes fast:
- Local write creates `updatedAt = 10:10`
- Server timestamp on push is `updated_at = 10:00` (server time)
- Pull sees remote `updated_at = 10:00`
- Local `updatedAt = 10:10` (incorrect, future)
- **Mitigated**: Server timestamp is authoritative on push
- When pushing, client should update local `updatedAt` to server's `updated_at`

---

## Soft Deletes

### Why Soft Deletes?

Hard deletes don't sync well:
- If Device A deletes a record, Device B needs to know it was deleted
- Hard delete leaves no trace
- Device B would re-create the record on next push

Soft deletes use `deleted_at` timestamp:
- Deleted records remain in database with `deleted_at != NULL`
- Syncs propagate the deletion
- All devices eventually mark record as deleted

### Implementation

**Delete Operation**:
```swift
actor SessionService {
    func deleteSession(sessionId: UUID) async throws {
        let session = try await fetch(id: sessionId)

        // Soft delete: Set deleted_at
        session.deletedAt = Date()
        session.needsSync = true  // Mark for sync

        try modelContext.save()

        // Background sync will push deleted_at to Supabase
    }
}
```

**Query Filter** (exclude deleted):
```swift
@Query(
    filter: #Predicate<SCSession> {
        $0.deletedAt == nil  // Only show non-deleted
    }
)
var sessions: [SCSession]
```

**Sync Pull** (propagate deletes):
```swift
// Remote has deleted_at = 2024-01-18 10:00
// Local has deleted_at = nil

// Conflict resolution:
if remote.deleted_at != nil {
    local.deletedAt = remote.deleted_at
    local.needsSync = false
}
```

### Permanent Deletion

Eventually, soft-deleted records should be hard-deleted:
- Admin task: Hard delete where `deleted_at < 90 days ago`
- Reduces database size
- Not implemented in MVP

### Unique Constraints with Soft Deletes

**Problem**: Standard UNIQUE constraints block inserts when soft-deleted records exist.

**Example Scenario**:
```sql
-- Table with UNIQUE constraint
CREATE TABLE technique_impacts (
    user_id UUID NOT NULL,
    climb_id UUID NOT NULL,
    tag_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE (user_id, climb_id, tag_id)  -- ❌ Blocks soft-deleted records
);

-- User adds tag to climb
INSERT INTO technique_impacts (user_id, climb_id, tag_id) VALUES (...);

-- User removes tag (soft delete)
UPDATE technique_impacts SET deleted_at = NOW() WHERE ...;

-- User adds same tag again
INSERT INTO technique_impacts (user_id, climb_id, tag_id) VALUES (...);
-- ERROR: duplicate key value violates unique constraint
-- The soft-deleted record still blocks the insert!
```

**Solution**: Use partial unique indexes instead of UNIQUE constraints.

```sql
-- Drop the standard UNIQUE constraint
ALTER TABLE technique_impacts
    DROP CONSTRAINT IF EXISTS technique_impacts_user_id_climb_id_tag_id_key;

-- Add partial unique index that excludes soft-deleted records
CREATE UNIQUE INDEX technique_impacts_user_climb_tag_unique
    ON technique_impacts (user_id, climb_id, tag_id)
    WHERE deleted_at IS NULL;
```

**Benefits**:
- Uniqueness enforced only for active records (`deleted_at IS NULL`)
- Soft-deleted records don't block new inserts
- Multiple soft-deleted records can exist with same key
- New insert allowed after soft delete

**Applied To**:
- `technique_impacts` table (hold type tags)
- `skill_impacts` table (skill tags)
- `wall_style_impacts` table (wall style tags)

**Migration**: See `Database/migrations/20260123_fix_impact_unique_constraints.sql`

**Troubleshooting**:
If sync fails with "409 Conflict" errors on tag impacts, verify that partial unique indexes are in place:
```sql
-- Check for partial unique indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('technique_impacts', 'skill_impacts', 'wall_style_impacts')
  AND indexdef LIKE '%WHERE deleted_at IS NULL%';
```

---

## Retry Strategy

### Exponential Backoff

```swift
struct RetryPolicy {
    let maxAttempts: Int = 5
    let baseDelay: TimeInterval = 1.0  // 1 second
    let maxDelay: TimeInterval = 60.0  // 1 minute
    let jitter: Double = 0.1  // 10% jitter

    func delay(for attempt: Int) -> TimeInterval {
        // Exponential: 1s, 2s, 4s, 8s, 16s, ... (capped at 60s)
        let exponential = baseDelay * pow(2.0, Double(attempt - 1))
        let clamped = min(exponential, maxDelay)

        // Add jitter to prevent thundering herd
        let jitterRange = clamped * jitter
        let randomJitter = Double.random(in: -jitterRange...jitterRange)

        return clamped + randomJitter
    }
}
```

### Retry Implementation

```swift
actor SyncActor {
    private var retryQueue: [SyncOperation] = []
    private let retryPolicy = RetryPolicy()

    func pushPendingChanges() async throws {
        for operation in retryQueue {
            let delay = retryPolicy.delay(for: operation.attemptCount)

            // Wait before retry
            try await Task.sleep(for: .seconds(delay))

            do {
                try await execute(operation)

                // Success: Remove from queue
                retryQueue.removeAll { $0.id == operation.id }
            } catch {
                // Failure: Increment attempt count
                operation.attemptCount += 1

                // Give up after max attempts
                if operation.attemptCount >= retryPolicy.maxAttempts {
                    // Log failure, notify user
                    await logSyncFailure(operation)
                    retryQueue.removeAll { $0.id == operation.id }
                }
            }
        }
    }
}
```

### Retry Triggers

1. **Network Error**: Retry immediately (with backoff)
2. **Server Error (5xx)**: Retry with backoff
3. **Client Error (4xx)**: Don't retry (likely permanent failure)
4. **Auth Error (401)**: Refresh token, then retry

```swift
switch error {
case NetworkError.noConnection:
    // Retry when connection restored
    retryQueue.append(operation)

case NetworkError.serverError(500...599):
    // Server error, retry with backoff
    retryQueue.append(operation)

case NetworkError.unauthorized:
    // Refresh auth token
    try await authManager.refreshToken()
    // Then retry
    retryQueue.append(operation)

case NetworkError.clientError(400...499):
    // Client error (likely bad data), don't retry
    await logError(operation, error)
    // Don't add to retry queue

default:
    retryQueue.append(operation)
}
```

---

## Edge Cases

### Edge Case 1: Rapid Edits

User makes multiple rapid edits to same record:

```swift
// Edit 1: Set rpe = 5
session.rpe = 5
session.needsSync = true
try modelContext.save()
await syncActor.enqueue(.updateSession(session.id))

// Edit 2 (before sync completes): Set rpe = 6
session.rpe = 6
session.needsSync = true  // Still true
try modelContext.save()
// Don't enqueue again (already pending)
```

**Solution**: Check if operation already pending:
```swift
actor SyncActor {
    private var pendingOperations: Set<UUID> = []

    func enqueue(_ operation: SyncOperation) {
        guard !pendingOperations.contains(operation.recordId) else {
            return  // Already pending
        }

        pendingOperations.insert(operation.recordId)
        retryQueue.append(operation)
    }
}
```

### Edge Case 2: User Logs Out Mid-Sync

User logs out while sync is in progress:

```swift
actor SyncActor {
    func cancelAll() {
        // Cancel in-flight tasks
        currentTask?.cancel()

        // Clear retry queue
        retryQueue.removeAll()

        // Reset state
        lastSyncAt = nil
        isSyncing = false
    }
}

// In logout flow:
await syncActor.cancelAll()
```

### Edge Case 3: App Killed During Sync

App is killed while sync operation is in progress:

**Prevention**: Use Background Tasks API
```swift
import BackgroundTasks

BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.swiftclimb.sync",
    using: nil
) { task in
    Task {
        try await syncActor.pushPendingChanges()
        task.setTaskCompleted(success: true)
    }
}
```

**Recovery**: On next launch, resume from `needsSync` records:
```swift
// App launch
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    Task {
        // Resume sync for any records with needsSync = true
        try await syncActor.pushPendingChanges()
    }
}
```

### Edge Case 4: Large Binary Data (Future)

Photos or videos (not in MVP, but planned):

**Challenge**: Large files slow down sync
**Solution**: Separate binary sync from metadata sync
- Sync metadata (session, climb) immediately
- Upload photos to Supabase Storage in background
- Store URL reference in metadata

```swift
// Metadata (fast sync)
let climb = SCClimb(
    name: "My Project",
    photoURL: nil,  // Nil until upload completes
    needsSync: true
)

// Photo upload (background)
Task.detached {
    let url = try await supabaseStorage.upload(photo)
    climb.photoURL = url
    climb.needsSync = true  // Re-sync with URL
}
```

---

## Troubleshooting

### Issue: 409 Conflict Errors on Tag Impact Sync

**Symptoms**: Tag impacts fail to sync with "409 Conflict" error

**Root Cause**: Standard UNIQUE constraints block inserts when soft-deleted records exist with the same (user_id, climb_id, tag_id) combination.

**Solution**: Ensure partial unique indexes are in place instead of UNIQUE constraints:
```sql
-- Verify partial unique indexes exist
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('technique_impacts', 'skill_impacts', 'wall_style_impacts')
  AND indexdef LIKE '%WHERE deleted_at IS NULL%';
```

If indexes are missing, apply migration: `Database/migrations/20260123_fix_impact_unique_constraints.sql`

**Prevention**: Always use partial unique indexes for tables with soft-delete pattern.

### Issue: Sync Never Completes

**Symptoms**: `needsSync = true` never clears

**Possible Causes**:
1. Network error → Check retry queue
2. Foreign key violation → Check dependency order
3. Auth token expired → Refresh token
4. Supabase RLS policy blocking → Check policies
5. 409 Conflict error → Check unique constraints (see above)

**Debug**:
```swift
let syncState = await syncActor.getSyncState()
print("Last sync: \(syncState.lastSyncAt)")
print("Pending: \(syncState.pendingChangesCount)")
print("In flight: \(syncState.inFlightOperations)")
```

### Issue: Data Not Appearing on Other Device

**Symptoms**: Edit on Device A, doesn't show on Device B

**Possible Causes**:
1. Device A hasn't pushed yet
2. Device B hasn't pulled yet
3. Conflict resolution chose wrong version

**Debug**:
```swift
// Device A: Check if pushed
let session = try await fetch(id: sessionId)
print("Needs sync: \(session.needsSync)")  // Should be false

// Device B: Check Supabase directly
let remote = try await supabaseClient.fetch(id: sessionId)
print("Remote updated_at: \(remote.updated_at)")

// Device B: Force pull
try await syncActor.pullUpdates()
```

### Issue: Duplicate Records

**Symptoms**: Same climb appears twice

**Possible Causes**:
1. UUID collision (extremely rare)
2. Sync logic bug

**Prevention**:
- Always use `UUID()` for new records (128-bit, collision-resistant)
- Upsert (not insert) on sync

**Fix**:
```swift
// Supabase upsert (ON CONFLICT UPDATE)
try await supabaseClient.upsert(
    table: "climbs",
    values: climbDTO,
    onConflict: "id"  // Use id as conflict key
)
```

### Issue: Sync Indicator Stuck

**Symptoms**: UI shows "syncing..." forever

**Possible Causes**:
1. `isSyncing` flag not cleared (logic error)
2. Task never completes (infinite loop)

**Prevention**:
```swift
func pushPendingChanges() async throws {
    guard !isSyncing else { return }
    isSyncing = true
    defer { isSyncing = false }  // ALWAYS clear, even on error
    // ...
}
```

---

## Summary

SwiftClimb's sync strategy:
- ✅ **Offline-first**: Local writes always succeed
- ✅ **Eventually consistent**: Remote sync happens in background
- ✅ **Conflict resolution**: Last-write-wins with `needsSync` priority
- ✅ **Resilient**: Exponential backoff retry
- ✅ **Efficient**: Batched operations, dependency-ordered

For architecture details, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

**Last Updated**: 2026-01-23
**Author**: Agent 4 (The Scribe)

**Recent Changes**:
- 2026-01-23: Added section on partial unique indexes for soft-delete pattern
- 2026-01-23: Added troubleshooting entry for 409 Conflict errors on tag impacts
