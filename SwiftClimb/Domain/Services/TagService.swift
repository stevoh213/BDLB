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

    // Sync tags from Supabase (called on login/startup)
    func syncTagsFromRemote() async throws
}

// MARK: - Implementation

/// Actor-based tag service with offline-first persistence.
///
/// This service manages the predefined tag catalog and impact tracking for climbs.
/// Tags are synced from Supabase on login and cached in memory for performance.
actor TagService: TagServiceProtocol {
    private let modelContainer: ModelContainer
    private let tagsTable: TagsTable?

    // In-memory cache for tag catalog (synced from remote, cached locally)
    private var holdTypeTagsCache: [TechniqueTagDTO]?
    private var skillTagsCache: [SkillTagDTO]?

    init(modelContainer: ModelContainer, tagsTable: TagsTable? = nil) {
        self.modelContainer = modelContainer
        self.tagsTable = tagsTable
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

    // MARK: - Tag Sync from Remote

    /// Syncs tag catalog from Supabase to local SwiftData.
    ///
    /// This method fetches all technique and skill tags from Supabase
    /// and upserts them into local SwiftData with matching UUIDs.
    /// This ensures that when impacts are created locally, they use
    /// the same tag UUIDs as Supabase for proper sync.
    func syncTagsFromRemote() async throws {
        guard let tagsTable = tagsTable else {
            print("[TagService] No tagsTable available, skipping remote sync")
            return
        }

        print("[TagService] Syncing tags from Supabase...")

        // Fetch tags from Supabase
        let remoteTechniqueTags = try await tagsTable.fetchAllTechniqueTags()
        let remoteSkillTags = try await tagsTable.fetchAllSkillTags()

        print("[TagService] Fetched \(remoteTechniqueTags.count) technique tags, \(remoteSkillTags.count) skill tags")

        // Upsert into local SwiftData
        try await MainActor.run {
            // Upsert technique tags
            for remoteTag in remoteTechniqueTags {
                let predicate = #Predicate<SCTechniqueTag> { $0.id == remoteTag.id }
                let descriptor = FetchDescriptor<SCTechniqueTag>(predicate: predicate)
                let existing = try modelContext.fetch(descriptor).first

                if let existing = existing {
                    // Update existing tag
                    existing.name = remoteTag.name
                    existing.category = remoteTag.category
                    existing.updatedAt = remoteTag.updatedAt
                } else {
                    // Insert new tag with Supabase UUID
                    let tag = SCTechniqueTag(
                        id: remoteTag.id,
                        name: remoteTag.name,
                        category: remoteTag.category,
                        createdAt: remoteTag.createdAt,
                        updatedAt: remoteTag.updatedAt
                    )
                    modelContext.insert(tag)
                }
            }

            // Upsert skill tags
            for remoteTag in remoteSkillTags {
                let predicate = #Predicate<SCSkillTag> { $0.id == remoteTag.id }
                let descriptor = FetchDescriptor<SCSkillTag>(predicate: predicate)
                let existing = try modelContext.fetch(descriptor).first

                if let existing = existing {
                    // Update existing tag
                    existing.name = remoteTag.name
                    existing.category = remoteTag.category
                    existing.updatedAt = remoteTag.updatedAt
                } else {
                    // Insert new tag with Supabase UUID
                    let tag = SCSkillTag(
                        id: remoteTag.id,
                        name: remoteTag.name,
                        category: remoteTag.category,
                        createdAt: remoteTag.createdAt,
                        updatedAt: remoteTag.updatedAt
                    )
                    modelContext.insert(tag)
                }
            }

            try modelContext.save()
        }

        // Clear cache to force reload with new data
        holdTypeTagsCache = nil
        skillTagsCache = nil

        print("[TagService] Tag sync complete")
    }
}
