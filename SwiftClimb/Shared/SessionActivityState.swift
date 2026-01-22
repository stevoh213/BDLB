// SessionActivityState.swift
// SwiftClimb
//
// Lightweight state stored in App Group for widget extension access.
//
// This provides a communication bridge between the main app (which has
// SwiftData access) and the widget extension (which does not).

import Foundation

/// Lightweight state stored in App Group for widget access.
///
/// The widget extension cannot access SwiftData, so this codable struct
/// is used to share session state via App Group UserDefaults.
///
/// ## Usage
///
/// ```swift
/// // Write state from main app
/// let state = SessionActivityState(
///     sessionId: session.id,
///     discipline: session.discipline.rawValue,
///     startedAt: session.startedAt,
///     climbCount: 5,
///     attemptCount: 12
/// )
/// state.write()
///
/// // Read state in widget
/// if let state = SessionActivityState.read() {
///     Text("Climbs: \(state.climbCount)")
/// }
/// ```
struct SessionActivityState: Codable, Sendable {
    /// Unique identifier for the session (matches SCSession.id)
    let sessionId: UUID

    /// Climbing discipline raw value (e.g., "bouldering", "sport")
    let discipline: String

    /// When the session started
    let startedAt: Date

    /// Number of climbs logged in this session
    let climbCount: Int

    /// Total number of attempts across all climbs
    let attemptCount: Int

    /// Timestamp of last update (for staleness detection)
    let lastUpdated: Date

    // MARK: - App Group Configuration

    /// The App Group identifier shared between main app and widget extension.
    ///
    /// This must match the value configured in both targets' entitlements.
    static let appGroupIdentifier = "group.com.swiftclimb.shared"

    /// The UserDefaults key for storing active session state.
    static let stateKey = "activeSessionState"

    // MARK: - Persistence

    /// Reads current state from App Group UserDefaults.
    ///
    /// - Returns: The stored session state, or nil if no active session exists.
    static func read() -> SessionActivityState? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: stateKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionActivityState.self, from: data)
    }

    /// Writes this state to App Group UserDefaults.
    ///
    /// This method is synchronous and safe to call from any thread.
    func write() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Self.stateKey)
    }

    /// Clears state from App Group UserDefaults.
    ///
    /// Called when a session ends to remove stale state.
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        defaults.removeObject(forKey: stateKey)
    }
}
