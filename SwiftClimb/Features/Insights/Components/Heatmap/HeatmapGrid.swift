// HeatmapGrid.swift
// SwiftClimb
//
// Calendar grid showing climbing activity over time.

import SwiftUI

/// A GitHub-style activity heatmap showing climbing sessions over time.
///
/// The grid displays up to 52 weeks of activity with 7 rows (days of week).
/// Each cell's color intensity represents the level of climbing activity.
@MainActor
struct HeatmapGrid: View {
    let data: [HeatmapDayData]
    let timeRange: InsightsTimeRange

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let rowCount = 7

    private var calendar: Calendar { Calendar.current }

    private var dateRange: (start: Date, end: Date) {
        let end = Date()
        let start: Date

        switch timeRange {
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        case .allTime:
            // Show last year for all time
            start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        }

        return (start, end)
    }

    private var weeksToShow: Int {
        let (start, end) = dateRange
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, (days / 7) + 1)
    }

    private var dataByDate: [Date: HeatmapDayData] {
        Dictionary(uniqueKeysWithValues: data.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xs) {
            // Month labels
            monthLabelsRow

            HStack(alignment: .top, spacing: cellSpacing) {
                // Day of week labels
                dayLabelsColumn

                // Grid
                ScrollView(.horizontal, showsIndicators: false) {
                    gridContent
                }
            }
        }
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<weeksToShow, id: \.self) { weekIndex in
                weekColumn(weekIndex: weekIndex)
            }
        }
    }

    private func weekColumn(weekIndex: Int) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<rowCount, id: \.self) { dayIndex in
                let date = dateForCell(weekIndex: weekIndex, dayIndex: dayIndex)
                let dayData = date.flatMap { dataByDate[calendar.startOfDay(for: $0)] }

                HeatmapCell(data: dayData, cellSize: cellSize)
            }
        }
    }

    private func dateForCell(weekIndex: Int, dayIndex: Int) -> Date? {
        let (start, end) = dateRange

        // Find the first Sunday before or on start date
        var firstSunday = start
        while calendar.component(.weekday, from: firstSunday) != 1 {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: firstSunday) else { break }
            firstSunday = prev
        }

        // Calculate date for this cell
        let daysToAdd = (weekIndex * 7) + dayIndex
        guard let cellDate = calendar.date(byAdding: .day, value: daysToAdd, to: firstSunday) else {
            return nil
        }

        // Only return date if it's within range
        if cellDate >= start && cellDate <= end {
            return cellDate
        }
        return nil
    }

    // MARK: - Labels

    private var dayLabelsColumn: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<rowCount, id: \.self) { dayIndex in
                Text(dayLabel(for: dayIndex))
                    .font(.system(size: 8))
                    .foregroundStyle(SCColors.textTertiary)
                    .frame(width: 20, height: cellSize, alignment: .trailing)
            }
        }
    }

    private func dayLabel(for index: Int) -> String {
        // 0 = Sunday, only show Mon, Wed, Fri
        switch index {
        case 1: return "Mon"
        case 3: return "Wed"
        case 5: return "Fri"
        default: return ""
        }
    }

    private var monthLabelsRow: some View {
        HStack(spacing: 0) {
            // Spacer for day labels
            Color.clear.frame(width: 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(monthLabels, id: \.offset) { label in
                        Text(label.name)
                            .font(.system(size: 10))
                            .foregroundStyle(SCColors.textSecondary)
                            .frame(width: CGFloat(label.weekSpan) * (cellSize + cellSpacing), alignment: .leading)
                    }
                }
            }
        }
    }

    private var monthLabels: [(name: String, weekSpan: Int, offset: Int)] {
        var labels: [(name: String, weekSpan: Int, offset: Int)] = []
        let (start, _) = dateRange
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var currentDate = start
        var currentMonth = calendar.component(.month, from: currentDate)
        var weekCount = 0
        var offset = 0

        for weekIndex in 0..<weeksToShow {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: start) else { continue }
            let month = calendar.component(.month, from: weekStart)

            if month != currentMonth {
                if weekCount > 0 {
                    labels.append((name: formatter.string(from: currentDate), weekSpan: weekCount, offset: offset))
                }
                offset += weekCount
                currentDate = weekStart
                currentMonth = month
                weekCount = 1
            } else {
                weekCount += 1
            }
        }

        // Add final month
        if weekCount > 0 {
            labels.append((name: formatter.string(from: currentDate), weekSpan: weekCount, offset: offset))
        }

        return labels
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [HeatmapDayData] = {
        var data: [HeatmapDayData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            // Random activity
            let hasActivity = Int.random(in: 0...2) > 0
            if hasActivity {
                data.append(HeatmapDayData(
                    date: date,
                    sessionCount: Int.random(in: 1...2),
                    climbCount: Int.random(in: 1...20),
                    primaryDiscipline: Bool.random() ? .bouldering : .sport
                ))
            }
        }

        return data
    }()

    VStack(spacing: SCSpacing.lg) {
        HeatmapGrid(data: sampleData, timeRange: .month)
        HeatmapGrid(data: sampleData, timeRange: .year)
    }
    .padding()
}
