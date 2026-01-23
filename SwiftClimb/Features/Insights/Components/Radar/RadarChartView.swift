// RadarChartView.swift
// SwiftClimb
//
// Custom radar chart for tag impact visualization.

import SwiftUI

/// A radar chart showing tag impacts (helped vs hindered).
///
/// Displays two overlapping polygons:
/// - Green filled: Tags that helped performance
/// - Red dashed: Tags that hindered performance
@MainActor
struct RadarChartView: View {
    let data: [TagRadarPoint]
    var size: CGFloat = 200

    private var labels: [String] {
        data.map { $0.tagName }
    }

    private var helpedValues: [Double] {
        let maxCount = Double(data.map(\.totalCount).max() ?? 1)
        return data.map { Double($0.helpedCount) / maxCount }
    }

    private var hinderedValues: [Double] {
        let maxCount = Double(data.map(\.totalCount).max() ?? 1)
        return data.map { Double($0.hinderedCount) / maxCount }
    }

    private var hasData: Bool {
        !data.isEmpty && data.count >= 3
    }

    var body: some View {
        if hasData {
            chartContent
        } else {
            insufficientDataView
        }
    }

    private var chartContent: some View {
        ZStack {
            // Background grid
            RadarGridShape(sides: data.count, levels: 4)
                .stroke(Color(.systemGray4), lineWidth: 1)

            // Helped polygon (green, filled)
            RadarDataShape(values: helpedValues)
                .fill(SCColors.impactHelped.opacity(0.3))

            RadarDataShape(values: helpedValues)
                .stroke(SCColors.impactHelped, lineWidth: 2)

            // Hindered polygon (red, dashed)
            RadarDataShape(values: hinderedValues)
                .fill(SCColors.impactHindered.opacity(0.15))

            RadarDataShape(values: hinderedValues)
                .stroke(
                    SCColors.impactHindered,
                    style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                )

            // Data point markers
            ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                let helpedRadius = size / 2 * helpedValues[index]
                let angle = angleFor(index: index)

                Circle()
                    .fill(SCColors.impactHelped)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: helpedRadius * cos(angle),
                        y: helpedRadius * sin(angle)
                    )
            }

            // Axis labels
            RadarAxisLabels(labels: labels, size: size)
        }
        .frame(width: size + 80, height: size + 80)
    }

    private var insufficientDataView: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "hexagon")
                .font(.largeTitle)
                .foregroundStyle(SCColors.textTertiary)

            Text("Need at least 3 tags")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Tag more climbs to see impact patterns")
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: size)
    }

    private func angleFor(index: Int) -> Double {
        let anglePerSide = 360.0 / Double(data.count)
        return (-90 + anglePerSide * Double(index)) * .pi / 180
    }
}

// MARK: - Radar Chart with Legend

@MainActor
struct RadarChartWithLegend: View {
    let data: [TagRadarPoint]
    var size: CGFloat = 200

    var body: some View {
        VStack(spacing: SCSpacing.md) {
            RadarChartView(data: data, size: size)

            // Legend
            HStack(spacing: SCSpacing.lg) {
                LegendItem(
                    color: SCColors.impactHelped,
                    label: "Helped",
                    isDashed: false
                )

                LegendItem(
                    color: SCColors.impactHindered,
                    label: "Hindered",
                    isDashed: true
                )
            }

            // Tag counts summary
            if !data.isEmpty {
                tagSummaryView
            }
        }
    }

    private var tagSummaryView: some View {
        VStack(spacing: SCSpacing.xs) {
            ForEach(data.prefix(5)) { point in
                TagSummaryRow(point: point)
            }

            if data.count > 5 {
                Text("+ \(data.count - 5) more tags")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textTertiary)
            }
        }
        .padding(.top, SCSpacing.sm)
    }
}

@MainActor
private struct LegendItem: View {
    let color: Color
    let label: String
    let isDashed: Bool

    var body: some View {
        HStack(spacing: SCSpacing.xxs) {
            if isDashed {
                DashedLine()
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: 20, height: 2)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 20, height: 3)
                    .cornerRadius(1.5)
            }

            Text(label)
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textSecondary)
        }
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

@MainActor
private struct TagSummaryRow: View {
    let point: TagRadarPoint

    var body: some View {
        HStack {
            Text(point.tagName)
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textPrimary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: SCSpacing.sm) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                    Text("\(point.helpedCount)")
                        .font(SCTypography.metadata)
                }
                .foregroundStyle(SCColors.impactHelped)

                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                    Text("\(point.hinderedCount)")
                        .font(SCTypography.metadata)
                }
                .foregroundStyle(SCColors.impactHindered)

                Text("(\(point.totalCount))")
                    .font(SCTypography.label)
                    .foregroundStyle(SCColors.textTertiary)
            }
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
        VStack(spacing: SCSpacing.xl) {
            RadarChartView(data: sampleData)

            RadarChartWithLegend(data: sampleData)

            RadarChartView(data: [])
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
