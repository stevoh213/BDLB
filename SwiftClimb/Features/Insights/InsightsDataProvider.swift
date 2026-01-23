// InsightsDataProvider.swift
// SwiftClimb
//
// Observable data provider that computes analytics from session data.
// All computations are derived from the sessions array provided by the view.

import Foundation
import SwiftData
import SwiftUI

/// Provides computed insights data from climbing sessions.
///
/// This provider transforms raw session/climb data into analytics-ready
/// structures for the Premium Insights feature. It respects the selected
/// time range and discipline filters.
///
/// ## Usage
///
/// ```swift
/// @State private var dataProvider = InsightsDataProvider()
///
/// var body: some View {
///     PremiumInsightsContent(dataProvider: dataProvider)
///         .task {
///             dataProvider.updateSessions(allSessions)
///         }
/// }
/// ```
@Observable
@MainActor
final class InsightsDataProvider {
    // MARK: - Inputs

    /// All sessions from SwiftData query.
    private(set) var sessions: [SCSession] = []

    /// Selected time range filter.
    var timeRange: InsightsTimeRange = .month

    /// Selected discipline filter for grade pyramid.
    var selectedDiscipline: Discipline = .bouldering

    /// Selected tag category for radar chart.
    var selectedTagCategory: TagCategory = .skills

    // MARK: - Tag Lookups (for radar chart)

    /// Skill tag name lookup by ID.
    private(set) var skillTagNames: [UUID: String] = [:]

    /// Technique tag name lookup by ID.
    private(set) var techniqueTagNames: [UUID: String] = [:]

    /// Wall style tag name lookup by ID.
    private(set) var wallStyleTagNames: [UUID: String] = [:]

    // MARK: - Direct Impact Storage (workaround for SwiftData relationships)

    /// All skill impacts (queried directly, not via relationship).
    private(set) var skillImpacts: [SCSkillImpact] = []

    /// All technique impacts (queried directly, not via relationship).
    private(set) var techniqueImpacts: [SCTechniqueImpact] = []

    /// All wall style impacts (queried directly, not via relationship).
    private(set) var wallStyleImpacts: [SCWallStyleImpact] = []

    // MARK: - Computed: Filtered Sessions

    /// Sessions filtered by current time range.
    var filteredSessions: [SCSession] {
        let startDate = timeRange.startDate
        return sessions.filter { session in
            session.startedAt >= startDate && session.deletedAt == nil
        }
    }

    /// All climbs from filtered sessions.
    var filteredClimbs: [SCClimb] {
        filteredSessions.flatMap { session in
            session.climbs.filter { $0.deletedAt == nil }
        }
    }

    /// All attempts from filtered climbs.
    var filteredAttempts: [SCAttempt] {
        filteredClimbs.flatMap { climb in
            climb.attempts.filter { $0.deletedAt == nil }
        }
    }

    // MARK: - Computed: Overview Stats

    var overviewStats: OverviewStats {
        let climbs = filteredClimbs
        let attempts = filteredAttempts
        let sessions = filteredSessions

        let sendCount = attempts.filter { $0.outcome == .send }.count
        let sendRate = attempts.isEmpty ? 0 : Double(sendCount) / Double(attempts.count) * 100

        // Count unique belay partners
        var partnerIds = Set<UUID>()
        var partnerNames = Set<String>()

        for climb in climbs {
            if let partnerId = climb.belayPartnerUserId {
                partnerIds.insert(partnerId)
            }
            if let partnerName = climb.belayPartnerName, !partnerName.isEmpty {
                partnerNames.insert(partnerName.lowercased())
            }
        }

        let uniquePartners = partnerIds.count + partnerNames.count

        return OverviewStats(
            totalClimbs: climbs.count,
            totalSessions: sessions.count,
            sendRatePercentage: sendRate,
            uniquePartners: uniquePartners
        )
    }

    // MARK: - Computed: Key Stats

    var keyStats: KeyStats {
        let climbs = filteredClimbs
        let attempts = filteredAttempts
        let sessions = filteredSessions

        let sendCount = attempts.filter { $0.outcome == .send }.count

        // Calculate unique partners
        var partnerIds = Set<UUID>()
        var partnerNames = Set<String>()

        for climb in climbs {
            if let partnerId = climb.belayPartnerUserId {
                partnerIds.insert(partnerId)
            }
            if let partnerName = climb.belayPartnerName, !partnerName.isEmpty {
                partnerNames.insert(partnerName.lowercased())
            }
        }

        // Find max grades per discipline
        let maxBoulder = maxGrade(for: .bouldering, in: climbs)
        let maxSport = maxGrade(for: .sport, in: climbs)
        let maxTrad = maxGrade(for: .trad, in: climbs)
        let maxTopRope = maxGrade(for: .topRope, in: climbs)

        return KeyStats(
            totalClimbs: climbs.count,
            totalSessions: sessions.count,
            totalAttempts: attempts.count,
            sendCount: sendCount,
            uniquePartners: partnerIds.count + partnerNames.count,
            maxBoulderGrade: maxBoulder,
            maxSportGrade: maxSport,
            maxTradGrade: maxTrad,
            maxTopRopeGrade: maxTopRope
        )
    }

