import SwiftData
import Foundation

/// Observes SwiftData changes for sync
actor ChangeTracker {
    private var observedChanges: [SyncOperation] = []

    // MARK: - Public Interface

    /// Record a change for sync
    func recordChange(_ operation: SyncOperation) {
        observedChanges.append(operation)
    }

    /// Get pending changes
    func getPendingChanges() -> [SyncOperation] {
        return observedChanges
    }

    /// Clear tracked changes
    func clearChanges() {
        observedChanges.removeAll()
    }

    /// Remove specific change
    func removeChange(withId id: UUID) {
        observedChanges.removeAll { $0.id == id }
    }
}
