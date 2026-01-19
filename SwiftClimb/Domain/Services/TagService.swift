import Foundation

/// Tag catalog management
protocol TagServiceProtocol: Sendable {
    func getTechniqueTags() async -> [SCTechniqueTag]
    func getSkillTags() async -> [SCSkillTag]
    func getWallStyleTags() async -> [SCWallStyleTag]

    func addTechniqueImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws

    func addSkillImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws

    func addWallStyleImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws
}

// Stub implementation
final class TagService: TagServiceProtocol, @unchecked Sendable {
    func getTechniqueTags() async -> [SCTechniqueTag] {
        // TODO: Implement technique tag retrieval
        return []
    }

    func getSkillTags() async -> [SCSkillTag] {
        // TODO: Implement skill tag retrieval
        return []
    }

    func getWallStyleTags() async -> [SCWallStyleTag] {
        // TODO: Implement wall style tag retrieval
        return []
    }

    func addTechniqueImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
        // TODO: Implement technique impact addition
    }

    func addSkillImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
        // TODO: Implement skill impact addition
    }

    func addWallStyleImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
        // TODO: Implement wall style impact addition
    }
}
