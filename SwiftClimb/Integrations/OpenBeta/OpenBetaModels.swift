import Foundation

// MARK: - Area Models

struct OpenBetaArea: Codable, Sendable {
    let id: String
    let areaName: String
    let pathTokens: [String]
    let totalClimbs: Int

    var displayPath: String {
        pathTokens.joined(separator: " > ")
    }
}

struct OpenBetaAreaDetails: Codable, Sendable {
    let id: String
    let areaName: String
    let pathTokens: [String]
    let totalClimbs: Int
    let metadata: AreaMetadata?
    let content: AreaContent?
}

struct AreaMetadata: Codable, Sendable {
    let lat: Double?
    let lng: Double?
}

struct AreaContent: Codable, Sendable {
    let description: String?
}

// MARK: - Climb Models

struct OpenBetaClimb: Codable, Sendable {
    let id: String
    let name: String
    let grades: ClimbGrades
    let type: ClimbType

    var primaryDiscipline: Discipline? {
        if type.boulder {
            return .bouldering
        } else if type.sport {
            return .sport
        } else if type.trad {
            return .trad
        } else if type.tr {
            return .topRope
        }
        return nil
    }

    var displayGrade: String? {
        if type.boulder {
            return grades.vscale
        } else {
            return grades.yds ?? grades.french
        }
    }
}

struct OpenBetaClimbDetails: Codable, Sendable {
    let id: String
    let name: String
    let grades: ClimbGrades
    let type: ClimbType
    let fa: String?
    let description: String?
    let location: String?
    let protection: String?
}

struct ClimbGrades: Codable, Sendable {
    let vscale: String?
    let yds: String?
    let french: String?
    let uiaa: String?
}

struct ClimbType: Codable, Sendable {
    let boulder: Bool
    let sport: Bool
    let trad: Bool
    let tr: Bool
}
