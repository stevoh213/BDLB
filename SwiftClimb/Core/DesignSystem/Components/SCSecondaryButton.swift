import SwiftUI

/// Secondary action button
struct SCSecondaryButton: View {
    let title: String
    let action: () -> Void
    var isFullWidth: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SCTypography.body.weight(.medium))
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .frame(minHeight: 44)
                .padding(.horizontal, SCSpacing.md)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    VStack(spacing: SCSpacing.md) {
        SCSecondaryButton(title: "Normal Button") {}
        SCSecondaryButton(title: "Full Width", action: {}, isFullWidth: true)
    }
    .padding()
}
