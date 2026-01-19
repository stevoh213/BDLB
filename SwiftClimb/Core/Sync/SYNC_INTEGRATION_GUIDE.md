# Sync Layer Integration Guide

This guide explains how to integrate the SyncActor into the SwiftClimb app to enable offline-first synchronization with Supabase.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      UI (SwiftUI)                       │
│                     @MainActor                          │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    UseCase Layer                        │
│              (Session, Climb, Attempt)                  │
└─────────────┬───────────────────────────┬───────────────┘
              │                           │
              ▼                           ▼
┌─────────────────────────┐   ┌───────────────────────────┐
│   SwiftData (Local)     │   │   SyncActor               │
│   - Immediate writes    │◄──┤   - Pull updates          │
│   - needsSync flag      │   │   - Push changes          │
│   - Query for UI        │   │   - Conflict resolution   │
└─────────────────────────┘   └───────────────┬───────────┘
                                              │
                                              ▼
                              ┌───────────────────────────┐
                              │  SupabaseRepository       │
                              │  - CRUD operations        │
                              └───────────┬───────────────┘
                                          │
                                          ▼
                              ┌───────────────────────────┐
                              │  Supabase REST API        │
                              │  - sessions table         │
                              │  - climbs table           │
                              │  - attempts table         │
                              └───────────────────────────┘
```

## Setup Instructions

### 1. Initialize SyncActor in SwiftClimbApp

Add SyncActor to the app's initialization:

```swift
@main
struct SwiftClimbApp: App {
    let modelContainer: ModelContainer

    // Add SyncActor
    @State private var syncActor: SyncActor?
    @State private var authManager: SupabaseAuthManager

    init() {
        // Initialize ModelContainer
        modelContainer = SwiftDataContainer.shared.container

        // Initialize Supabase client
        let supabaseClient = SupabaseClientActor(config: .shared)
        let authMgr = SupabaseAuthManager(client: supabaseClient)
        self._authManager = State(initialValue: authMgr)

        // Initialize SyncActor
        let sync = SyncActor(
            modelContainer: modelContainer,
            supabaseClient: supabaseClient
        )
        self._syncActor = State(initialValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            if isAuthenticated, let userId = currentUserId {
                ContentView()
                    .environment(\.syncActor, syncActor)
                    .task {
                        // Trigger initial sync on app launch
                        await performInitialSync(userId: userId)
                    }
                    .onAppear {
                        // Set up periodic sync (every 5 minutes)
                        startPeriodicSync(userId: userId)
                    }
            } else {
                AuthView(authManager: authManager)
            }
        }
        .modelContainer(modelContainer)
    }

    private func performInitialSync(userId: UUID) async {
        guard let syncActor = syncActor else { return }
        do {
            try await syncActor.performSync(userId: userId)
        } catch {
            print("Initial sync failed: \(error)")
        }
    }

    private func startPeriodicSync(userId: UUID) {
        guard let syncActor = syncActor else { return }

        Task {
            while true {
                try? await Task.sleep(for: .seconds(300)) // 5 minutes
                try? await syncActor.performSync(userId: userId)
            }
        }
    }
}
```

### 2. Add Environment Value for SyncActor

Create an environment key in `App/Environment+UseCases.swift`:

```swift
import SwiftUI

// Add to existing environment values
private struct SyncActorKey: EnvironmentKey {
    static let defaultValue: SyncActor? = nil
}

extension EnvironmentValues {
    var syncActor: SyncActor? {
        get { self[SyncActorKey.self] }
        set { self[SyncActorKey.self] = newValue }
    }
}
```

### 3. Trigger Sync After Local Writes

In your use cases, after writing to SwiftData, trigger a background sync:

```swift
final class StartSessionUseCase: StartSessionUseCaseProtocol {
    private let sessionService: SessionServiceProtocol

