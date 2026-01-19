import SwiftUI

/// Metric display pill for readiness, RPE, pump level
struct SCMetricPill: View {
    let label: String
    let value: Int
    let maxValue: Int

    init(label: String, value: Int, maxValue: Int = 10) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    var body: some View {
        HStack(spacing: SCSpacing.xs) {
            Text(label)
                .font(SCTypography.label)
                .foregroundStyle(SCColors.textSecondary)

            Text("\(value)")
                .font(SCTypography.body.weight(.semibold))
                .foregroundStyle(metricColor)
        }
        .padding(.horizontal, SCSpacing.sm)
        .padding(.vertical, SCSpacing.xs)
        .background {
            Capsule()
                .fill(metricColor.opacity(0.15))
        }
    }

    private var metricColor: Color {
        let percentage = Double(value) / Double(maxValue)
        if percentage <= 0.3 {
            return SCColors.metricLow
        } else if percentage <= 0.6 {
            return SCColors.metricMedium
        } else {
            return SCColors.metricHigh
        }
    }
}

#Preview {
    VStack(spacing: SCSpacing.md) {
        HStack(spacing: SCSpacing.sm) {
            SCMetricPill(label: "RPE", value: 2, maxValue: 10)
            SCMetricPill(label: "RPE", value: 5, maxValue: 10)
            SCMetricPill(label: "RPE", value: 8, maxValue: 10)
        }

        HStack(spacing: SCSpacing.sm) {
            SCMetricPill(label: "Mental", value: 3, maxValue: 5)
            SCMetricPill(label: "Physical", value: 4, maxValue: 5)
            SCMetricPill(label: "Pump", value: 2, maxValue: 5)
        }
    }
    .padding()
}
