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
        self.needsSync = needsSync
        self.remoteId = remoteId
    }
}
