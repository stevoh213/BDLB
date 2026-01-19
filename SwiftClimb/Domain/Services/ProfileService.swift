import Foundation

/// Profile CRUD operations
protocol ProfileServiceProtocol: Sendable {
    func createProfile(
        id: UUID,
        handle: String,
        photoURL: String?,
        homeZIP: String?
    ) async throws -> SCProfile

    func updateProfile(profileId: UUID, updates: ProfileUpdates) async throws
    func getProfile(profileId: UUID) async -> SCProfile?
    func searchProfiles(query: String, limit: Int) async -> [SCProfile]
}

struct ProfileUpdates: Sendable {
    var handle: String?
    var photoURL: String?
    var homeZIP: String?
    var preferredGradeScaleBoulder: GradeScale?
    var preferredGradeScaleRoute: GradeScale?
    var isPublic: Bool?
}

// Stub implementation
final class ProfileService: ProfileServiceProtocol, @unchecked Sendable {
    func createProfile(
        id: UUID,
        handle: String,
        photoURL: String?,
        homeZIP: String?
    ) async throws -> SCProfile {
        // TODO: Implement profile creation
        fatalError("Not implemented")
    }

    func updateProfile(profileId: UUID, updates: ProfileUpdates) async throws {
        // TODO: Implement profile update
    }

    func getProfile(profileId: UUID) async -> SCProfile? {
        // TODO: Implement profile retrieval
        return nil
    }

    func searchProfiles(query: String, limit: Int) async -> [SCProfile] {
        // TODO: Implement profile search
        return []
    }
}
