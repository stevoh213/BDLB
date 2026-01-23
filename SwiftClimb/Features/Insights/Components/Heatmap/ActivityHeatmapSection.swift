// ActivityHeatmapSection.swift
// SwiftClimb
//
// Section container for the activity heatmap with legend.

import SwiftUI

/// A section displaying the activity heatmap with header and legend.
@MainActor
struct ActivityHeatmapSection: View {
    let data: [HeatmapDayData]
    let timeRange: InsightsTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Activity",
                subtitle: activitySummary,
                systemImage: "calendar.badge.clock"
            )

            VStack(spacing: SCSpacing.md) {
                HeatmapGrid(data: data, timeRange: timeRange)

                HeatmapLegend()
            }
            .padding(SCSpacing.md)
            .background(SCColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
        }
    }

    private var activitySummary: String {
        let sessionCount = Set(data.map { Calendar.current.startOfDay(for: $0.date) }).count
        let climbCount = data.reduce(0) { $0 + $1.climbCount }

        if sessionCount == 0 {
            return "No sessions logged"
        }

        return "\(sessionCount) active days, \(climbCount) climbs"
    }
}

// MARK: - Legend

@MainActor
private struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: SCSpacing.md) {
            Spacer()

            Text("Less")
                .font(.system(size: 10))
                .foregroundStyle(SCColors.textTertiary)

            HStack(spacing: 2) {
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 12, height: 12)
                }
            }

            Text("More")
                .font(.system(size: 10))
                .foregroundStyle(SCColors.textTertiary)

            Spacer()

            // Discipline legend
            HStack(spacing: SCSpacing.sm) {
                LegendItem(color: .orange, label: "Boulder")
                LegendItem(color: .blue, label: "Rope")
            }
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color(.systemGray5)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        default: return Color.green
        }
    }
}

@MainActor
private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SCColors.textTertiary)
        }
    }
}

// MARK: - Empty State

@MainActor
struct EmptyHeatmapView: View {
    var body: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(SCColors.textTertiary)

            Text("No activity data")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Start logging sessions to see your activity patterns")
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SCSpacing.lg)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [HeatmapDayData] = {
        var data: [HeatmapDayData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<60 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

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

    ScrollView {
        VStack(spacing: SCSpacing.lg) {
            ActivityHeatmapSection(data: sampleData, timeRange: .month)
            ActivityHeatmapSection(data: [], timeRange: .month)
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
