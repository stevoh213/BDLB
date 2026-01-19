import SwiftData
import Foundation

/// Schema versioning and migration strategies
enum ModelMigrations {
    // MARK: - Version History

    /// Current schema version
    static let currentVersion = 1

    // MARK: - Migration Plans

    /// Future migration implementations will go here
    /// Example:
    /// ```
    /// static let v1ToV2 = MigrationPlan(...)
    /// ```

    // MARK: - Helper Methods

    /// Validates schema version compatibility
    static func validateVersion(_ version: Int) -> Bool {
        return version <= currentVersion
    }
}
