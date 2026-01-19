// Attempt.swift
// SwiftClimb
//
// Domain model representing a single attempt on a climb.
//
// An attempt is a try at completing a climb, with an outcome (send, fall, bail),
// send type (flash, onsight, redpoint, etc.), and optional notes. Attempts are
// the most frequently logged data, requiring < 100ms write performance.

import SwiftData
import Foundation

/// A single attempt on a climb.
///
/// `SCAttempt` represents one try at completing a climb. It captures the outcome
/// (send, fall, bail), the type of send if successful (flash, onsight, redpoint),
/// and attempt metadata.
///
/// ## Performance Requirement
///
/// Attempt logging must complete in < 100ms for fast-paced climbing sessions.
/// This is achieved through local-first SwiftData writes with background sync.
///
/// ## Outcomes
///
/// - **Send**: Successfully completed the climb
/// - **Fall**: Fell off the climb
/// - **Bail**: Chose to stop (e.g., unsafe conditions, pumped out)
///
/// ## Send Types (when outcome = .send)
///
/// - **Flash**: First try, no prior attempts, no beta
/// - **Onsight**: First try, no prior attempts, with beta/observation
/// - **Redpoint**: Sent after previous attempts
/// - **Repeat**: Previously sent, sent again
/// - **Project**: Working climb (not yet sent)
///
/// ## Relationships
///
/// - Many-to-one with `SCClimb`: Attempt belongs to a climb
/// - Cascade delete: Deleting a climb deletes all attempts
///
/// ## Example
///
/// ```swift
/// // Successful flash
/// let attempt = SCAttempt(
///     userId: currentUserId,
///     sessionId: session.id,
///     climbId: climb.id,
///     attemptNumber: 1,
///     outcome: .send,
///     sendType: .flash
/// )
///
/// // Failed attempt
/// let fallAttempt = SCAttempt(
///     userId: currentUserId,
///     sessionId: session.id,
///     climbId: climb.id,
///     attemptNumber: 2,
///     outcome: .fall
/// )
/// ```
@Model
final class SCAttempt {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var sessionId: UUID
    var climbId: UUID
    var attemptNumber: Int  // >= 1
    var outcome: AttemptOutcome
    var sendType: SendType?
    var occurredAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCClimb.attempts)
    var climb: SCClimb?

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        attemptNumber: Int,
        outcome: AttemptOutcome,
        sendType: SendType? = nil,
        occurredAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climb: SCClimb? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.sessionId = sessionId
        self.climbId = climbId
        self.attemptNumber = attemptNumber
        self.outcome = outcome
        self.sendType = sendType
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.climb = climb
        self.needsSync = needsSync
    }
}

extension SCAttempt {
    var isSend: Bool {
        return outcome == .send
    }
}
