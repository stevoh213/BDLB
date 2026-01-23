// InsightsModels.swift
// SwiftClimb
//
// Data structures for Premium Insights feature.
// These models represent computed analytics data derived from sessions and climbs.

import Foundation

// MARK: - Time Range

/// Time range filter for insights data.
enum InsightsTimeRange: String, CaseIterable, Sendable {
    case week
    case month
    case year
    case allTime

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }

    /// Start date for this time range (from current date).
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return Date.distantPast
        }
    }
}

// MARK: - Heatmap Data

/// Represents activity data for a single day in the heatmap.
struct HeatmapDayData: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let sessionCount: Int
    let climbCount: Int
    let primaryDiscipline: Discipline?

    /// Intensity level 0-4 based on climb count.
    var intensityLevel: Int {
        switch climbCount {
        case 0: return 0
        case 1...5: return 1
        case 6...10: return 2
        case 11...20: return 3
        default: return 4
        }
    }
}

// MARK: - Grade Pyramid Data

/// Represents a bucket in the grade pyramid chart.
struct GradeBucket: Identifiable, Sendable {
    let id = UUID()
    let gradeLabel: String
    let gradeScore: Int
    let attemptCount: Int
    let sendCount: Int
    let onsightFlashCount: Int

    /// Percentage of sends vs attempts.
    var sendRate: Double {
        guard attemptCount > 0 else { return 0 }
        return Double(sendCount) / Double(attemptCount) * 100
    }
}

// MARK: - Tag Radar Data

/// Represents a single point on the tag radar chart.
struct TagRadarPoint: Identifiable, Sendable {
    let id = UUID()
    let tagName: String
    let helpedCount: Int
    let hinderedCount: Int
    let totalCount: Int

    /// Helped ratio from 0 to 1.
    var helpedRatio: Double {
        guard totalCount > 0 else { return 0.5 }
        return Double(helpedCount) / Double(totalCount)
    }

    /// Hindered ratio from 0 to 1.
    var hinderedRatio: Double {
        guard totalCount > 0 else { return 0.5 }
        return Double(hinderedCount) / Double(totalCount)
    }
}

/// Category of tags for radar chart.
enum TagCategory: String, CaseIterable, Sendable {
    case skills = "Skills"
    case techniques = "Techniques"
    case wallStyles = "Wall Styles"
}

// MARK: - Grade Progression Data

/// Represents a data point for grade progression over time.
struct GradeProgressionPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let maxBoulderScore: Int?
    let maxRouteScore: Int?

    /// Display label for boulder grade.
    var boulderGradeLabel: String? {
        guard let score = maxBoulderScore else { return nil }
        return gradeLabel(score: score, isBoulder: true)
    }

    /// Display label for route grade.
    var routeGradeLabel: String? {
        guard let score = maxRouteScore else { return nil }
        return gradeLabel(score: score, isBoulder: false)
    }

    private func gradeLabel(score: Int, isBoulder: Bool) -> String {
        if isBoulder {
            // Approximate V grade from score (10 = V0, 100 = V17)
            let vGrade = max(0, (score - 10) * 17 / 90)
            return "V\(vGrade)"
        } else {
            // Approximate YDS from score
            if score < 26 {
                return "5.\(max(5, score / 4))"
            } else {
                let base = (score - 26) / 12 + 10
                let letters = ["a", "b", "c", "d"]
                let letterIndex = ((score - 26) % 12) / 3
                return "5.\(base)\(letters[min(letterIndex, 3)])"
            }
        }
    }
}

// MARK: - Session Duration Data

/// Represents session duration data for a time period.
struct SessionDurationPoint: Identifiable, Sendable {
    let id = UUID()
    let periodStart: Date
    let avgDurationMinutes: Double
    let sessionCount: Int

    var formattedDuration: String {
        let hours = Int(avgDurationMinutes) / 60
        let minutes = Int(avgDurationMinutes) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Discipline Breakdown Data

/// Represents discipline distribution data.
struct DisciplineBreakdown: Identifiable, Sendable {
    let id = UUID()
    let discipline: Discipline
    let climbCount: Int
    let percentage: Double

    var formattedPercentage: String {
        return String(format: "%.0f%%", percentage)
    }
}

// MARK: - Key Stats

/// Summary statistics for the selected time range.
struct KeyStats: Sendable {
    let totalClimbs: Int
    let totalSessions: Int
    let totalAttempts: Int
    let sendCount: Int
    let uniquePartners: Int

    let maxBoulderGrade: String?
    let maxSportGrade: String?
    let maxTradGrade: String?
    let maxTopRopeGrade: String?

    var sendRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(sendCount) / Double(totalAttempts) * 100
    }

    var formattedSendRate: String {
        return String(format: "%.0f%%", sendRate)
    }

    static let empty = KeyStats(
        totalClimbs: 0,
        totalSessions: 0,
        totalAttempts: 0,
        sendCount: 0,
        uniquePartners: 0,
        maxBoulderGrade: nil,
        maxSportGrade: nil,
        maxTradGrade: nil,
        maxTopRopeGrade: nil
    )
}

// MARK: - Overview Stats

/// Quick overview statistics displayed in cards.
struct OverviewStats: Sendable {
    let totalClimbs: Int
    let totalSessions: Int
    let sendRatePercentage: Double
    let uniquePartners: Int

    static let empty = OverviewStats(
        totalClimbs: 0,
        totalSessions: 0,
        sendRatePercentage: 0,
        uniquePartners: 0
    )
}
