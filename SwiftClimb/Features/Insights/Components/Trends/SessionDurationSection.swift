// SessionDurationSection.swift
// SwiftClimb
//
// Bar chart showing average session duration trends.

import SwiftUI
import Charts

/// A section displaying session duration trends using a bar chart.
///
/// Shows average session duration per week/period, helping identify
/// training consistency and volume patterns.
@MainActor
struct SessionDurationSection: View {
    let data: [SessionDurationPoint]

    private var hasData: Bool {
        !data.isEmpty
    }

    private var averageDuration: Double {
        guard !data.isEmpty else { return 0 }
        return data.reduce(0) { $0 + $1.avgDurationMinutes } / Double(data.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Session Duration",
                subtitle: hasData ? "Avg: \(formatDuration(averageDuration))" : nil,
                systemImage: "clock.fill"
            )

            if hasData {
                chartContent
            } else {
                EmptyChartView(
                    icon: "clock.badge.questionmark",
                    message: "Complete some sessions to see duration trends"
                )
            }
        }
    }

    private var chartContent: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Week", point.periodStart),
                y: .value("Duration", point.avgDurationMinutes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...(maxDuration * 1.2))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let minutes = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatDuration(minutes))
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
            }
        }
        .frame(height: 180)
        .padding(SCSpacing.md)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private var maxDuration: Double {
        data.map(\.avgDurationMinutes).max() ?? 120
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [SessionDurationPoint] = {
        var points: [SessionDurationPoint] = []
        let calendar = Calendar.current

        for weekOffset in 0..<8 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) else { continue }

            points.append(SessionDurationPoint(
                periodStart: date,
                avgDurationMinutes: Double.random(in: 60...150),
                sessionCount: Int.random(in: 1...4)
            ))
        }

        return points.reversed()
    }()

    ScrollView {
        VStack(spacing: SCSpacing.lg) {
            SessionDurationSection(data: sampleData)
            SessionDurationSection(data: [])
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
