import SwiftUI

/// Primary call-to-action button
struct SCPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isFullWidth: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SCSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(SCTypography.body.weight(.semibold))
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .padding(.horizontal, SCSpacing.md)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: SCSpacing.md) {
        SCPrimaryButton(title: "Normal Button") {}
        SCPrimaryButton(title: "Loading Button", action: {}, isLoading: true)
        SCPrimaryButton(title: "Full Width", action: {}, isFullWidth: true)
    }
    .padding()
}
