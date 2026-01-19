import SwiftUI

/// Persistent banner for active session
struct SCSessionBanner: View {
    let sessionStartTime: Date
    let climbCount: Int
    let attemptCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SCSpacing.sm) {
                VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                    Text("Session in progress")
                        .font(SCTypography.secondary.weight(.semibold))
                        .foregroundStyle(SCColors.textPrimary)

                    HStack(spacing: SCSpacing.sm) {
                        Label("\(climbCount) climbs", systemImage: "figure.climbing")
                        Label("\(attemptCount) attempts", systemImage: "scope")
                    }
                    .font(SCTypography.label)
                    .foregroundStyle(SCColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SCColors.textSecondary)
            }
            .padding(SCSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: SCCornerRadius.card)
                    .fill(SCColors.primary.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: SCCornerRadius.card)
                            .stroke(SCColors.primary, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SCSessionBanner(
        sessionStartTime: Date(),
        climbCount: 5,
        attemptCount: 12
    ) {}
    .padding()
}
