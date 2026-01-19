import Foundation

// MARK: - Discipline

enum Discipline: String, Codable, CaseIterable, Sendable {
    case bouldering
    case sport
    case trad
    case topRope = "top_rope"

    var displayName: String {
        switch self {
        case .bouldering: return "Bouldering"
        case .sport: return "Sport"
        case .trad: return "Trad"
        case .topRope: return "Top Rope"
        }
    }
}

// MARK: - Grade Scale

enum GradeScale: String, Codable, CaseIterable, Sendable {
    case v = "V"
    case yds = "YDS"
    case french = "FRENCH"
    case uiaa = "UIAA"

    var displayName: String {
        switch self {
        case .v: return "V Scale"
        case .yds: return "YDS"
        case .french: return "French"
        case .uiaa: return "UIAA"
        }
    }

    /// Returns whether this scale is for boulder or route climbing
    var isBoulderScale: Bool {
        return self == .v
    }
}

// MARK: - Attempt Outcome

enum AttemptOutcome: String, Codable, Sendable {
    case `try`
    case send

    var displayName: String {
        switch self {
        case .try: return "Try"
        case .send: return "Send"
        }
    }

    var systemImage: String {
        switch self {
        case .try: return "xmark.circle"
        case .send: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Send Type

enum SendType: String, Codable, CaseIterable, Sendable {
    case onsight
    case flash
    case redpoint
    case pinkpoint
    case project

    var displayName: String {
        switch self {
        case .onsight: return "Onsight"
        case .flash: return "Flash"
        case .redpoint: return "Redpoint"
        case .pinkpoint: return "Pinkpoint"
        case .project: return "Project"
        }
    }

    var description: String {
        switch self {
        case .onsight:
            return "First try, no prior knowledge"
        case .flash:
            return "First try with beta"
        case .redpoint:
            return "Clean send after working"
        case .pinkpoint:
            return "Clean send with pre-placed gear"
        case .project:
            return "Long-term project send"
        }
    }
}

// MARK: - Tag Impact

enum TagImpact: String, Codable, CaseIterable, Sendable {
    case helped
    case hindered
    case neutral

    var displayName: String {
        switch self {
        case .helped: return "Helped"
        case .hindered: return "Hindered"
        case .neutral: return "Neutral"
        }
    }

    var systemImage: String {
        switch self {
        case .helped: return "arrow.up.circle.fill"
        case .hindered: return "arrow.down.circle.fill"
        case .neutral: return "circle.fill"
        }
    }
}
