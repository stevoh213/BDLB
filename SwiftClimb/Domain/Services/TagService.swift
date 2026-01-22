import Foundation
import SwiftData

// Import model types needed for tag operations.
// Note: TagImpact enum is defined in Domain/Models/Enums.swift
// Tag models (SCTechniqueTag, SCSkillTag, etc.) are in Domain/Models/Tags.swift

// MARK: - Input Types

/// Input for setting tag impacts in bulk.
struct TagImpactInput: Sendable {
    let tagId: UUID
    let impact: TagImpact
}

// MARK: - Tag Data Transfer Objects

/// Sendable representation of a technique tag for UI display.
struct TechniqueTagDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}

/// Sendable representation of a skill tag for UI display.
struct SkillTagDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}

// MARK: - Protocol

/// Tag catalog management and impact tracking.
protocol TagServiceProtocol: Sendable {
    // Tag catalog queries (renamed for clarity)
    func getHoldTypeTags() async -> [TechniqueTagDTO]
    func getSkillTags() async -> [SkillTagDTO]

    // Bulk impact management (new pattern)
    func setHoldTypeImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws

    func setSkillImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws

    // Seed predefined tags (called on first launch)
    func seedPredefinedTagsIfNeeded() async throws
}

// MARK: - Implementation

/// Actor-based tag service with offline-first persistence.
///
/// This service manages the predefined tag catalog and impact tracking for climbs.
/// Tags are seeded once on first launch and cached in memory for performance.
actor TagService: TagServiceProtocol {
    private let modelContainer: ModelContainer

    // In-memory cache for tag catalog (seeded once, never changes)
    private var holdTypeTagsCache: [TechniqueTagDTO]?
    private var skillTagsCache: [SkillTagDTO]?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Tag Catalog Queries

    func getHoldTypeTags() async -> [TechniqueTagDTO] {
        if let cached = holdTypeTagsCache {
            return cached
        }

        let tags = await MainActor.run {
            let descriptor = FetchDescriptor<SCTechniqueTag>(
                sortBy: [SortDescriptor(\.name)]
            )
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.map { tag in
                TechniqueTagDTO(id: tag.id, name: tag.name, category: tag.category)
            }
        }

        holdTypeTagsCache = tags
        return tags
    }

    func getSkillTags() async -> [SkillTagDTO] {
        if let cached = skillTagsCache {
            return cached
        }

        let tags = await MainActor.run {
            let descriptor = FetchDescriptor<SCSkillTag>(
                sortBy: [SortDescriptor(\.name)]
            )
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.map { tag in
                SkillTagDTO(id: tag.id, name: tag.name, category: tag.category)
            }
        }

        skillTagsCache = tags
        return tags
    }

    // MARK: - Impact Management

    func setHoldTypeImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws {
        try await MainActor.run {
            // Delete existing impacts for this climb
            let existingPredicate = #Predicate<SCTechniqueImpact> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let existingDescriptor = FetchDescriptor<SCTechniqueImpact>(
                predicate: existingPredicate
            )
            let existing = try modelContext.fetch(existingDescriptor)

            // Soft delete existing impacts
            let now = Date()
            for impact in existing {
                impact.deletedAt = now
                impact.updatedAt = now
                impact.needsSync = true
            }

            // Create new impacts
            for input in impacts {
                let impact = SCTechniqueImpact(
                    userId: userId,
                    climbId: climbId,
                    tagId: input.tagId,
                    impact: input.impact,
                    needsSync: true
                )
                modelContext.insert(impact)
            }

            try modelContext.save()
        }
    }

    func setSkillImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws {
        try await MainActor.run {
            // Delete existing impacts for this climb
            let existingPredicate = #Predicate<SCSkillImpact> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let existingDescriptor = FetchDescriptor<SCSkillImpact>(
                predicate: existingPredicate
            )
            let existing = try modelContext.fetch(existingDescriptor)

            // Soft delete existing impacts
            let now = Date()
            for impact in existing {
                impact.deletedAt = now
                impact.updatedAt = now
                impact.needsSync = true
            }

            // Create new impacts
            for input in impacts {
                let impact = SCSkillImpact(
                    userId: userId,
                    climbId: climbId,
                    tagId: input.tagId,
                    impact: input.impact,
                    needsSync: true
                )
                modelContext.insert(impact)
            }

            try modelContext.save()
        }
    }

    // MARK: - Tag Seeding

    func seedPredefinedTagsIfNeeded() async throws {
        try await MainActor.run {
            // Check if already seeded
            let holdDescriptor = FetchDescriptor<SCTechniqueTag>()
            let existingHolds = try modelContext.fetch(holdDescriptor)

            if existingHolds.isEmpty {
                try seedHoldTypeTags()
            }

            let skillDescriptor = FetchDescriptor<SCSkillTag>()
            let existingSkills = try modelContext.fetch(skillDescriptor)

            if existingSkills.isEmpty {
                try seedSkillTags()
            }

            try modelContext.save()
        }

        // Clear cache to force reload (done outside MainActor.run to avoid actor isolation issues)
        holdTypeTagsCache = nil
        skillTagsCache = nil
    }

    @MainActor
    private func seedHoldTypeTags() throws {
        let holdTypes: [(name: String, category: String)] = [
            ("Crimp", "Grip"),
            ("Sloper", "Grip"),
            ("Jug", "Grip"),
            ("Pinch", "Grip"),
            ("Pocket", "Grip"),
            ("Sidepull", "Grip"),
            ("Undercling", "Grip"),
            ("Gaston", "Movement"),
            ("Smear", "Movement"),
            ("Heel Hook", "Movement"),
            ("Toe Hook", "Movement")
        ]

        for holdType in holdTypes {
            let tag = SCTechniqueTag(
                name: holdType.name,
                category: holdType.category
            )
            modelContext.insert(tag)
        }
    }

    @MainActor
    private func seedSkillTags() throws {
        let skills: [(name: String, category: String)] = [
            ("Drop Knee", "Technical"),
            ("Flagging", "Technical"),
            ("Mantle", "Technical"),
            ("Dyno", "Technical"),
            ("Lock Off", "Technical"),
            ("Deadpoint", "Technical"),
            ("Body Tension", "Physical"),
            ("Finger Strength", "Physical"),
            ("Flexibility", "Physical"),
            ("Power", "Physical"),
            ("Endurance", "Physical"),
            ("No Cut Loose", "Physical"),
            ("Mental", "Mental"),
            ("Pacing", "Mental"),
            ("Precision", "Mental"),
            ("Route Reading", "Mental")
        ]

        for skill in skills {
            let tag = SCSkillTag(
                name: skill.name,
                category: skill.category
            )
            modelContext.insert(tag)
        }
    }
}
