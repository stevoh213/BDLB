// ClimbingSessionAttributes.swift
// SwiftClimb
//
// Re-exports ClimbingSessionAttributes from SwiftClimbFeature package
// and adds convenience extensions that use app-specific types.

import Foundation
@_exported import SwiftClimbFeature

#if canImport(ActivityKit)
// MARK: - Convenience Extensions (Main App Only)

extension ClimbingSessionAttributes {
    /// Creates attributes from session data using the Discipline enum.
    ///
    /// This convenience initializer is only available in the main app
    /// because the widget extension doesn't have access to the Discipline enum.
    ///
    /// - Parameters:
    ///   - sessionId: The session's unique identifier
    ///   - discipline: The discipline enum (converted to String internally)
    ///   - startedAt: When the session started
    init(sessionId: UUID, discipline: Discipline, startedAt: Date) {
        self.init(sessionId: sessionId, discipline: discipline.rawValue, startedAt: startedAt)
    }
}
#endif
