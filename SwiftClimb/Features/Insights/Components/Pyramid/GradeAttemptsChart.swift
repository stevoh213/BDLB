// GradeAttemptsChart.swift
// SwiftClimb
//
// Horizontal bar chart showing attempts by grade.

import SwiftUI
import Charts

/// A horizontal bar chart showing attempt distribution by grade.
///
/// Uses red/orange coloring to indicate attempts/projects that haven't
/// been sent yet. Part of the grade pyramid visualization.
@MainActor
struct GradeAttemptsChart: View {
    let data: [GradeBucket]
    let maxValue: Int

    private var sortedData: [GradeBucket] {
        data.sorted { $0.gradeScore > $1.gradeScore }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xs) {
            Text("Attempts")
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
        Chart(sortedData) { bucket in
            BarMark(
                x: .value("Attempts", bucket.attemptCount),
                y: .value("Grade", bucket.gradeLabel)
            )
            .foregroundStyle(SCColors.impactHindered.opacity(0.7))
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
    }

    private var emptyView: some View {
        Text("No attempts logged")
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
        GradeAttemptsChart(data: sampleData, maxValue: 50)
            .padding()
    }
    .background(Color(.systemBackground))
}
