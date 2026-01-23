// GradeSendsChart.swift
// SwiftClimb
//
// Stacked horizontal bar chart showing sends by grade.

import SwiftUI
import Charts

/// A stacked horizontal bar chart showing send distribution by grade.
///
/// Uses green for regular sends and blue for onsight/flash sends.
/// Part of the grade pyramid visualization.
@MainActor
struct GradeSendsChart: View {
    let data: [GradeBucket]
    let maxValue: Int

    private var sortedData: [GradeBucket] {
        data.sorted { $0.gradeScore > $1.gradeScore }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xs) {
            Text("Sends")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)

            if data.isEmpty {
                emptyView
            } else {
                chartContent
            }
        }
    }

    private var chartContent: some View {
        VStack(spacing: SCSpacing.xs) {
            Chart(sortedData) { bucket in
                // Regular sends (non-onsight/flash)
                let regularSends = bucket.sendCount - bucket.onsightFlashCount

                BarMark(
                    x: .value("Sends", regularSends),
                    y: .value("Grade", bucket.gradeLabel)
                )
                .foregroundStyle(SCColors.impactHelped)
                .cornerRadius(4)

                // Onsight/Flash sends
                BarMark(
                    x: .value("Onsight/Flash", bucket.onsightFlashCount),
                    y: .value("Grade", bucket.gradeLabel)
                )
                .foregroundStyle(SCColors.primary)
                .cornerRadius(4)
            }
            .chartXScale(domain: 0...max(maxValue, 1))
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    if let count = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(count)")
                                .font(.system(size: 10))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let grade = value.as(String.self) {
                        AxisValueLabel {
                            Text(grade)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                }
            }
            .frame(height: CGFloat(sortedData.count * 28 + 40))

            // Legend
            HStack(spacing: SCSpacing.md) {
                HStack(spacing: SCSpacing.xxs) {
                    Circle()
                        .fill(SCColors.impactHelped)
                        .frame(width: 8, height: 8)
                    Text("Sends")
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                }

                HStack(spacing: SCSpacing.xxs) {
                    Circle()
                        .fill(SCColors.primary)
                        .frame(width: 8, height: 8)
                    Text("Onsight/Flash")
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }
        }
    }

    private var emptyView: some View {
        Text("No sends logged")
            .font(SCTypography.metadata)
            .foregroundStyle(SCColors.textTertiary)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [GradeBucket] = [
        GradeBucket(gradeLabel: "V7", gradeScore: 50, attemptCount: 15, sendCount: 2, onsightFlashCount: 0),
        GradeBucket(gradeLabel: "V6", gradeScore: 45, attemptCount: 25, sendCount: 8, onsightFlashCount: 2),
        GradeBucket(gradeLabel: "V5", gradeScore: 40, attemptCount: 40, sendCount: 20, onsightFlashCount: 5),
        GradeBucket(gradeLabel: "V4", gradeScore: 35, attemptCount: 35, sendCount: 28, onsightFlashCount: 10),
        GradeBucket(gradeLabel: "V3", gradeScore: 30, attemptCount: 20, sendCount: 18, onsightFlashCount: 12)
    ]

    ScrollView {
        GradeSendsChart(data: sampleData, maxValue: 30)
            .padding()
    }
    .background(Color(.systemBackground))
}
