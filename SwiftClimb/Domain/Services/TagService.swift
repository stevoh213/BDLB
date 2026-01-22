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
// TODO: [Tag Service Implementation] - Complete tag service with persistence and sync
// - Inject ModelContext for SwiftData persistence
// - Implement tag catalog seeding with predefined tags on first launch
// - Add query methods with filtering and sorting capabilities
// - Ensure offline-first: persist impacts locally, sync in background
// - Consider tag usage analytics for suggested tags feature
final class TagService: TagServiceProtocol, @unchecked Sendable {
    // TODO: [Technique Tags] - Implement technique tag retrieval from SwiftData
    // - Query SCTechniqueTag models sorted alphabetically
    // - Consider grouping by category (e.g., "Footwork", "Hand Techniques")
    // - Cache results for performance
    // - Examples: heel hook, toe hook, drop knee, high step, smearing
    func getTechniqueTags() async -> [SCTechniqueTag] {
        return []
    }

    // TODO: [Skill Tags] - Implement skill tag retrieval from SwiftData
    // - Query SCSkillTag models sorted alphabetically
    // - Consider grouping by category (e.g., "Physical", "Mental")
    // - Cache results for performance
    // - Examples: crimping strength, endurance, flexibility, body tension, problem solving
    func getSkillTags() async -> [SCSkillTag] {
        return []
    }

    // TODO: [Wall Style Tags] - Implement wall style tag retrieval from SwiftData
    // - Query SCWallStyleTag models sorted alphabetically
    // - Consider grouping by category (e.g., "Angle", "Features")
    // - Cache results for performance
    // - Examples: overhang, slab, vertical, arete, roof, dihedral
    func getWallStyleTags() async -> [SCWallStyleTag] {
        return []
    }

    // TODO: [Technique Impact] - Implement technique impact creation
    // - Create SCTechniqueImpact record with userId, climbId, tagId, impact
    // - Persist to SwiftData with needsSync = true
    // - Enqueue for background sync via SyncActor
    // - Handle duplicate impacts (update existing or error)
    func addTechniqueImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
    }

    // TODO: [Skill Impact] - Implement skill impact creation
    // - Create SCSkillImpact record with userId, climbId, tagId, impact
    // - Persist to SwiftData with needsSync = true
    // - Enqueue for background sync via SyncActor
    // - Handle duplicate impacts (update existing or error)
    func addSkillImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
    }

    // TODO: [Wall Style Impact] - Implement wall style impact creation
    // - Create SCWallStyleImpact record with userId, climbId, tagId, impact
    // - Persist to SwiftData with needsSync = true
    // - Enqueue for background sync via SyncActor
    // - Handle duplicate impacts (update existing or error)
    func addWallStyleImpact(
        userId: UUID,
        climbId: UUID,
        tagId: UUID,
        impact: TagImpact
    ) async throws {
    }
}
