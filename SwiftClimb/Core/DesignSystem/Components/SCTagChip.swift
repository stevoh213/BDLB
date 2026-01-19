import SwiftUI

/// Tag chip for technique/skill/wall style display
struct SCTagChip: View {
    let title: String
    let impact: TagImpact?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        impact: TagImpact? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.impact = impact
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SCSpacing.xxs) {
                if let impact = impact {
                    impactIndicator(for: impact)
                }
                Text(title)
                    .font(SCTypography.label)
            }
            .padding(.horizontal, SCSpacing.sm)
            .padding(.vertical, SCSpacing.xs)
            .background(chipBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            Capsule()
                .fill(SCColors.primary.opacity(0.2))
                .overlay {
                    Capsule()
                        .stroke(SCColors.primary, lineWidth: 1)
                }
        } else {
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }

    @ViewBuilder
    private func impactIndicator(for impact: TagImpact) -> some View {
        Circle()
            .fill(impactColor(for: impact))
            .frame(width: 6, height: 6)
    }

    private func impactColor(for impact: TagImpact) -> Color {
        switch impact {
        case .helped:
            return SCColors.impactHelped
        case .hindered:
            return SCColors.impactHindered
        case .neutral:
            return SCColors.impactNeutral
        }
    }
}

#Preview {
    VStack(spacing: SCSpacing.md) {
        HStack(spacing: SCSpacing.xs) {
            SCTagChip(title: "Crimp") {}
            SCTagChip(title: "Heel Hook", impact: .helped) {}
            SCTagChip(title: "Overhang", impact: .hindered) {}
        }

        HStack(spacing: SCSpacing.xs) {
            SCTagChip(title: "Selected", isSelected: true) {}
            SCTagChip(title: "Not Selected", isSelected: false) {}
        }
    }
    .padding()
}
