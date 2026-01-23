// DisciplineSplitSection.swift
// SwiftClimb
//
// Pie/bar chart showing discipline distribution.

import SwiftUI
import Charts

/// A section displaying the distribution of climbs by discipline.
///
/// Uses a donut chart to visualize the breakdown of climbing disciplines,
/// helping identify training balance.
@MainActor
struct DisciplineSplitSection: View {
    let data: [DisciplineBreakdown]

    private var hasData: Bool {
        !data.isEmpty
    }

    private var totalClimbs: Int {
        data.reduce(0) { $0 + $1.climbCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Discipline Split",
                subtitle: hasData ? "\(totalClimbs) total climbs" : nil,
                systemImage: "chart.pie.fill"
            )

            if hasData {
                chartContent
            } else {
                EmptyChartView(
                    icon: "chart.pie",
                    message: "Log some climbs to see your discipline breakdown"
                )
            }
        }
    }

    private var chartContent: some View {
        HStack(spacing: SCSpacing.lg) {
            // Donut chart
            Chart(data) { item in
                SectorMark(
                    angle: .value("Climbs", item.climbCount),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(colorFor(item.discipline))
                .cornerRadius(4)
            }
            .frame(width: 120, height: 120)

            // Legend
            VStack(alignment: .leading, spacing: SCSpacing.xs) {
                ForEach(data) { item in
                    DisciplineLegendRow(
                        discipline: item.discipline,
                        count: item.climbCount,
                        percentage: item.percentage,
                        color: colorFor(item.discipline)
                    )
                }
            }

            Spacer()
        }
        .padding(SCSpacing.md)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private func colorFor(_ discipline: Discipline) -> Color {
        switch discipline {
        case .bouldering: return .orange
        case .sport: return .blue
        case .trad: return .green
        case .topRope: return .purple
        }
    }
}

// MARK: - Discipline Legend Row

@MainActor
private struct DisciplineLegendRow: View {
    let discipline: Discipline
    let count: Int
    let percentage: Double
    let color: Color

    var body: some View {
        HStack(spacing: SCSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(discipline.displayName)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textPrimary)

            Spacer()

            Text("\(count)")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)

            Text(String(format: "%.0f%%", percentage))
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textTertiary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Alternative Bar View

@MainActor
struct DisciplineSplitBarSection: View {
    let data: [DisciplineBreakdown]

    private var hasData: Bool {
        !data.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Discipline Split",
                systemImage: "chart.bar.fill"
            )

            if hasData {
                VStack(spacing: SCSpacing.sm) {
                    ForEach(data) { item in
                        DisciplineBarRow(
                            discipline: item.discipline,
                            percentage: item.percentage,
                            count: item.climbCount
                        )
                    }
                }
                .padding(SCSpacing.md)
                .background(SCColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
            } else {
                EmptyChartView(
                    icon: "chart.bar",
                    message: "Log some climbs to see your discipline breakdown"
                )
            }
        }
    }
}

@MainActor
private struct DisciplineBarRow: View {
    let discipline: Discipline
    let percentage: Double
    let count: Int

    private var color: Color {
        switch discipline {
        case .bouldering: return .orange
        case .sport: return .blue
        case .trad: return .green
        case .topRope: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xxs) {
            HStack {
                Text(discipline.displayName)
                    .font(SCTypography.body)
                    .foregroundStyle(SCColors.textPrimary)

                Spacer()

                Text("\(count) climbs")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage / 100)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [DisciplineBreakdown] = [
        DisciplineBreakdown(discipline: .bouldering, climbCount: 85, percentage: 55),
        DisciplineBreakdown(discipline: .sport, climbCount: 45, percentage: 29),
        DisciplineBreakdown(discipline: .trad, climbCount: 15, percentage: 10),
        DisciplineBreakdown(discipline: .topRope, climbCount: 10, percentage: 6)
    ]

    ScrollView {
        VStack(spacing: SCSpacing.lg) {
            DisciplineSplitSection(data: sampleData)
            DisciplineSplitBarSection(data: sampleData)
            DisciplineSplitSection(data: [])
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
