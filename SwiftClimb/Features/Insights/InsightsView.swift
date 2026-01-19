import SwiftUI
import SwiftData

@MainActor
struct InsightsView: View {
    // Query user profile to check premium status
    @Query private var profiles: [SCProfile]

    @Environment(\.modelContext) private var modelContext

    @State private var isPremium = false

    private var currentProfile: SCProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SCSpacing.md) {
                if isPremium {
                    premiumContentView
                } else {
                    premiumUpsellView
                }
            }
            .padding()
            .navigationTitle("Insights")
        }
        .task {
            // TODO: Load premium status from profile or subscription service
            // For now, default to false
            isPremium = false
        }
    }

    @ViewBuilder
    private var premiumContentView: some View {
        Text("Premium insights coming soon")
            .font(SCTypography.body)
            .foregroundStyle(SCColors.textSecondary)
    }

    @ViewBuilder
    private var premiumUpsellView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("Premium Feature")
                .font(SCTypography.sectionHeader)

            Text("Upgrade to access detailed insights and analytics")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            SCPrimaryButton(title: "Upgrade to Premium", action: {
                // TODO: Navigate to subscription flow
            }, isFullWidth: true)
        }
    }
}

#Preview {
    InsightsView()
}
