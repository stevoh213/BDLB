// TagRadarSection.swift
// SwiftClimb
//
// Section container for tag impact radar chart.

import SwiftUI

/// A section displaying tag impact patterns using a radar chart.
///
/// Includes a category picker (Skills, Techniques, Wall Styles)
/// and shows how different tags have helped or hindered climbing performance.
@MainActor
struct TagRadarSection: View {
    let data: [TagRadarPoint]
    @Binding var selectedCategory: TagCategory

    private var hasData: Bool {
        !data.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Tag Impact",
                subtitle: hasData ? impactSummary : nil,
                systemImage: "hexagon.fill"
            )

            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(TagCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if hasData {
                chartContent
            } else {
                emptyContent
            }
        }
    }

    private var chartContent: some View {
        VStack(spacing: SCSpacing.md) {
            RadarChartWithLegend(data: data, size: 180)
        }
        .padding(SCSpacing.md)
        .frame(maxWidth: .infinity)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private var emptyContent: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "tag")
                .font(.largeTitle)
                .foregroundStyle(SCColors.textTertiary)

            Text("No \(selectedCategory.rawValue.lowercased()) tagged yet")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Tag your climbs with \(selectedCategory.rawValue.lowercased()) to see impact patterns")
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SCSpacing.xl)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }

    private var impactSummary: String {
        let totalHelped = data.reduce(0) { $0 + $1.helpedCount }
        let totalHindered = data.reduce(0) { $0 + $1.hinderedCount }

        if totalHelped > totalHindered {
            return "\(totalHelped) helped, \(totalHindered) hindered"
        } else if totalHindered > totalHelped {
            return "\(totalHindered) hindered, \(totalHelped) helped"
        } else {
            return "\(totalHelped + totalHindered) total impacts"
        }
    }
}

// MARK: - Simplified Tag Bar Chart Alternative

/// An alternative bar-based visualization for tag impacts.
@MainActor
struct TagImpactBarSection: View {
    let data: [TagRadarPoint]
    @Binding var selectedCategory: TagCategory

    private var hasData: Bool {
        !data.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Tag Impact",
                systemImage: "chart.bar.xaxis"
            )

            Picker("Category", selection: $selectedCategory) {
                ForEach(TagCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if hasData {
                VStack(spacing: SCSpacing.sm) {
                    ForEach(data.prefix(8)) { point in
                        TagImpactBar(point: point)
                    }
                }
                .padding(SCSpacing.md)
                .background(SCColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
            } else {
                EmptyChartView(
                    icon: "tag",
                    message: "Tag your climbs to see impact patterns"
                )
            }
        }
    }
}

@MainActor
private struct TagImpactBar: View {
    let point: TagRadarPoint

    private var helpedPercentage: Double {
        guard point.totalCount > 0 else { return 0.5 }
        return Double(point.helpedCount) / Double(point.totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.xxs) {
            HStack {
                Text(point.tagName)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textPrimary)

                Spacer()

                HStack(spacing: SCSpacing.xs) {
                    Text("\(point.helpedCount)")
                        .foregroundStyle(SCColors.impactHelped)
                    Text("/")
                        .foregroundStyle(SCColors.textTertiary)
                    Text("\(point.hinderedCount)")
                        .foregroundStyle(SCColors.impactHindered)
                }
                .font(SCTypography.metadata)
            }

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(SCColors.impactHelped)
                        .frame(width: geometry.size.width * helpedPercentage)

                    Rectangle()
                        .fill(SCColors.impactHindered)
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [TagRadarPoint] = [
        TagRadarPoint(tagName: "Crimps", helpedCount: 15, hinderedCount: 5, totalCount: 20),
        TagRadarPoint(tagName: "Slopers", helpedCount: 8, hinderedCount: 12, totalCount: 20),
        TagRadarPoint(tagName: "Overhang", helpedCount: 18, hinderedCount: 3, totalCount: 21),
        TagRadarPoint(tagName: "Slab", helpedCount: 5, hinderedCount: 10, totalCount: 15),
        TagRadarPoint(tagName: "Dynos", helpedCount: 12, hinderedCount: 8, totalCount: 20),
        TagRadarPoint(tagName: "Pinches", helpedCount: 10, hinderedCount: 6, totalCount: 16)
    ]

    ScrollView {
        VStack(spacing: SCSpacing.lg) {
            TagRadarSection(data: sampleData, selectedCategory: .constant(.skills))
            TagImpactBarSection(data: sampleData, selectedCategory: .constant(.techniques))
            TagRadarSection(data: [], selectedCategory: .constant(.wallStyles))
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
