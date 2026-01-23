// TimeRangePicker.swift
// SwiftClimb
//
// Global time range filter for insights data.

import SwiftUI

/// A segmented control for selecting the insights time range.
///
/// This picker controls the global time filter that affects all
/// sections in the Premium Insights view.
///
/// ## Usage
///
/// ```swift
/// @Bindable var dataProvider = dataProvider
/// TimeRangePicker(selection: $dataProvider.timeRange)
/// ```
@MainActor
struct TimeRangePicker: View {
    @Binding var selection: InsightsTimeRange

    var body: some View {
        Picker("Time Range", selection: $selection) {
            ForEach(InsightsTimeRange.allCases, id: \.self) { range in
                Text(range.displayName)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time range filter")
    }
}

// MARK: - Section Header with Time Range

/// A section header that includes an optional time range description.
@MainActor
struct InsightsSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xxs) {
            HStack(spacing: SCSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(SCColors.primary)
                }

                Text(title)
                    .font(SCTypography.sectionHeader)
                    .fontWeight(.semibold)
                    .foregroundStyle(SCColors.textPrimary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: SCSpacing.lg) {
        TimeRangePicker(selection: .constant(.month))

        InsightsSectionHeader(
            title: "Overview",
            subtitle: "Last 30 days",
            systemImage: "chart.bar.fill"
        )

        InsightsSectionHeader(
            title: "Grade Pyramid",
            systemImage: "triangle.fill"
        )
    }
    .padding()
}
