// OverviewCardsSection.swift
// SwiftClimb
//
// 2x2 grid of stat cards showing key metrics.

import SwiftUI

/// A section displaying overview statistics in a 2x2 grid.
///
/// Shows:
/// - Total Climbs
/// - Total Sessions
/// - Send Rate
/// - Unique Partners
///
/// All metrics respect the current time range filter.
@MainActor
struct OverviewCardsSection: View {
    let stats: OverviewStats

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Overview",
                systemImage: "chart.bar.fill"
            )

            LazyVGrid(columns: columns, spacing: SCSpacing.md) {
                StatCard(
                    icon: "figure.climbing",
                    intValue: stats.totalClimbs,
                    label: "Total Climbs",
                    color: .orange
                )

                StatCard(
                    icon: "calendar",
                    intValue: stats.totalSessions,
                    label: "Sessions",
                    color: .blue
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    percentage: stats.sendRatePercentage,
                    label: "Send Rate",
                    color: SCColors.impactHelped
                )

                StatCard(
                    icon: "person.2.fill",
                    intValue: stats.uniquePartners,
                    label: "Partners",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        OverviewCardsSection(
            stats: OverviewStats(
                totalClimbs: 127,
                totalSessions: 24,
                sendRatePercentage: 68.5,
                uniquePartners: 5
            )
        )
        .padding()
    }
    .background(Color(.systemBackground))
}
