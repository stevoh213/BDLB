import SwiftUI

/// Empty state view shown when no active session exists
struct EmptySessionState: View {
    let onStartSession: () -> Void

    var body: some View {
        VStack(spacing: SCSpacing.lg) {
            Spacer()

            Image(systemName: "figure.climbing")
                .font(.system(size: 80))
                .foregroundStyle(SCColors.textSecondary)

            VStack(spacing: SCSpacing.sm) {
                Text("Ready to Climb?")
                    .font(SCTypography.screenHeader)

                Text("Start a session to track your climbs and progress")
                    .font(SCTypography.body)
                    .foregroundStyle(SCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SCPrimaryButton(
                title: "Start Session",
                action: onStartSession,
                isFullWidth: true
            )
            .padding(.horizontal, SCSpacing.xl)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    EmptySessionState(onStartSession: {})
}
