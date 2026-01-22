// DeepLinkHandler.swift
// SwiftClimb
//
// URL parsing and routing for deep links.
//
// Handles deep links from Live Activity and other sources to navigate
// to specific screens within the app.

import Foundation

/// Represents a parsed deep link action.
///
/// Deep links follow the format: `swiftclimb://session/{sessionId}/action`
///
/// ## Supported URLs
///
/// - `swiftclimb://session/{uuid}` - View session
/// - `swiftclimb://session/{uuid}/add-climb` - Open add climb sheet
///
/// ## Example
///
/// ```swift
/// let url = URL(string: "swiftclimb://session/123e4567-e89b-12d3-a456-426614174000/add-climb")!
/// let deepLink = DeepLink(url: url)
///
/// switch deepLink {
/// case .addClimb(let sessionId):
///     showAddClimbSheet(for: sessionId)
/// case .viewSession(let sessionId):
///     navigateToSession(sessionId)
/// case .unknown:
///     // Handle gracefully
/// }
/// ```
enum DeepLink: Equatable, Sendable {
    /// Open the Add Climb sheet for a specific session.
    case addClimb(sessionId: UUID)

    /// Navigate to view a specific session.
    case viewSession(sessionId: UUID)

    /// Unrecognized or malformed URL.
    case unknown

    /// The URL scheme used for SwiftClimb deep links.
    static let scheme = "swiftclimb"

    /// Parses a URL into a DeepLink action.
    ///
    /// - Parameter url: The URL to parse
    ///
    /// ## URL Format
    ///
    /// ```
    /// swiftclimb://session/{sessionId}[/action]
    /// ```
    ///
    /// Where:
    /// - `{sessionId}` is a valid UUID string
    /// - `[/action]` is optional (e.g., `/add-climb`)
    init(url: URL) {
        // Validate scheme
        guard url.scheme == Self.scheme else {
            self = .unknown
            return
        }

        // Validate host (should be "session")
        guard url.host == "session" else {
            self = .unknown
            return
        }

        // Parse path components: ["", "{sessionId}", "action"?]
        let pathComponents = url.pathComponents

        // Need at least the session ID (pathComponents[0] is empty string for root)
        guard pathComponents.count >= 2,
              let sessionId = UUID(uuidString: pathComponents[1]) else {
            self = .unknown
            return
        }

        // Check for action
        if pathComponents.count >= 3 && pathComponents[2] == "add-climb" {
            self = .addClimb(sessionId: sessionId)
        } else {
            self = .viewSession(sessionId: sessionId)
        }
    }

    /// Creates the URL for adding a climb to a session.
    ///
    /// - Parameter sessionId: The session to add a climb to
    /// - Returns: The formatted deep link URL
    static func addClimbURL(sessionId: UUID) -> URL? {
        URL(string: "\(scheme)://session/\(sessionId.uuidString)/add-climb")
    }

    /// Creates the URL for viewing a session.
    ///
    /// - Parameter sessionId: The session to view
    /// - Returns: The formatted deep link URL
    static func viewSessionURL(sessionId: UUID) -> URL? {
        URL(string: "\(scheme)://session/\(sessionId.uuidString)")
    }
}
