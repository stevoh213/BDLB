import SwiftData
import Foundation

/// SwiftData ModelContainer configuration
final class SwiftDataContainer: Sendable {
    static let shared = SwiftDataContainer()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            SCProfile.self,
            SCPremiumStatus.self,
            SCSession.self,
            SCClimb.self,
            SCAttempt.self,
            SCTechniqueTag.self,
            SCSkillTag.self,
            SCWallStyleTag.self,
            SCTechniqueImpact.self,
            SCSkillImpact.self,
            SCWallStyleImpact.self,
            SCPost.self,
            SCFollow.self,
            SCKudos.self,
            SCComment.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
