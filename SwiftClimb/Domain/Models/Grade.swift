import Foundation

/// Grade representation with normalization
struct Grade: Codable, Sendable, Equatable {
    let original: String        // "V5", "5.11a", etc.
    let scale: GradeScale       // .v, .yds, .french, .uiaa
    let scoreMin: Int           // Normalized numeric score
    let scoreMax: Int           // For slash grades like "5.10a/b"

    init(
        original: String,
        scale: GradeScale,
        scoreMin: Int,
        scoreMax: Int? = nil
    ) {
        self.original = original
        self.scale = scale
        self.scoreMin = scoreMin
        self.scoreMax = scoreMax ?? scoreMin
    }

    var displayString: String {
        if scoreMin == scoreMax {
            return original
        } else {
            return original // Could format as "V3-V4" etc.
        }
    }

    var isSlashGrade: Bool {
        return scoreMin != scoreMax
    }
}

extension Grade {
    /// Create a Grade from user input string
    static func parse(_ input: String) -> Grade? {
        // TODO: Implement grade parsing logic
        // This is a stub that will need full implementation
        return nil
    }
}
