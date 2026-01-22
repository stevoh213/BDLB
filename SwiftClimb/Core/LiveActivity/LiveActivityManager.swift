// LiveActivityManager.swift
// SwiftClimb
//
// Actor-based manager for Live Activity lifecycle.
//
// This actor ensures thread-safe management of Live Activities and
// coordinates state updates between the app and widget extension.

#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif
import Foundation
import os.log

private let logger = Logger(subsystem: "com.bdlb.app", category: "LiveActivity")

/// Manages Live Activity lifecycle for climbing sessions.
///
/// This actor ensures thread-safe management of Live Activities and
/// coordinates state updates between the app and widget extension via App Group.
///
/// ## Responsibilities
///
/// - Start/end Live Activities in response to session lifecycle
/// - Update activity state when climbs/attempts change
/// - Maintain App Group state for widget extension
/// - Ensure only one activity is active at a time
///
/// ## Threading
///
/// As an actor, all access is serialized automatically. This prevents
/// race conditions when multiple updates occur rapidly.
///
/// ## Error Handling
///
/// ActivityKit errors are logged but don't propagate to callers. This ensures
/// that Live Activity failures don't break core app functionality.
///
/// ## Example
///
/// ```swift
/// let manager = LiveActivityManager()
///
/// // Start activity
/// await manager.startActivity(
///     sessionId: session.id,
///     discipline: .bouldering,
///     startedAt: session.startedAt
/// )
///
/// // Update after adding climb
/// await manager.updateActivity(
///     sessionId: session.id,
///     climbCount: 5,
///     attemptCount: 12
/// )
///
/// // End when session completes
/// await manager.endActivity(sessionId: session.id)
/// ```
#if canImport(ActivityKit)
actor LiveActivityManager: LiveActivityManagerProtocol {

    /// Currently active Live Activity, if any.
    private var currentActivity: Activity<ClimbingSessionAttributes>?

    /// Current session counts (kept in memory for quick access).
    private var currentClimbCount: Int = 0
    private var currentAttemptCount: Int = 0

    /// The session ID of the current activity (for validation).
    private var currentSessionId: UUID?

    // MARK: - Lifecycle

    func startActivity(
        sessionId: UUID,
        discipline: Discipline,
        startedAt: Date
    ) async {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Activities not enabled or not supported")
            return
        }

        // End any existing activity first
        await endAllActivities()

        let attributes = ClimbingSessionAttributes(
            sessionId: sessionId,
            discipline: discipline,
            startedAt: startedAt
        )

        let initialState = ClimbingSessionAttributes.ContentState.initial

        do {
            // Debug: Log the actual type name being used
            logger.info("Attributes type: \(type(of: attributes))")
            logger.info("Full type name: \(String(reflecting: type(of: attributes)))")

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil  // Local updates only, no push notifications
            )
            currentActivity = activity
            currentSessionId = sessionId
            currentClimbCount = 0
            currentAttemptCount = 0

            // Write to App Group for widget
            writeState(
                sessionId: sessionId,
                discipline: discipline.rawValue,
                startedAt: startedAt
            )

            logger.info("Started activity for session \(sessionId)")
            logger.info("Activity ID: \(activity.id)")
        } catch {
            logger.error("Failed to start activity: \(error)")
        }
    }

    func endActivity(sessionId: UUID) async {
        guard let activity = currentActivity,
              currentSessionId == sessionId else {
            return
        }

        let finalState = ClimbingSessionAttributes.ContentState(
            climbCount: currentClimbCount,
            attemptCount: currentAttemptCount,
            lastUpdated: Date()
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        currentSessionId = nil
        currentClimbCount = 0
        currentAttemptCount = 0

        // Clear App Group state
        SessionActivityState.clear()

        logger.info("Ended activity for session \(sessionId)")
    }

    func updateActivity(
        sessionId: UUID,
        climbCount: Int,
        attemptCount: Int
    ) async {
        guard let activity = currentActivity,
              currentSessionId == sessionId else {
            return
        }

        currentClimbCount = climbCount
        currentAttemptCount = attemptCount

        let newState = ClimbingSessionAttributes.ContentState(
            climbCount: climbCount,
            attemptCount: attemptCount,
            lastUpdated: Date()
        )

        await activity.update(ActivityContent(state: newState, staleDate: nil))

        // Update App Group state
        writeState(
            sessionId: sessionId,
            discipline: activity.attributes.discipline,
            startedAt: activity.attributes.startedAt
        )

        logger.info("Updated activity: \(climbCount) climbs, \(attemptCount) attempts")
    }

    func incrementAttemptCount(sessionId: UUID) async {
        guard currentSessionId == sessionId else { return }

        currentAttemptCount += 1
        await updateActivity(
            sessionId: sessionId,
            climbCount: currentClimbCount,
            attemptCount: currentAttemptCount
        )
    }

    func decrementAttemptCount(sessionId: UUID) async {
        guard currentSessionId == sessionId else { return }

        currentAttemptCount = max(0, currentAttemptCount - 1)
        await updateActivity(
            sessionId: sessionId,
            climbCount: currentClimbCount,
            attemptCount: currentAttemptCount
        )
    }

    func hasActiveActivity(sessionId: UUID) async -> Bool {
        return currentSessionId == sessionId && currentActivity != nil
    }

    // MARK: - Private Helpers

    /// Ends all existing activities for cleanup.
    private func endAllActivities() async {
        for activity in Activity<ClimbingSessionAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        currentActivity = nil
        currentSessionId = nil
    }

    /// Writes current state to App Group for widget access.
    private func writeState(
        sessionId: UUID,
        discipline: String,
        startedAt: Date
    ) {
        let state = SessionActivityState(
            sessionId: sessionId,
            discipline: discipline,
            startedAt: startedAt,
            climbCount: currentClimbCount,
            attemptCount: currentAttemptCount,
            lastUpdated: Date()
        )
        state.write()
    }
}
#else
// Stub implementation for platforms without ActivityKit (macOS)
actor LiveActivityManager: LiveActivityManagerProtocol {
    func startActivity(sessionId: UUID, discipline: Discipline, startedAt: Date) async {}
    func endActivity(sessionId: UUID) async {}
    func updateActivity(sessionId: UUID, climbCount: Int, attemptCount: Int) async {}
    func incrementAttemptCount(sessionId: UUID) async {}
    func decrementAttemptCount(sessionId: UUID) async {}
    func hasActiveActivity(sessionId: UUID) async -> Bool { false }
}
#endif
