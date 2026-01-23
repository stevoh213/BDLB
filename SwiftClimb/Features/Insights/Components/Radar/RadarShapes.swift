// RadarShapes.swift
// SwiftClimb
//
// Custom shapes for radar chart visualization.

import SwiftUI

/// A shape that draws concentric polygons for the radar chart background grid.
struct RadarGridShape: Shape {
    let sides: Int
    let levels: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Draw concentric polygons
        for level in 1...levels {
            let levelRadius = radius * CGFloat(level) / CGFloat(levels)
            let polygon = polygonPath(center: center, radius: levelRadius, sides: sides)
            path.addPath(polygon)
        }

        // Draw lines from center to each vertex
        for i in 0..<sides {
            let angle = angleFor(index: i)
            let endPoint = pointAt(angle: angle, radius: radius, center: center)

            path.move(to: center)
            path.addLine(to: endPoint)
        }

        return path
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var path = Path()

        for i in 0..<sides {
            let angle = angleFor(index: i)
            let point = pointAt(angle: angle, radius: radius, center: center)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func angleFor(index: Int) -> Double {
        // Start from top (-90 degrees) and go clockwise
        let anglePerSide = 360.0 / Double(sides)
        return (-90 + anglePerSide * Double(index)) * .pi / 180
    }

    private func pointAt(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

/// A shape that draws a filled polygon connecting data points on the radar chart.
struct RadarDataShape: Shape {
    let values: [Double]  // 0-1 normalized values
    let maxValue: Double

    init(values: [Double], maxValue: Double = 1.0) {
        self.values = values
        self.maxValue = maxValue
    }

    func path(in rect: CGRect) -> Path {
        guard values.count >= 3 else { return Path() }

        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sides = values.count

        for (index, value) in values.enumerated() {
            let normalizedValue = min(value / maxValue, 1.0)
            let angle = angleFor(index: index, sides: sides)
            let point = pointAt(
                angle: angle,
                radius: radius * normalizedValue,
                center: center
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func angleFor(index: Int, sides: Int) -> Double {
        let anglePerSide = 360.0 / Double(sides)
        return (-90 + anglePerSide * Double(index)) * .pi / 180
    }

    private func pointAt(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

// MARK: - Radar Axis Labels

/// View that positions labels around a radar chart.
struct RadarAxisLabels: View {
    let labels: [String]
    let size: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 + 20

            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let angle = angleFor(index: index)
                let position = pointAt(angle: angle, radius: radius, center: center)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(SCColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .position(position)
            }
        }
    }

    private func angleFor(index: Int) -> Double {
        let anglePerSide = 360.0 / Double(labels.count)
        return (-90 + anglePerSide * Double(index)) * .pi / 180
    }

    private func pointAt(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Grid only
        ZStack {
            RadarGridShape(sides: 6, levels: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
        .frame(width: 200, height: 200)

        // Grid with data
        ZStack {
            RadarGridShape(sides: 5, levels: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

            RadarDataShape(values: [0.8, 0.6, 0.9, 0.4, 0.7])
                .fill(Color.green.opacity(0.3))

            RadarDataShape(values: [0.8, 0.6, 0.9, 0.4, 0.7])
                .stroke(Color.green, lineWidth: 2)

            RadarDataShape(values: [0.3, 0.5, 0.2, 0.6, 0.4])
                .fill(Color.red.opacity(0.2))

            RadarDataShape(values: [0.3, 0.5, 0.2, 0.6, 0.4])
                .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
        .frame(width: 200, height: 200)
    }
    .padding()
}
