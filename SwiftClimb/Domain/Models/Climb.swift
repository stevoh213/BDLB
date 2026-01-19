// Climb.swift
// SwiftClimb
//
// Domain model representing an individual climb within a session.
//
// A climb is a specific boulder problem or route that was attempted during
// a session. It includes grade, discipline, location, and tags describing
// techniques, skills, and wall style. Each climb has multiple attempts.

import SwiftData
import Foundation

/// An individual climb attempted during a session.
///
/// `SCClimb` represents a specific boulder problem or route with its grade,
/// discipline (boulder, sport, etc.), and optional location data. Climbs can
/// be linked to OpenBeta for outdoor climbs or manually entered for indoor climbs.
///
/// ## Relationships
///
/// - Many-to-one with `SCSession`: Climb belongs to a session
/// - One-to-many with `SCAttempt`: Climb has multiple attempts
/// - Many-to-many with tags via impact junction tables
/// - Cascade delete: Deleting a climb deletes all attempts and tag impacts
///
/// ## Gym vs. Outdoor
///
/// - **Gym climbs**: `isOutdoor = false`, `locationDisplay = "Gym Name"`, no OpenBeta reference
/// - **Outdoor climbs**: `isOutdoor = true`, `openBetaClimbId` links to OpenBeta database
///
/// ## Tag Impacts
///
/// Climbs can be tagged with techniques, skills, and wall styles, each with
/// an impact indicator (helped/hindered/neutral) for tracking what works.
///
/// ## Example
///
/// ```swift
/// // Indoor climb
/// let climb = SCClimb(
///     userId: currentUserId,
///     sessionId: session.id,
///     discipline: .boulder,
///     isOutdoor: false,
///     name: "Red V5 Corner",
///     gradeOriginal: "V5",
///     locationDisplay: "Brooklyn Boulders"
/// )
///
/// // Outdoor climb
/// let outdoorClimb = SCClimb(
///     userId: currentUserId,
///     sessionId: session.id,
///     discipline: .boulder,
///     isOutdoor: true,
///     name: "Golden Harvest",
///     gradeOriginal: "V8",
///     openBetaClimbId: "abc123",
///     locationDisplay: "Hueco Tanks, TX"
/// )
/// ```
@Model
final class SCClimb {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var sessionId: UUID
    var discipline: Discipline
    var isOutdoor: Bool
    var name: String?
    var gradeOriginal: String?
    var gradeScale: GradeScale?
    var gradeScoreMin: Int?
    var gradeScoreMax: Int?
    var openBetaClimbId: String?
    var openBetaAreaId: String?
    var locationDisplay: String?
    var belayPartnerUserId: UUID?
    var belayPartnerName: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    @Relationship(inverse: \SCSession.climbs)
    var session: SCSession?

    @Relationship(deleteRule: .cascade)
    var attempts: [SCAttempt]

    @Relationship(deleteRule: .cascade)
    var techniqueImpacts: [SCTechniqueImpact]

    @Relationship(deleteRule: .cascade)
    var skillImpacts: [SCSkillImpact]

    @Relationship(deleteRule: .cascade)
    var wallStyleImpacts: [SCWallStyleImpact]

    // Sync metadata
    var needsSync: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String? = nil,
        gradeOriginal: String? = nil,
        gradeScale: GradeScale? = nil,
        gradeScoreMin: Int? = nil,
        gradeScoreMax: Int? = nil,
        openBetaClimbId: String? = nil,
        openBetaAreaId: String? = nil,
        locationDisplay: String? = nil,
        belayPartnerUserId: UUID? = nil,
        belayPartnerName: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        session: SCSession? = nil,
        attempts: [SCAttempt] = [],
        techniqueImpacts: [SCTechniqueImpact] = [],
        skillImpacts: [SCSkillImpact] = [],
        wallStyleImpacts: [SCWallStyleImpact] = [],
        needsSync: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.sessionId = sessionId
        self.discipline = discipline
        self.isOutdoor = isOutdoor
        self.name = name
        self.gradeOriginal = gradeOriginal
        self.gradeScale = gradeScale
        self.gradeScoreMin = gradeScoreMin
        self.gradeScoreMax = gradeScoreMax
        self.openBetaClimbId = openBetaClimbId
        self.openBetaAreaId = openBetaAreaId
        self.locationDisplay = locationDisplay
        self.belayPartnerUserId = belayPartnerUserId
        self.belayPartnerName = belayPartnerName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.session = session
        self.attempts = attempts
        self.techniqueImpacts = techniqueImpacts
        self.skillImpacts = skillImpacts
        self.wallStyleImpacts = wallStyleImpacts
        self.needsSync = needsSync
    }
}

extension SCClimb {
    var hasSend: Bool {
        return attempts.contains { $0.outcome == .send }
    }

    var attemptCount: Int {
        return attempts.count
    }
}
