import SwiftUI

/// Primary container component with Liquid Glass styling
struct SCGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(SCSpacing.md)
            .background {
                if UIAccessibility.isReduceTransparencyEnabled {
                    RoundedRectangle(cornerRadius: SCCornerRadius.card)
                        .fill(Color(UIColor.systemBackground))
                } else {
                    RoundedRectangle(cornerRadius: SCCornerRadius.card)
                        .fill(SCColors.cardBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }
}

#Preview {
    SCGlassCard {
        VStack(alignment: .leading, spacing: SCSpacing.xs) {
            Text("Card Title")
                .font(SCTypography.cardTitle)
            Text("Card content goes here")
                .font(SCTypography.body)
        }
    }
    .padding()
}
