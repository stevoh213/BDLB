// GradeProgressionSection.swift
// SwiftClimb
//
// Line chart showing grade progression over time.

import SwiftUI
import Charts

/// A section displaying grade progression over time using a line chart.
///
/// Shows two lines:
/// - Orange: Maximum boulder grade sent per week
/// - Blue: Maximum route grade sent per week
@MainActor
struct GradeProgressionSection: View {
    let data: [GradeProgressionPoint]

    private var hasBoulderData: Bool {
        data.contains { $0.maxBoulderScore != nil }
    }

    private var hasRouteData: Bool {
        data.contains { $0.maxRouteScore != nil }
    }

    private var hasData: Bool {
        hasBoulderData || hasRouteData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Grade Progression",
                subtitle: "Max grades over time",
                systemImage: "chart.line.uptrend.xyaxis"
            )

            if hasData {
                chartContent
            } else {
                EmptyChartView(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "Send some climbs to see your progression"
                )
            }
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Chart {
                if hasBoulderData {
                    ForEach(data.filter { $0.maxBoulderScore != nil }) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Grade", point.maxBoulderScore ?? 0)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Grade", point.maxBoulderScore ?? 0)
                        )
                        .foregroundStyle(.orange)
                        .symbolSize(30)
                    }
                }

                if hasRouteData {
                    ForEach(data.filter { $0.maxRouteScore != nil }) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Grade", point.maxRouteScore ?? 0)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Grade", point.maxRouteScore ?? 0)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(30)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let score = value.as(Int.self) {
                        AxisValueLabel {
                            Text(gradeLabel(for: score))
                                .font(.system(size: 10))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatDate(date))
                                .font(.system(size: 10))
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 200)

            // Legend
            ChartLegend(items: legendItems)
        }
        .padding(SCSpacing.md)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private var yAxisDomain: ClosedRange<Int> {
        let allScores = data.compactMap { $0.maxBoulderScore } + data.compactMap { $0.maxRouteScore }
        let minScore = (allScores.min() ?? 0) - 5
        let maxScore = (allScores.max() ?? 50) + 5
        return max(0, minScore)...min(100, maxScore)
    }

    private var legendItems: [(color: Color, label: String)] {
        var items: [(Color, String)] = []
        if hasBoulderData {
            items.append((.orange, "Boulder"))
        }
        if hasRouteData {
            items.append((.blue, "Route"))
        }
        return items
    }

    private func gradeLabel(for score: Int) -> String {
        // Simplified grade label from score
        if hasBoulderData && !hasRouteData {
            let vGrade = max(0, (score - 10) * 17 / 90)
            return "V\(vGrade)"
        } else if hasRouteData && !hasBoulderData {
            return ydsLabel(for: score)
        } else {
            // Mixed, just show score
            return "\(score)"
        }
    }

    private func ydsLabel(for score: Int) -> String {
        if score < 26 {
            return "5.\(max(5, score / 4))"
        } else {
            let base = (score - 26) / 12 + 10
            return "5.\(base)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Chart Legend

@MainActor
struct ChartLegend: View {
    let items: [(color: Color, label: String)]

    var body: some View {
        HStack(spacing: SCSpacing.md) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: SCSpacing.xxs) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)

                    Text(item.label)
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Empty Chart View

@MainActor
struct EmptyChartView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(SCColors.textTertiary)

            Text(message)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .padding(SCSpacing.md)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [GradeProgressionPoint] = {
        var points: [GradeProgressionPoint] = []
        let calendar = Calendar.current

        for weekOffset in 0..<12 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) else { continue }

            points.append(GradeProgressionPoint(
                date: date,
                maxBoulderScore: 25 + weekOffset * 2 + Int.random(in: -3...3),
                maxRouteScore: 35 + weekOffset + Int.random(in: -2...2)
            ))
        }

        return points.reversed()
    }()

    ScrollView {
        VStack(spacing: SCSpacing.lg) {
            GradeProgressionSection(data: sampleData)
            GradeProgressionSection(data: [])
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
