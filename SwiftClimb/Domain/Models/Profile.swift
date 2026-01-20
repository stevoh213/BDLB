import SwiftData
import Foundation

@Model
final class SCProfile {
    @Attribute(.unique) var id: UUID
    var handle: String
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale
    var preferredGradeScaleRoute: GradeScale
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Social Profile Fields (Phase 1)

    /// User's display name (distinct from @handle)
    /// Example: "Alex Honnold" while handle might be "@alex_honnold"
    var displayName: String?

    /// Short user biography (max 280 characters)
    /// Validated at app layer before saving
    var bio: String?

    /// User's home gym or crag name
    /// Free-form text, not validated against a list
    var homeGym: String?

    /// Date when user started climbing
    /// Used for "climbing for X years" display
    var climbingSince: Date?

    /// User's preferred climbing style
    /// Stored as string to allow flexibility (e.g., "Bouldering", "Sport", "Trad")
    var favoriteStyle: String?

    /// Cached count of users following this user
    /// Updated by Supabase trigger, synced to device
    var followerCount: Int

    /// Cached count of users this user follows
    /// Updated by Supabase trigger, synced to device
    var followingCount: Int

    /// Cached count of successful sends
    /// Updated by Supabase trigger, synced to device
    var sendCount: Int

    // Premium status relationship
    @Relationship(deleteRule: .cascade)
    var premiumStatus: SCPremiumStatus?

    // Sync metadata
    var needsSync: Bool
    var remoteId: UUID?

    init(
        id: UUID = UUID(),
        handle: String,
        photoURL: String? = nil,
        homeZIP: String? = nil,
        preferredGradeScaleBoulder: GradeScale = .v,
        preferredGradeScaleRoute: GradeScale = .yds,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        // New social profile fields
        displayName: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        climbingSince: Date? = nil,
        favoriteStyle: String? = nil,
        followerCount: Int = 0,
        followingCount: Int = 0,
        sendCount: Int = 0,
        // Sync metadata
        needsSync: Bool = true,
        remoteId: UUID? = nil
    ) {
        self.id = id
        self.handle = handle
        self.photoURL = photoURL
        self.homeZIP = homeZIP
        self.preferredGradeScaleBoulder = preferredGradeScaleBoulder
        self.preferredGradeScaleRoute = preferredGradeScaleRoute
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        // Social profile fields
        self.displayName = displayName
        self.bio = bio
        self.homeGym = homeGym
        self.climbingSince = climbingSince
        self.favoriteStyle = favoriteStyle
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.sendCount = sendCount
        // Sync metadata
        self.needsSync = needsSync
        self.remoteId = remoteId
    }
}

extension SCProfile {
    /// Computed property for easy premium access
    var isPremium: Bool {
        premiumStatus?.isValidPremium ?? false
    }

    /// Computed property for "climbing for X years" display
    var yearsClimbing: Int? {
        guard let since = climbingSince else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: since, to: Date())
        return components.year
    }

    /// Validation helper for bio length
    static let maxBioLength = 280

    /// Returns true if the bio is within the allowed length
    var isBioValid: Bool {
        guard let bio = bio else { return true }
        return bio.count <= Self.maxBioLength
    }
}
