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

    /// Returns available grade scales for this discipline
    var availableGradeScales: [GradeScale] {
        switch self {
        case .bouldering:
            return [.v]
        case .sport, .trad, .topRope:
            return [.yds, .french, .uiaa]
        }
    }

    /// Returns the default grade scale for this discipline
    var defaultGradeScale: GradeScale {
        switch self {
        case .bouldering:
            return .v
        case .sport, .trad, .topRope:
            return .yds
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

    var displayName: String {
        switch self {
        case .onsight: return "Onsight"
        case .flash: return "Flash"
        case .redpoint: return "Redpoint"
        case .pinkpoint: return "Pinkpoint"
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
        }
    }

    /// Returns available tick types for a given discipline.
    ///
    /// Different climbing disciplines use different tick type terminology:
    /// - **Bouldering**: Flash, Onsight only (redpoint/pinkpoint are lead climbing terms)
    /// - **Sport**: All types including pinkpoint (pre-placed quickdraws)
    /// - **Trad**: Onsight, Flash, Redpoint (no pinkpoint - gear isn't pre-placed)
    /// - **Top Rope**: Flash, Onsight only (not leading, so no redpoint/pinkpoint)
    ///
    /// - Parameter discipline: The climbing discipline
    /// - Returns: Array of valid tick types for the discipline
    static func availableTypes(for discipline: Discipline) -> [SendType] {
        switch discipline {
        case .bouldering:
            return [.flash, .onsight]
        case .sport:
            return [.onsight, .flash, .redpoint, .pinkpoint]
        case .trad:
            return [.onsight, .flash, .redpoint]
        case .topRope:
            return [.flash, .onsight]
        }
    }

    /// Returns the inferred tick type based on discipline and attempt count.
    ///
    /// Auto-inference rules:
    /// - **1 attempt**: Flash (first try with beta)
    /// - **2+ attempts on sport/trad**: Redpoint (worked then sent)
    /// - **2+ attempts on boulder/top rope**: Flash (redpoint doesn't apply)
    ///
    /// - Parameters:
    ///   - discipline: The climbing discipline
    ///   - attemptCount: Number of attempts made
    /// - Returns: The inferred tick type
    static func inferred(for discipline: Discipline, attemptCount: Int) -> SendType {
        if attemptCount == 1 {
            return .flash
        }

        // For disciplines that support redpoint (lead climbing), use it for 2+ attempts
        switch discipline {
        case .sport, .trad:
            return .redpoint
        case .bouldering, .topRope:
            // Redpoint doesn't apply - just use flash as the default send type
            return .flash
        }
    }
}

// MARK: - Climb Outcome (for form UI)

/// Represents the final outcome of a climb attempt session.
///
/// Used in the Add Climb form to differentiate between successful sends
/// and ongoing projects. This enum drives the automatic attempt creation
/// logic in ``AddClimbUseCase``.
///
/// ## Usage
///
/// ```swift
/// // In Add Climb form
/// Picker("Outcome", selection: $outcome) {
///     ForEach(ClimbOutcome.allCases, id: \.self) { outcome in
///         Label(outcome.displayName, systemImage: outcome.systemImage)
///             .tag(outcome)
///     }
/// }
/// ```
///
/// ## Attempt Creation Behavior
///
/// - **Send**: Last attempt marked as send, previous as tries
/// - **Project**: All attempts marked as tries (no send type)
///
/// - SeeAlso: ``AddClimbUseCase/createAttempts(userId:sessionId:climbId:attemptCount:outcome:tickType:)``
enum ClimbOutcome: String, Codable, CaseIterable, Sendable {
    /// Successfully completed the climb.
    ///
    /// When this outcome is selected, the last attempt will be marked as a send
    /// with the specified tick type, and all previous attempts will be marked as tries.
    case send

    /// Still working on the climb / didn't complete.
    ///
    /// When this outcome is selected, all attempts will be marked as tries with no send type.
    case project

    var displayName: String {
        switch self {
        case .send: return "Send"
        case .project: return "Project"
        }
    }

    var description: String {
        switch self {
        case .send: return "You completed the climb"
        case .project: return "Still working on it"
        }
    }

    var systemImage: String {
        switch self {
        case .send: return "checkmark.circle.fill"
        case .project: return "arrow.clockwise"
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
