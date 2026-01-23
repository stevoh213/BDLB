// HeatmapCell.swift
// SwiftClimb
//
// Individual day cell in the activity heatmap.

import SwiftUI

/// A single cell representing one day in the activity heatmap.
///
/// Color intensity indicates climbing activity level:
/// - Level 0: Empty (no activity)
/// - Level 1-4: Increasing intensity
///
/// Color hue indicates primary discipline:
/// - Orange: Bouldering
/// - Blue: Sport/Trad/Top Rope
@MainActor
struct HeatmapCell: View {
    let data: HeatmapDayData?
    var cellSize: CGFloat = 12

    private var color: Color {
        guard let data, data.climbCount > 0 else {
            return Color(.systemGray5)
        }

        let baseColor: Color
        switch data.primaryDiscipline {
        case .bouldering:
            baseColor = .orange
        case .sport, .trad, .topRope:
            baseColor = .blue
        case nil:
            baseColor = .green
        }

        let opacity: Double
        switch data.intensityLevel {
        case 0: opacity = 0.0
        case 1: opacity = 0.3
        case 2: opacity = 0.5
        case 3: opacity = 0.7
        default: opacity = 1.0
        }

        return baseColor.opacity(opacity)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: cellSize, height: cellSize)
            .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let data else { return "No data" }

        if data.climbCount == 0 {
            return "No activity"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        return "\(dateFormatter.string(from: data.date)): \(data.climbCount) climbs, \(data.sessionCount) sessions"
    }
}

// MARK: - Empty Cell

extension HeatmapCell {
    /// Create an empty cell for days without data.
    static var empty: HeatmapCell {
        HeatmapCell(data: nil)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 2) {
        HeatmapCell(data: nil)

        HeatmapCell(data: HeatmapDayData(
            date: Date(),
            sessionCount: 1,
            climbCount: 3,
            primaryDiscipline: .bouldering
        ))

        HeatmapCell(data: HeatmapDayData(
            date: Date(),
            sessionCount: 1,
            climbCount: 8,
            primaryDiscipline: .bouldering
        ))

        HeatmapCell(data: HeatmapDayData(
            date: Date(),
            sessionCount: 2,
            climbCount: 15,
            primaryDiscipline: .sport
        ))

        HeatmapCell(data: HeatmapDayData(
            date: Date(),
            sessionCount: 2,
            climbCount: 25,
            primaryDiscipline: .sport
        ))
    }
    .padding()
}
