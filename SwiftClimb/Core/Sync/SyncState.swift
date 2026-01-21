import Foundation

/// Sync state tracking for the SyncActor.
///
/// `SyncState` provides observable status information about the synchronization
/// process, including whether a sync is in progress, pending changes count,
/// and any errors that occurred.
struct SyncState: Sendable {
    var lastSyncAt: Date?
    var isSyncing: Bool
    var pendingChangesCount: Int
    var lastError: String?

    init(
        lastSyncAt: Date? = nil,
        isSyncing: Bool = false,
        pendingChangesCount: Int = 0,
        lastError: String? = nil
    ) {
        self.lastSyncAt = lastSyncAt
        self.isSyncing = isSyncing
        self.pendingChangesCount = pendingChangesCount
        self.lastError = lastError
    }
}

// MARK: - UI Helpers

extension SyncState {
    /// Human-readable status text for displaying sync state in UI.
    var statusText: String {
        if isSyncing {
            return "Syncing..."
        } else if let error = lastError {
            return "Sync failed: \(error)"
        } else if let lastSync = lastSyncAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced"
        }
    }
}
