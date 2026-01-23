// PremiumInsightsContent.swift
// SwiftClimb
//
// Main content view for Premium Insights feature.
// Combines all insight sections with a global time filter.

import SwiftUI
import SwiftData

/// The main content view for Premium Insights.
///
/// Displays all analytics sections in a scrollable layout:
/// 1. Time range picker (sticky)
/// 2. Overview cards (climbs, sessions, send rate, partners)
/// 3. Max grades by discipline
/// 4. Activity heatmap
/// 5. Grade progression chart
/// 6. Discipline breakdown
/// 7. Session duration trends
/// 8. Grade pyramid
/// 9. Tag impact radar
///
/// All sections respect the global time range filter.
@MainActor
struct PremiumInsightsContent: View {
    @Bindable var dataProvider: InsightsDataProvider

    var body: some View {
        VStack(spacing: 0) {
            // Sticky time range picker
            VStack(spacing: 0) {
                TimeRangePicker(selection: $dataProvider.timeRange)
                    .padding(.horizontal)
                    .padding(.vertical, SCSpacing.sm)

                Divider()
            }
            .background(Color(.systemBackground))

            // Scrollable content
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    // Overview stats
                    OverviewCardsSection(stats: dataProvider.overviewStats)

                    // Max grades
                    KeyStatsSection(stats: dataProvider.keyStats)

                    // Activity heatmap
                    ActivityHeatmapSection(
                        data: dataProvider.heatmapData,
                        timeRange: dataProvider.timeRange
                    )

                    // Grade progression
                    GradeProgressionSection(data: dataProvider.gradeProgressionData)

                    // Discipline split
                    DisciplineSplitSection(data: dataProvider.disciplineBreakdown)

                    // Session duration
                    SessionDurationSection(data: dataProvider.sessionDurationData)

                    // Grade pyramid
                    GradePyramidSection(
                        data: dataProvider.gradePyramidData,
                        selectedDiscipline: $dataProvider.selectedDiscipline
                    )

                    // Tag radar
                    TagRadarSection(
                        data: dataProvider.tagRadarData,
                        selectedCategory: $dataProvider.selectedTagCategory
                    )

                    // Bottom spacing
                    Color.clear.frame(height: SCSpacing.xl)
                }
                .padding(.horizontal)
                .padding(.top, SCSpacing.md)
            }
        }
    }
}

// MARK: - Compact Insights View

/// A compact version of insights for dashboard/widget usage.
@MainActor
struct CompactInsightsView: View {
    let dataProvider: InsightsDataProvider

    var body: some View {
        VStack(spacing: SCSpacing.md) {
            // Quick stats
            HStack(spacing: SCSpacing.md) {
                CompactStatItem(
                    value: "\(dataProvider.overviewStats.totalClimbs)",
                    label: "Climbs",
                    icon: "figure.climbing"
                )

                CompactStatItem(
                    value: dataProvider.keyStats.formattedSendRate,
                    label: "Send Rate",
                    icon: "checkmark.circle.fill"
                )

                if let maxBoulder = dataProvider.keyStats.maxBoulderGrade {
                    CompactStatItem(
                        value: maxBoulder,
                        label: "Max Boulder",
                        icon: "arrow.up"
                    )
                }
            }
        }
    }
}

@MainActor
private struct CompactStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: SCSpacing.xxs) {
            HStack(spacing: SCSpacing.xxs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(SCColors.primary)

            Text(label)
                .font(SCTypography.label)
                .foregroundStyle(SCColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Full Insights") {
    let dataProvider = InsightsDataProvider()

    PremiumInsightsContent(dataProvider: dataProvider)
        .background(Color(.systemBackground))
}

#Preview("Compact") {
    let dataProvider = InsightsDataProvider()

    CompactInsightsView(dataProvider: dataProvider)
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
        .padding()
}
