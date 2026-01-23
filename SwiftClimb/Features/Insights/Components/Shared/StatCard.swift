// StatCard.swift
// SwiftClimb
//
// Reusable stat card component for displaying key metrics.

import SwiftUI

/// A card displaying a single statistic with an icon.
///
/// Used in the overview section to display key metrics like
/// total climbs, sessions, send rate, and unique partners.
///
/// ## Usage
///
/// ```swift
/// StatCard(
///     icon: "figure.climbing",
///     value: "127",
///     label: "Total Climbs",
///     color: .orange
/// )
/// ```
@MainActor
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = SCColors.primary

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            Spacer()

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(SCColors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(label)
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textSecondary)
                .lineLimit(1)
        }
        .padding(SCSpacing.md)
        .frame(minHeight: 120)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Convenience Initializers

extension StatCard {
    /// Create a stat card with an integer value.
    init(icon: String, intValue: Int, label: String, color: Color = SCColors.primary) {
        self.icon = icon
        self.value = "\(intValue)"
        self.label = label
        self.color = color
    }

    /// Create a stat card with a percentage value.
    init(icon: String, percentage: Double, label: String, color: Color = SCColors.primary) {
        self.icon = icon
        self.value = String(format: "%.0f%%", percentage)
        self.label = label
        self.color = color
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: SCSpacing.md) {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: SCSpacing.md) {
            StatCard(
                icon: "figure.climbing",
                intValue: 127,
                label: "Total Climbs",
                color: .orange
            )

            StatCard(
                icon: "calendar",
                intValue: 24,
                label: "Sessions",
                color: .blue
            )

            StatCard(
                icon: "checkmark.circle.fill",
                percentage: 68.5,
                label: "Send Rate",
                color: .green
            )

            StatCard(
                icon: "person.2.fill",
                intValue: 5,
                label: "Partners",
                color: .purple
            )
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
