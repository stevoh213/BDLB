// ClimbingSessionAttributes.swift
// SwiftClimbFeature
//
// ActivityKit attributes definition for climbing session Live Activities.
// Shared between main app and widget extension.

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

/// Defines the static and dynamic data for a climbing session Live Activity.
///
/// This type MUST be in a shared module so both the main app and widget extension
/// use the exact same type. ActivityKit matches activities by type name.
#if canImport(ActivityKit)
public struct ClimbingSessionAttributes: ActivityAttributes {

    // MARK: - Static Attributes (immutable after activity starts)

    /// Unique identifier for the session (matches SCSession.id)
    public let sessionId: UUID

    /// Climbing discipline for this session (stored as String for widget compatibility)
    public let discipline: String

    /// When the session started (used for elapsed time calculation)
    public let startedAt: Date

    /// Deep link URL scheme for opening the app
    public let deepLinkScheme: String = "swiftclimb"

    // MARK: - ContentState (dynamic, updatable)

    /// Dynamic state that changes during the session.
    public struct ContentState: Codable, Hashable {
        /// Number of climbs logged in this session
        public let climbCount: Int

        /// Total number of attempts across all climbs
        public let attemptCount: Int

        /// Timestamp of last update
        public let lastUpdated: Date

        /// Initial state when activity starts (no climbs yet)
        public static var initial: ContentState {
            ContentState(climbCount: 0, attemptCount: 0, lastUpdated: Date())
        }

        public init(climbCount: Int, attemptCount: Int, lastUpdated: Date) {
            self.climbCount = climbCount
            self.attemptCount = attemptCount
            self.lastUpdated = lastUpdated
        }
    }

    // MARK: - Initializers

    public init(sessionId: UUID, discipline: String, startedAt: Date) {
        self.sessionId = sessionId
        self.discipline = discipline
        self.startedAt = startedAt
    }
}

// MARK: - Convenience Extensions

extension ClimbingSessionAttributes {
    /// Returns the discipline display name for UI.
    public var disciplineDisplayName: String {
        switch discipline {
        case "bouldering": return "Bouldering"
        case "sport": return "Sport"
        case "trad": return "Trad"
        case "top_rope": return "Top Rope"
        default: return discipline.capitalized
        }
    }

    /// Returns the system image name for the discipline.
    public var disciplineIcon: String {
        "figure.climbing"
    }

    /// Constructs the deep link URL for adding a climb.
    public var addClimbDeepLink: URL? {
        URL(string: "\(deepLinkScheme)://session/\(sessionId.uuidString)/add-climb")
    }

    /// Constructs the deep link URL for viewing the session.
    public var viewSessionDeepLink: URL? {
        URL(string: "\(deepLinkScheme)://session/\(sessionId.uuidString)")
    }
}
#endif
