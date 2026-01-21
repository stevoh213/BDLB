// Session.swift
// SwiftClimb
//
// Domain model representing a climbing session.
//
// A session captures a single climbing workout, including readiness metrics,
// duration, RPE (Rate of Perceived Exertion), and all climbs attempted during
// the session. Sessions are the primary unit of organization in the logbook.
//
// Offline-First: All sessions are created in SwiftData first, then synced to
// Supabase in the background. The `needsSync` flag tracks pending sync operations.

import SwiftData
import Foundation

/// A climbing session with associated climbs and metrics.
///
/// `SCSession` represents a single climbing workout from start to finish.
/// It captures readiness metrics at the start, tracks all climbs and attempts
/// during the session, and records exertion metrics (RPE, pump level) at the end.
///
/// ## Lifecycle
///
/// 1. **Start**: User starts session with optional mental/physical readiness
/// 2. **Active**: Climbs are added, attempts logged (session.endedAt == nil)
/// 3. **End**: User ends session with RPE, pump level, and notes
///
/// ## Relationships
///
/// - One-to-many with `SCClimb`: A session contains multiple climbs
/// - Cascade delete: Deleting a session deletes all associated climbs and attempts
///
/// ## Sync Strategy
///
/// Sessions use offline-first persistence with eventual sync:
/// - Created locally with `needsSync = true`
/// - Synced to Supabase in background
/// - On success, `needsSync` cleared
/// - Soft deletes via `deletedAt` timestamp
///
/// ## Example
///
/// ```swift
/// // Create new session
/// let session = SCSession(
///     userId: currentUserId,
///     mentalReadiness: 4,
///     physicalReadiness: 5
/// )
/// modelContext.insert(session)
///
/// // Add climbs...
///
/// // End session
/// session.endedAt = Date()
/// session.rpe = 7
/// session.pumpLevel = 3
/// session.notes = "Great endurance day"
/// ```
@Model
final class SCSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    // Stored as optional for migration compatibility with pre-discipline sessions
    private var _discipline: Discipline?
    var startedAt: Date
    var endedAt: Date?
    var mentalReadiness: Int?  // 1-5
    var physicalReadiness: Int? // 1-5
    var rpe: Int?              // 1-10
    var pumpLevel: Int?        // 1-5
    var notes: String?
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade)
    var climbs: [SCClimb]

    // Sync metadata
    var needsSync: Bool

    /// The climbing discipline for this session.
    /// Defaults to .bouldering for sessions created before discipline was added.
    var discipline: Discipline {
        get { _discipline ?? .bouldering }
        set { _discipline = newValue }
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        discipline: Discipline,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        mentalReadiness: Int? = nil,
        physicalReadiness: Int? = nil,
        rpe: Int? = nil,
        pumpLevel: Int? = nil,
        notes: String? = nil,
        isPrivate: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        climbs: [SCClimb] = [],
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self._discipline = discipline
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mentalReadiness = mentalReadiness
        self.physicalReadiness = physicalReadiness
        self.rpe = rpe
        self.pumpLevel = pumpLevel
        self.notes = notes
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.climbs = climbs
        self.needsSync = needsSync
    }
}

extension SCSession {
    var isActive: Bool {
        return endedAt == nil
    }

    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var attemptCount: Int {
        return climbs.reduce(0) { $0 + $1.attempts.count }
    }

    /// Returns the appropriate grade scale for this session's discipline
    var defaultGradeScale: GradeScale {
        switch discipline {
        case .bouldering:
            return .v
        case .sport, .trad, .topRope:
            return .yds
        }
    }
}
