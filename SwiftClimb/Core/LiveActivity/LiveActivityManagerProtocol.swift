// LiveActivityManagerProtocol.swift
// SwiftClimb
//
// Protocol defining Live Activity management operations.
//
// This protocol enables dependency injection and testing of Live Activity
// functionality. The actor-based implementation provides thread-safe updates.

import Foundation

/// Protocol for managing Live Activity lifecycle for climbing sessions.
///
/// This protocol defines the contract for starting, updating, and ending
/// Live Activities. It is `Sendable` to allow safe injection across actor boundaries.
///
/// ## Lifecycle
///
/// 1. **Start**: Call `startActivity()` when a session begins
/// 2. **Update**: Call `updateActivity()` when climbs/attempts change
/// 3. **End**: Call `endActivity()` when the session completes
///
/// ## Thread Safety
///
/// All implementations must be thread-safe. The concrete `LiveActivityManager`
/// actor provides automatic isolation.
///
/// ## Example
///
/// ```swift
/// // In StartSessionUseCase
/// await liveActivityManager.startActivity(
///     sessionId: sessionId,
///     discipline: discipline,
///     startedAt: Date()
/// )
///
/// // In AddClimbUseCase
/// await liveActivityManager.updateActivity(
///     sessionId: sessionId,
///     climbCount: 5,
///     attemptCount: 12
/// )
///
/// // In EndSessionUseCase
/// await liveActivityManager.endActivity(sessionId: sessionId)
/// ```
protocol LiveActivityManagerProtocol: Sendable {

    /// Starts a new Live Activity for a climbing session.
    ///
    /// Creates and displays a Live Activity on the Lock Screen and Dynamic Island.
    /// Any existing activity is ended before the new one starts.
    ///
    /// - Parameters:
    ///   - sessionId: The unique identifier of the session
    ///   - discipline: The climbing discipline for this session
    ///   - startedAt: When the session started (used for elapsed timer)
    ///
    /// - Note: This method is non-throwing. Errors are logged but don't fail the operation.
    func startActivity(
        sessionId: UUID,
        discipline: Discipline,
        startedAt: Date
    ) async

    /// Ends the Live Activity for a specific session.
    ///
    /// Dismisses the Live Activity from Lock Screen and Dynamic Island.
    /// No-op if no activity exists for the given session ID.
    ///
    /// - Parameter sessionId: The session ID whose activity should end
    func endActivity(sessionId: UUID) async

    /// Updates the Live Activity with new climb and attempt counts.
    ///
    /// Updates the displayed counts in real-time. This should be called
    /// after any climb or attempt is added/deleted.
    ///
    /// - Parameters:
    ///   - sessionId: The session ID to update
    ///   - climbCount: The new total climb count
    ///   - attemptCount: The new total attempt count
    ///
    /// - Note: No-op if no activity exists for the given session ID.
    func updateActivity(
        sessionId: UUID,
        climbCount: Int,
        attemptCount: Int
    ) async

    /// Increments only the attempt count for a session.
    ///
    /// Convenience method for logging attempts without changing climb count.
    /// Uses the current internal climb count.
    ///
    /// - Parameter sessionId: The session ID to update
    func incrementAttemptCount(sessionId: UUID) async

    /// Decrements only the attempt count for a session.
    ///
    /// Used when an attempt is deleted.
    ///
    /// - Parameter sessionId: The session ID to update
    func decrementAttemptCount(sessionId: UUID) async

    /// Returns whether a Live Activity is currently active for a session.
    ///
    /// - Parameter sessionId: The session ID to check
    /// - Returns: True if an activity exists for this session
    func hasActiveActivity(sessionId: UUID) async -> Bool
}
