import Foundation

/// Climb management
protocol ClimbServiceProtocol: Sendable {
    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?
    ) async throws -> SCClimb

    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws
    func deleteClimb(climbId: UUID) async throws
    func getClimb(climbId: UUID) async -> SCClimb?
}

struct ClimbUpdates: Sendable {
    var name: String?
    var grade: Grade?
    var notes: String?
    var belayPartnerName: String?
}

// Stub implementation
final class ClimbService: ClimbServiceProtocol, @unchecked Sendable {
    func createClimb(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        isOutdoor: Bool,
        name: String?,
        grade: Grade?
    ) async throws -> SCClimb {
        // TODO: Implement climb creation
        fatalError("Not implemented")
    }

    func updateClimb(climbId: UUID, updates: ClimbUpdates) async throws {
        // TODO: Implement climb update
    }

    func deleteClimb(climbId: UUID) async throws {
        // TODO: Implement climb deletion
    }

    func getClimb(climbId: UUID) async -> SCClimb? {
        // TODO: Implement climb retrieval
        return nil
    }
}