    // MARK: - Computed: Heatmap Data

    var heatmapData: [HeatmapDayData] {
        let calendar = Calendar.current
        var dataByDate: [Date: (sessions: Int, climbs: Int, discipline: Discipline?)] = [:]

        // Group sessions by day
        for session in filteredSessions {
            let dayStart = calendar.startOfDay(for: session.startedAt)
            var existing = dataByDate[dayStart] ?? (sessions: 0, climbs: 0, discipline: nil)
            existing.sessions += 1
            existing.climbs += session.climbs.filter { $0.deletedAt == nil }.count
            existing.discipline = session.discipline
            dataByDate[dayStart] = existing
        }

        // Convert to array
        return dataByDate.map { date, data in
            HeatmapDayData(
                date: date,
                sessionCount: data.sessions,
                climbCount: data.climbs,
                primaryDiscipline: data.discipline
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Computed: Grade Pyramid Data

    var gradePyramidData: [GradeBucket] {
        let disciplineClimbs = filteredClimbs.filter { $0.discipline == selectedDiscipline }

        // Group by grade score
        var buckets: [Int: (label: String, attempts: Int, sends: Int, onsightFlash: Int)] = [:]

        for climb in disciplineClimbs {
            guard let score = climb.gradeScoreMin else { continue }
            let label = climb.gradeOriginal ?? "Unknown"

            var bucket = buckets[score] ?? (label: label, attempts: 0, sends: 0, onsightFlash: 0)
            let attempts = climb.attempts.filter { $0.deletedAt == nil }
            bucket.attempts += attempts.count
            bucket.sends += attempts.filter { $0.outcome == .send }.count
            bucket.onsightFlash += attempts.filter {
                $0.outcome == .send && ($0.sendType == .onsight || $0.sendType == .flash)
            }.count
            buckets[score] = bucket
        }

        return buckets.map { score, data in
            GradeBucket(
                gradeLabel: data.label,
                gradeScore: score,
                attemptCount: data.attempts,
                sendCount: data.sends,
                onsightFlashCount: data.onsightFlash
            )
        }.sorted { $0.gradeScore < $1.gradeScore }
    }

    // MARK: - Computed: Tag Radar Data

    var tagRadarData: [TagRadarPoint] {
        switch selectedTagCategory {
        case .skills:
            return computeSkillRadarData()
        case .techniques:
            return computeTechniqueRadarData()
        case .wallStyles:
            return computeWallStyleRadarData()
        }
    }

    // MARK: - Computed: Grade Progression

    var gradeProgressionData: [GradeProgressionPoint] {
        let calendar = Calendar.current

        // Group sessions by week
        var weeklyMax: [Date: (boulder: Int?, route: Int?)] = [:]

        for session in filteredSessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start ?? session.startedAt

            var existing = weeklyMax[weekStart] ?? (boulder: nil, route: nil)

            for climb in session.climbs.filter({ $0.deletedAt == nil }) {
                guard climb.hasSend, let score = climb.gradeScoreMin else { continue }

                if climb.discipline == .bouldering {
                    existing.boulder = max(existing.boulder ?? 0, score)
                } else {
                    existing.route = max(existing.route ?? 0, score)
                }
            }

            weeklyMax[weekStart] = existing
        }

        return weeklyMax.map { date, grades in
            GradeProgressionPoint(
                date: date,
                maxBoulderScore: grades.boulder,
                maxRouteScore: grades.route
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Computed: Session Duration

    var sessionDurationData: [SessionDurationPoint] {
        let calendar = Calendar.current

        // Group sessions by week
        var weeklyDurations: [Date: [TimeInterval]] = [:]

        for session in filteredSessions {
            guard let duration = session.duration else { continue }
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start ?? session.startedAt

            weeklyDurations[weekStart, default: []].append(duration)
        }

        return weeklyDurations.map { date, durations in
            let avgMinutes = durations.reduce(0, +) / Double(durations.count) / 60
            return SessionDurationPoint(
                periodStart: date,
                avgDurationMinutes: avgMinutes,
                sessionCount: durations.count
            )
        }.sorted { $0.periodStart < $1.periodStart }
    }

    // MARK: - Computed: Discipline Split

    var disciplineBreakdown: [DisciplineBreakdown] {
        let climbs = filteredClimbs
        guard !climbs.isEmpty else { return [] }

        var counts: [Discipline: Int] = [:]
        for climb in climbs {
            counts[climb.discipline, default: 0] += 1
        }

        let total = Double(climbs.count)
        return counts.map { discipline, count in
            DisciplineBreakdown(
                discipline: discipline,
                climbCount: count,
                percentage: Double(count) / total * 100
            )
        }.sorted { $0.percentage > $1.percentage }
    }

    // MARK: - Public Methods

    /// Update the sessions data.
    func updateSessions(_ newSessions: [SCSession]) {
        sessions = newSessions
    }

    /// Update skill tag name lookup.
    func updateSkillTags(_ tags: [SCSkillTag]) {
        skillTagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
    }

    /// Update technique tag name lookup.
    func updateTechniqueTags(_ tags: [SCTechniqueTag]) {
        techniqueTagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
    }

    /// Update wall style tag name lookup.
    func updateWallStyleTags(_ tags: [SCWallStyleTag]) {
        wallStyleTagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
    }

    /// Update skill impacts (queried directly from SwiftData).
    func updateSkillImpacts(_ impacts: [SCSkillImpact]) {
        skillImpacts = impacts
    }

    /// Update technique impacts (queried directly from SwiftData).
    func updateTechniqueImpacts(_ impacts: [SCTechniqueImpact]) {
        techniqueImpacts = impacts
    }

    /// Update wall style impacts (queried directly from SwiftData).
    func updateWallStyleImpacts(_ impacts: [SCWallStyleImpact]) {
        wallStyleImpacts = impacts
    }

    // MARK: - Private Helpers

    private func maxGrade(for discipline: Discipline, in climbs: [SCClimb]) -> String? {
        let disciplineClimbs = climbs.filter {
            $0.discipline == discipline && $0.hasSend
        }

        guard let maxClimb = disciplineClimbs.max(by: { ($0.gradeScoreMin ?? 0) < ($1.gradeScoreMin ?? 0) }),
              let gradeLabel = maxClimb.gradeOriginal else {
            return nil
        }

        return gradeLabel
    }

    private func computeSkillRadarData() -> [TagRadarPoint] {
        var tagCounts: [String: (helped: Int, hindered: Int, total: Int)] = [:]

        // Get IDs of filtered climbs for matching
        let filteredClimbIds = Set(filteredClimbs.map(\.id))

        // Filter impacts to only those belonging to filtered climbs
        let relevantImpacts = skillImpacts.filter { impact in
            impact.deletedAt == nil && filteredClimbIds.contains(impact.climbId)
        }

        for impact in relevantImpacts {
            let tagName = skillTagNames[impact.tagId] ?? "Unknown"
            var counts = tagCounts[tagName] ?? (helped: 0, hindered: 0, total: 0)
            counts.total += 1

            switch impact.impact {
            case .helped: counts.helped += 1
            case .hindered: counts.hindered += 1
            case .neutral: break
            }

            tagCounts[tagName] = counts
        }

        return tagCounts.map { name, counts in
            TagRadarPoint(
                tagName: name,
                helpedCount: counts.helped,
                hinderedCount: counts.hindered,
                totalCount: counts.total
            )
        }
        .filter { $0.tagName != "Unknown" }
        .sorted { $0.totalCount > $1.totalCount }
        .prefix(8)
        .map { $0 }
    }

    private func computeTechniqueRadarData() -> [TagRadarPoint] {
        var tagCounts: [String: (helped: Int, hindered: Int, total: Int)] = [:]

        // Get IDs of filtered climbs for matching
        let filteredClimbIds = Set(filteredClimbs.map(\.id))

        // Filter impacts to only those belonging to filtered climbs
        let relevantImpacts = techniqueImpacts.filter { impact in
            impact.deletedAt == nil && filteredClimbIds.contains(impact.climbId)
        }

        for impact in relevantImpacts {
            let tagName = techniqueTagNames[impact.tagId] ?? "Unknown"
            var counts = tagCounts[tagName] ?? (helped: 0, hindered: 0, total: 0)
            counts.total += 1

            switch impact.impact {
            case .helped: counts.helped += 1
            case .hindered: counts.hindered += 1
            case .neutral: break
            }

            tagCounts[tagName] = counts
        }

        return tagCounts.map { name, counts in
            TagRadarPoint(
                tagName: name,
                helpedCount: counts.helped,
                hinderedCount: counts.hindered,
                totalCount: counts.total
            )
        }
        .filter { $0.tagName != "Unknown" }
        .sorted { $0.totalCount > $1.totalCount }
        .prefix(8)
        .map { $0 }
    }

    private func computeWallStyleRadarData() -> [TagRadarPoint] {
        var tagCounts: [String: (helped: Int, hindered: Int, total: Int)] = [:]

        // Get IDs of filtered climbs for matching
        let filteredClimbIds = Set(filteredClimbs.map(\.id))

        // Filter impacts to only those belonging to filtered climbs
        let relevantImpacts = wallStyleImpacts.filter { impact in
            impact.deletedAt == nil && filteredClimbIds.contains(impact.climbId)
        }

        for impact in relevantImpacts {
            let tagName = wallStyleTagNames[impact.tagId] ?? "Unknown"
            var counts = tagCounts[tagName] ?? (helped: 0, hindered: 0, total: 0)
            counts.total += 1

            switch impact.impact {
            case .helped: counts.helped += 1
            case .hindered: counts.hindered += 1
            case .neutral: break
            }

            tagCounts[tagName] = counts
        }

        return tagCounts.map { name, counts in
            TagRadarPoint(
                tagName: name,
                helpedCount: counts.helped,
                hinderedCount: counts.hindered,
                totalCount: counts.total
            )
        }
        .filter { $0.tagName != "Unknown" }
        .sorted { $0.totalCount > $1.totalCount }
        .prefix(8)
        .map { $0 }
    }
}