    func startNewSession(
        userId: UUID,
        mentalReadiness: Int?,
        physicalReadiness: Int?
    ) async throws -> SCSession {
        // Create session in SwiftData
        let session = SCSession(
            userId: userId,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness,
            needsSync: true  // Mark for sync
        )

        // Insert into local database
        try await sessionService.insert(session)

        // Trigger background sync (non-blocking)
        // This will be picked up by the periodic sync or manual refresh

        return session
    }
}
```

### 4. Manual Sync Trigger

Add a pull-to-refresh gesture in your views:

```swift
struct SessionListView: View {
    @Environment(\.syncActor) private var syncActor
    @Environment(\.currentUserId) private var currentUserId
    @Query private var sessions: [SCSession]

    var body: some View {
        List(sessions) { session in
            SessionRow(session: session)
        }
        .refreshable {
            guard let syncActor = syncActor, let userId = currentUserId else {
                return
            }
            try? await syncActor.performSync(userId: userId)
        }
    }
}
```

### 5. Display Sync State

Show sync status in your UI:

```swift
struct SyncStatusView: View {
    @Environment(\.syncActor) private var syncActor
    @State private var syncState: SyncState?

    var body: some View {
        HStack {
            if let state = syncState {
                Image(systemName: state.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                    .symbolEffect(.pulse, isActive: state.isSyncing)

                Text(state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            guard let syncActor = syncActor else { return }

            // Poll sync state every 2 seconds
            while true {
                syncState = await syncActor.getSyncState()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
```

## Sync Triggers

The sync layer is triggered in the following scenarios:

1. **App Launch**: Initial sync on authentication
2. **Periodic Timer**: Every 5 minutes while app is active
3. **Manual Refresh**: User pulls to refresh in list views
4. **Foreground Transition**: When app returns from background
5. **After Local Writes**: Automatic background sync (future enhancement)

## Conflict Resolution

The sync layer uses **last-write-wins** conflict resolution with the following rules:

1. If a local record has `needsSync = true`, it takes precedence (local wins)
2. Otherwise, the record with the newer `updatedAt` timestamp wins
3. This ensures user edits are never lost, even if they conflict with remote changes

## Error Handling

Sync errors are handled gracefully:

1. Network errors are logged but don't block the UI
2. Failed operations remain in the retry queue
3. The app remains functional offline
4. Sync state tracks the last error for debugging

## Testing Sync

To test the sync implementation:

```swift
// In your test or preview
let mockContainer = try ModelContainer(
    for: SCSession.self, SCClimb.self, SCAttempt.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)

let mockSupabaseClient = SupabaseClientActor(config: .shared)

let syncActor = SyncActor(
    modelContainer: mockContainer,
    supabaseClient: mockSupabaseClient
)

// Test sync
try await syncActor.performSync(userId: testUserId)

// Check sync state
let state = await syncActor.getSyncState()
print("Last sync: \(state.lastSyncAt)")
print("Pending: \(state.pendingChangesCount)")
```

## Performance Considerations

1. **Non-blocking**: All sync operations run in the background
2. **Batch operations**: Syncs are batched to reduce network calls
3. **Incremental sync**: Only fetches changes since last sync (5-minute buffer)
4. **Local-first**: UI always reads from SwiftData, never blocks on network

## Future Enhancements

1. **Retry queue**: Implement exponential backoff for failed operations
2. **Delta sync**: Track granular field-level changes
3. **Optimistic concurrency**: Use version vectors instead of timestamps
4. **Background sync**: Use BGTaskScheduler for background app refresh
5. **Network monitoring**: Pause sync when offline, resume when online

## Troubleshooting

### Sync not triggering
- Check that SyncActor is initialized and available via environment
- Verify that currentUserId is available
- Check network connectivity

### Data not syncing
- Verify that records have `needsSync = true` after local writes
- Check that `updatedAt` is being set on changes
- Inspect sync state for errors: `await syncActor.getSyncState()`

### Duplicate records
- Ensure all records use UUIDs, not auto-increment IDs
- Verify that upsert is using `on_conflict: "id"`
- Check that DTOs are properly serializing UUIDs

### Performance issues
- Monitor the number of pending changes
- Consider increasing the sync interval
- Batch large syncs or implement pagination
