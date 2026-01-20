// SyncOperation.swift
// SwiftClimb
//
// Represents a pending synchronization operation to be executed by SyncActor.
//
// Operations are queued when local data changes and need to be pushed to Supabase.
// Each operation has a unique ID, retry count, and timestamp for tracking.

import Foundation

/// A synchronization operation to be executed by SyncActor.
///
/// `SyncOperation` represents a single unit of work that needs to be synced
/// to Supabase. Operations are queued when local data changes and executed
/// in the background with retry logic.
///
/// ## Operation Types
///
/// - **Session**: Insert/update session record
/// - **Climb**: Insert/update climb record
/// - **Attempt**: Insert/update attempt record
/// - **Delete**: Soft delete any record type
///
/// ## Retry Logic
///
/// Operations track retry count for exponential backoff:
/// - Max retries: 5
/// - Base delay: 1 second
/// - Backoff: exponential (1s, 2s, 4s, 8s, 16s)
///
/// ## Example
///
/// ```swift
/// let operation = SyncOperation(
///     type: .insertSession(sessionId: session.id)
/// )
/// await syncActor.enqueue(operation)
/// ```
struct SyncOperation: Identifiable, Sendable {

    // MARK: - Operation Type

    enum OperationType: Sendable, Equatable {
        case insertSession(sessionId: UUID)
        case updateSession(sessionId: UUID)
        case deleteSession(sessionId: UUID)

        case insertClimb(climbId: UUID)
        case updateClimb(climbId: UUID)
        case deleteClimb(climbId: UUID)

        case insertAttempt(attemptId: UUID)
        case updateAttempt(attemptId: UUID)
        case deleteAttempt(attemptId: UUID)

        // Profile sync operations (Phase 6)
        case insertProfile(profileId: UUID)
        case updateProfile(profileId: UUID)
        case deleteProfile(profileId: UUID)

        // Follow sync operations (Phase 6)
        case insertFollow(followId: UUID)
        case deleteFollow(followId: UUID)
    }

    let id: UUID
    let type: OperationType
    let createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        type: OperationType,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
    }

    /// Maximum retry attempts before giving up
    static let maxRetries = 5

    /// Calculate delay before next retry attempt
    func nextRetryDelay() -> TimeInterval {
        guard retryCount < Self.maxRetries else { return 0 }
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        return pow(2.0, Double(retryCount))
    }

    var canRetry: Bool {
        return retryCount < Self.maxRetries
    }
}

extension SyncOperation.OperationType {
    var entityType: String {
        switch self {
        case .insertSession, .updateSession, .deleteSession:
            return "session"
        case .insertClimb, .updateClimb, .deleteClimb:
            return "climb"
        case .insertAttempt, .updateAttempt, .deleteAttempt:
            return "attempt"
        case .insertProfile, .updateProfile, .deleteProfile:
            return "profile"
        case .insertFollow, .deleteFollow:
            return "follow"
        }
    }

    var isDelete: Bool {
        switch self {
        case .deleteSession, .deleteClimb, .deleteAttempt, .deleteProfile, .deleteFollow:
            return true
        default:
            return false
        }
    }
}
