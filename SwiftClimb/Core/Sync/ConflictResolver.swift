import Foundation

/// Last-write-wins conflict resolution strategy
struct ConflictResolver: Sendable {
    /// Resolve conflict between local and remote versions
    /// Returns true if remote should win, false if local should win
    func shouldUseRemote(
        localUpdatedAt: Date,
        remoteUpdatedAt: Date,
        localNeedsSync: Bool
    ) -> Bool {
        // If local has unsync'd changes, local wins
        if localNeedsSync {
            return false
        }

        // Otherwise, newer timestamp wins
        return remoteUpdatedAt > localUpdatedAt
    }

    /// Merge remote changes into local data
    /// This is where the actual merge logic would be implemented
    func merge<T>(
        local: T?,
        remote: T,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date,
        localNeedsSync: Bool
    ) -> T {
        // If no local version exists, use remote
        guard let _ = local, let localDate = localUpdatedAt else {
            return remote
        }

        // Apply last-write-wins
        if shouldUseRemote(
            localUpdatedAt: localDate,
            remoteUpdatedAt: remoteUpdatedAt,
            localNeedsSync: localNeedsSync
        ) {
            return remote
        } else {
            // Keep local version - it will be pushed during next sync
            return local!
        }
    }
}
