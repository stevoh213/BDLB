import Foundation

/// Grade normalization and conversion
protocol GradeConversionServiceProtocol: Sendable {
    func parseGrade(_ input: String, scale: GradeScale?) -> Grade?
    func convertGrade(_ grade: Grade, to targetScale: GradeScale) -> Grade?
    func normalizeScore(for grade: Grade) -> Int
}

// Stub implementation
final class GradeConversionService: GradeConversionServiceProtocol {
    func parseGrade(_ input: String, scale: GradeScale?) -> Grade? {
        // TODO: Implement grade parsing
        // Reference OpenBeta grade conventions
        return nil
    }

    func convertGrade(_ grade: Grade, to targetScale: GradeScale) -> Grade? {
        // TODO: Implement grade conversion
        return nil
    }

    func normalizeScore(for grade: Grade) -> Int {
        // TODO: Implement score normalization
        return grade.scoreMin
    }
}
