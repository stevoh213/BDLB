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
        let trimmed = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return nil }

        // Try parsing in order of specificity
        if let vGrade = parseVGrade(trimmed) {
            return vGrade
        }
        if let ydsGrade = parseYDSGrade(trimmed) {
            return ydsGrade
        }
        if let frenchGrade = parseFrenchGrade(input.trimmingCharacters(in: .whitespaces)) {
            return frenchGrade
        }
        if let uiaaGrade = parseUIAAGrade(trimmed) {
            return uiaaGrade
        }

        return nil
    }

    // MARK: - V Grade (Bouldering)
    // V0, VB, V1, V2, ... V17, V3/V4

    private static func parseVGrade(_ input: String) -> Grade? {
        guard input.hasPrefix("V") else { return nil }
        let rest = String(input.dropFirst())

        // Handle VB (beginner) grade
        if rest == "B" {
            return Grade(original: "VB", scale: .v, scoreMin: 0)
        }

        // Check for slash grade like V3/V4
        if let slashIndex = rest.firstIndex(of: "/") {
            let lowStr = String(rest[..<slashIndex])
            let highStr = String(rest[rest.index(after: slashIndex)...])
                .replacingOccurrences(of: "V", with: "")

            guard let low = Int(lowStr), let high = Int(highStr),
                  low >= 0, low <= 17, high >= 0, high <= 17 else {
                return nil
            }
            let scoreMin = vGradeToScore(low)
            let scoreMax = vGradeToScore(high)
            return Grade(original: "V\(low)/V\(high)", scale: .v, scoreMin: scoreMin, scoreMax: scoreMax)
        }

        // Standard V grade
        guard let number = Int(rest), number >= 0, number <= 17 else {
            return nil
        }
        let score = vGradeToScore(number)
        return Grade(original: "V\(number)", scale: .v, scoreMin: score)
    }

    private static func vGradeToScore(_ grade: Int) -> Int {
        // Normalize V grades to a 0-100 scale
        // V0 = 10, V17 = 100
        return 10 + (grade * 90 / 17)
    }

    // MARK: - YDS Grade (Route Climbing)
    // 5.0-5.9, 5.9+/-, 5.10a-5.10d, ... 5.15a-5.15d

    private static func parseYDSGrade(_ input: String) -> Grade? {
        guard input.hasPrefix("5.") else { return nil }
        let rest = String(input.dropFirst(2))

        // Check for slash grade like 5.10A/B
        if let slashIndex = rest.firstIndex(of: "/") {
            let lowPart = String(rest[..<slashIndex])
            let highModifier = String(rest[rest.index(after: slashIndex)...])

            guard let (lowNum, lowMod) = parseYDSComponents(lowPart) else { return nil }

            // High part could be just "B" or "5.10B"
            let highMod = highModifier.last.map { String($0) } ?? highModifier

            let scoreMin = ydsToScore(lowNum, modifier: lowMod)
            let scoreMax = ydsToScore(lowNum, modifier: highMod)
            return Grade(original: input, scale: .yds, scoreMin: scoreMin, scoreMax: scoreMax)
        }

        guard let (number, modifier) = parseYDSComponents(rest) else { return nil }
        let score = ydsToScore(number, modifier: modifier)
        return Grade(original: input, scale: .yds, scoreMin: score)
    }

    private static func parseYDSComponents(_ input: String) -> (Int, String?)? {
        var numStr = ""
        var modifier: String?

        for char in input {
            if char.isNumber {
                numStr.append(char)
            } else if "ABCD".contains(char) {
                modifier = String(char)
                break
            } else if "+-".contains(char) {
                modifier = String(char)
                break
            }
        }

        guard let number = Int(numStr), number >= 0, number <= 15 else {
            return nil
        }

        // +/- modifiers only valid for 5.9 and above (before letter grades start at 5.10)
        if let mod = modifier, "+-".contains(mod), number < 9 {
            return nil
        }

        return (number, modifier)
    }

    private static func ydsToScore(_ number: Int, modifier: String?) -> Int {
        // 5.0 = 5, 5.9 = 25, 5.9+ = 27, 5.10a = 30, 5.15d = 100
        var score: Int

        if number <= 9 {
            score = 5 + (number * 20 / 9)
            // Handle +/- for 5.9
            if number == 9 {
                switch modifier {
                case "+": score += 2
                case "-": score -= 2
                default: break
                }
            }
        } else {
            // 5.10+ grades with letter modifiers
            let baseScore = 26 + ((number - 10) * 12)
            let modifierOffset: Int
            switch modifier {
            case "A": modifierOffset = 0
            case "B": modifierOffset = 3
            case "C": modifierOffset = 6
            case "D": modifierOffset = 9
            default: modifierOffset = 0
            }
            score = baseScore + modifierOffset
        }

        return min(score, 100)
    }

    // MARK: - French Grade
    // 4a, 5c+, 6a, 7b+, 8a, 9c

    private static func parseFrenchGrade(_ input: String) -> Grade? {
        let lowercased = input.lowercased()

        // French grades: digit followed by a/b/c and optional +
        let pattern = #"^(\d)([abc])(\+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: lowercased,
                  range: NSRange(lowercased.startIndex..., in: lowercased)
              ) else {
            return nil
        }

        guard let numberRange = Range(match.range(at: 1), in: lowercased),
              let letterRange = Range(match.range(at: 2), in: lowercased) else {
            return nil
        }

        let number = Int(String(lowercased[numberRange])) ?? 0
        let letter = String(lowercased[letterRange])
        let hasPlus = match.range(at: 3).location != NSNotFound

        guard number >= 3, number <= 9 else { return nil }

        let score = frenchToScore(number, letter: letter, plus: hasPlus)
        let original = "\(number)\(letter)\(hasPlus ? "+" : "")"
        return Grade(original: original, scale: .french, scoreMin: score)
    }

    private static func frenchToScore(_ number: Int, letter: String, plus: Bool) -> Int {
        // 4a = 15, 9c = 100
        let baseScore = (number - 3) * 14
        let letterOffset: Int
        switch letter {
        case "a": letterOffset = 0
        case "b": letterOffset = 4
        case "c": letterOffset = 8
        default: letterOffset = 0
        }
        let plusOffset = plus ? 2 : 0

        return min(15 + baseScore + letterOffset + plusOffset, 100)
    }

    // MARK: - UIAA Grade
    // Roman numerals I-XII with optional +/-

    private static func parseUIAAGrade(_ input: String) -> Grade? {
        var remaining = input
        var modifier: String?

        // Check for trailing +/-
        if remaining.hasSuffix("+") {
            modifier = "+"
            remaining = String(remaining.dropLast())
        } else if remaining.hasSuffix("-") {
            modifier = "-"
            remaining = String(remaining.dropLast())
        }

        guard let number = romanToInt(remaining), number >= 1, number <= 12 else {
            return nil
        }

        let score = uiaaToScore(number, modifier: modifier)
        return Grade(original: input, scale: .uiaa, scoreMin: score)
    }

    private static func romanToInt(_ roman: String) -> Int? {
        let romanNumerals: [(String, Int)] = [
            ("XII", 12), ("XI", 11), ("IX", 9), ("X", 10),
            ("VIII", 8), ("VII", 7), ("VI", 6), ("IV", 4),
            ("V", 5), ("III", 3), ("II", 2), ("I", 1)
        ]

        for (numeral, value) in romanNumerals {
            if roman == numeral {
                return value
            }
        }
        return nil
    }

    private static func uiaaToScore(_ number: Int, modifier: String?) -> Int {
        // I = 5, XII = 100
        let baseScore = 5 + ((number - 1) * 86 / 11)
        let modifierOffset: Int
        switch modifier {
        case "+": modifierOffset = 3
        case "-": modifierOffset = -3
        default: modifierOffset = 0
        }

        return max(1, min(baseScore + modifierOffset, 100))
    }
}
