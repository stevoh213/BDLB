// GradePyramidSection.swift
// SwiftClimb
//
// Container section for grade pyramid charts with discipline picker.

import SwiftUI

/// A section displaying the grade pyramid with attempts and sends charts.
///
/// Includes a discipline picker to filter by climbing type.
/// Shows both attempts (red) and sends (green/blue) distributions.
@MainActor
struct GradePyramidSection: View {
    let data: [GradeBucket]
    @Binding var selectedDiscipline: Discipline

    private var hasData: Bool {
        !data.isEmpty
    }

    private var maxAttempts: Int {
        data.map(\.attemptCount).max() ?? 0
    }

    private var maxSends: Int {
        data.map(\.sendCount).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                InsightsSectionHeader(
                    title: "Grade Pyramid",
                    subtitle: hasData ? pyramidSummary : nil,
                    systemImage: "triangle.fill"
                )

                Spacer()
            }

            // Discipline picker
            Picker("Discipline", selection: $selectedDiscipline) {
                ForEach(Discipline.allCases, id: \.self) { discipline in
                    Text(discipline.displayName).tag(discipline)
                }
            }
            .pickerStyle(.segmented)

            if hasData {
                pyramidContent
            } else {
                EmptyChartView(
                    icon: "triangle",
                    message: "No \(selectedDiscipline.displayName.lowercased()) climbs logged"
                )
            }
        }
    }

    private var pyramidContent: some View {
        VStack(spacing: SCSpacing.lg) {
            // Summary stats
            PyramidSummaryRow(data: data)

            Divider()

            // Attempts chart
            GradeAttemptsChart(data: data, maxValue: maxAttempts)

            Divider()

            // Sends chart
            GradeSendsChart(data: data, maxValue: maxSends)
        }
        .padding(SCSpacing.md)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private var pyramidSummary: String {
        let totalAttempts = data.reduce(0) { $0 + $1.attemptCount }
        let totalSends = data.reduce(0) { $0 + $1.sendCount }
        let sendRate = totalAttempts > 0 ? Double(totalSends) / Double(totalAttempts) * 100 : 0

        return "\(totalSends) sends, \(String(format: "%.0f", sendRate))% rate"
    }
}

// MARK: - Pyramid Summary Row

@MainActor
private struct PyramidSummaryRow: View {
    let data: [GradeBucket]

    private var totalAttempts: Int {
        data.reduce(0) { $0 + $1.attemptCount }
    }

    private var totalSends: Int {
        data.reduce(0) { $0 + $1.sendCount }
    }

    private var totalOnsightFlash: Int {
        data.reduce(0) { $0 + $1.onsightFlashCount }
    }

    private var sendRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalSends) / Double(totalAttempts) * 100
    }

    private var flashRate: Double {
        guard totalSends > 0 else { return 0 }
        return Double(totalOnsightFlash) / Double(totalSends) * 100
    }

    var body: some View {
        HStack(spacing: SCSpacing.lg) {
            SummaryItem(
                value: "\(totalAttempts)",
                label: "Attempts",
                color: SCColors.impactHindered
            )

            SummaryItem(
                value: "\(totalSends)",
                label: "Sends",
                color: SCColors.impactHelped
            )

            SummaryItem(
                value: String(format: "%.0f%%", sendRate),
                label: "Send Rate",
                color: SCColors.primary
            )

            SummaryItem(
                value: String(format: "%.0f%%", flashRate),
                label: "Flash Rate",
                color: .purple
            )
        }
    }
}

@MainActor
private struct SummaryItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: SCSpacing.xxs) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(SCTypography.label)
                .foregroundStyle(SCColors.textTertiary)
        }
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
        VStack(spacing: SCSpacing.lg) {
            GradePyramidSection(data: sampleData, selectedDiscipline: .constant(.bouldering))
            GradePyramidSection(data: [], selectedDiscipline: .constant(.sport))
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
