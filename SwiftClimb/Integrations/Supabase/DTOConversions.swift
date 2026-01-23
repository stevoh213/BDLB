// DTOConversions.swift
// SwiftClimb
//
// Conversion helpers between SwiftData domain models and Supabase DTOs.
//
// These extensions provide bidirectional conversion to facilitate sync operations.
// Domain models use Swift-native types while DTOs match Supabase table schema.

import Foundation

// MARK: - SessionDTO Conversions

extension SessionDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCSession {
        return SCSession(
            id: id,
            userId: userId,
            discipline: Discipline(rawValue: discipline) ?? .bouldering,
            startedAt: startedAt,
            endedAt: endedAt,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness,
            rpe: rpe,
            pumpLevel: pumpLevel,
            notes: notes,
            isPrivate: isPrivate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            climbs: [],
            needsSync: false  // Coming from server, so synced
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ session: SCSession) -> SessionDTO {
        return SessionDTO(
            id: session.id,
            userId: session.userId,
            discipline: session.discipline.rawValue,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            mentalReadiness: session.mentalReadiness,
            physicalReadiness: session.physicalReadiness,
            rpe: session.rpe,
            pumpLevel: session.pumpLevel,
            notes: session.notes,
            isPrivate: session.isPrivate,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            deletedAt: session.deletedAt
        )
    }
}

// MARK: - ClimbDTO Conversions

extension ClimbDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCClimb {
        return SCClimb(
            id: id,
            userId: userId,
            sessionId: sessionId,
            discipline: Discipline(rawValue: discipline) ?? .bouldering,
            isOutdoor: isOutdoor,
            name: name,
            gradeOriginal: gradeOriginal,
            gradeScale: gradeScale.flatMap { GradeScale(rawValue: $0) },
            gradeScoreMin: gradeScoreMin,
            gradeScoreMax: gradeScoreMax,
            openBetaClimbId: openBetaClimbId,
            openBetaAreaId: openBetaAreaId,
            locationDisplay: locationDisplay,
            belayPartnerUserId: belayPartnerUserId,
            belayPartnerName: belayPartnerName,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            session: nil,
            attempts: [],
            techniqueImpacts: [],
            skillImpacts: [],
            wallStyleImpacts: [],
            needsSync: false
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ climb: SCClimb) -> ClimbDTO {
        return ClimbDTO(
            id: climb.id,
            userId: climb.userId,
            sessionId: climb.sessionId,
            discipline: climb.discipline.rawValue,
            isOutdoor: climb.isOutdoor,
            name: climb.name,
            gradeOriginal: climb.gradeOriginal,
            gradeScale: climb.gradeScale?.rawValue,
            gradeScoreMin: climb.gradeScoreMin,
            gradeScoreMax: climb.gradeScoreMax,
            openBetaClimbId: climb.openBetaClimbId,
            openBetaAreaId: climb.openBetaAreaId,
            locationDisplay: climb.locationDisplay,
            belayPartnerUserId: climb.belayPartnerUserId,
            belayPartnerName: climb.belayPartnerName,
            notes: climb.notes,
            createdAt: climb.createdAt,
            updatedAt: climb.updatedAt,
            deletedAt: climb.deletedAt
        )
    }
}

// MARK: - AttemptDTO Conversions

extension AttemptDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCAttempt {
        return SCAttempt(
            id: id,
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            attemptNumber: attemptNumber,
            outcome: AttemptOutcome(rawValue: outcome) ?? .try,
            sendType: sendType.flatMap { SendType(rawValue: $0) },
            occurredAt: occurredAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            climb: nil,
            needsSync: false
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ attempt: SCAttempt) -> AttemptDTO {
        return AttemptDTO(
            id: attempt.id,
            userId: attempt.userId,
            sessionId: attempt.sessionId,
            climbId: attempt.climbId,
            attemptNumber: attempt.attemptNumber,
            outcome: attempt.outcome.rawValue,
            sendType: attempt.sendType?.rawValue,
            occurredAt: attempt.occurredAt,
            createdAt: attempt.createdAt,
            updatedAt: attempt.updatedAt,
            deletedAt: attempt.deletedAt
        )
    }
}

// MARK: - TechniqueImpactDTO Conversions

extension TechniqueImpactDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCTechniqueImpact {
        return SCTechniqueImpact(
            id: id,
            userId: userId,
            climbId: climbId,
            tagId: tagId,
            impact: TagImpact(rawValue: impact) ?? .neutral,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            climb: nil,
            tag: nil,
            needsSync: false  // Coming from server, so synced
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ impact: SCTechniqueImpact) -> TechniqueImpactDTO {
        return TechniqueImpactDTO(
            id: impact.id,
            userId: impact.userId,
            climbId: impact.climbId,
            tagId: impact.tagId,
            impact: impact.impact.rawValue,
            createdAt: impact.createdAt,
            updatedAt: impact.updatedAt,
            deletedAt: impact.deletedAt
        )
    }
}

// MARK: - SkillImpactDTO Conversions

extension SkillImpactDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCSkillImpact {
        return SCSkillImpact(
            id: id,
            userId: userId,
            climbId: climbId,
            tagId: tagId,
            impact: TagImpact(rawValue: impact) ?? .neutral,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            climb: nil,
            tag: nil,
            needsSync: false
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ impact: SCSkillImpact) -> SkillImpactDTO {
        return SkillImpactDTO(
            id: impact.id,
            userId: impact.userId,
            climbId: impact.climbId,
            tagId: impact.tagId,
            impact: impact.impact.rawValue,
            createdAt: impact.createdAt,
            updatedAt: impact.updatedAt,
            deletedAt: impact.deletedAt
        )
    }
}

// MARK: - WallStyleImpactDTO Conversions

extension WallStyleImpactDTO {
    /// Convert DTO to domain model
    func toDomain() -> SCWallStyleImpact {
        return SCWallStyleImpact(
            id: id,
            userId: userId,
            climbId: climbId,
            tagId: tagId,
            impact: TagImpact(rawValue: impact) ?? .neutral,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            climb: nil,
            tag: nil,
            needsSync: false
        )
    }

    /// Create DTO from domain model
    static func fromDomain(_ impact: SCWallStyleImpact) -> WallStyleImpactDTO {
        return WallStyleImpactDTO(
            id: impact.id,
            userId: impact.userId,
            climbId: impact.climbId,
            tagId: impact.tagId,
            impact: impact.impact.rawValue,
            createdAt: impact.createdAt,
            updatedAt: impact.updatedAt,
            deletedAt: impact.deletedAt
        )
    }
}
