import SwiftUI
import SwiftData

@MainActor
struct InsightsView: View {
    @Environment(\.premiumService) private var premiumService

    @State private var isPremium = false
    @State private var isLoading = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if isPremium {
                    PremiumInsightsContent()
                } else {
                    InsightsUpsellView(onUpgrade: { showPaywall = true })
                }
            }
            .navigationTitle("Insights")
        }
        .task {
            await checkPremiumStatus()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func checkPremiumStatus() async {
        isLoading = true
        defer { isLoading = false }

        isPremium = await premiumService?.isPremium() ?? false
    }
}

// MARK: - Premium Content

@MainActor
private struct PremiumInsightsContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.lg) {
                // TODO: Implement actual insights content
                Text("Premium insights content")
                    .font(SCTypography.body)
            }
            .padding()
        }
    }
}

// MARK: - Upsell View

@MainActor
private struct InsightsUpsellView: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: SCSpacing.lg) {
            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 80))
                .foregroundStyle(SCColors.textSecondary)

            Text("Unlock Your Climbing Insights")
                .font(SCTypography.screenHeader)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track grade progression over time")
                FeatureRow(icon: "calendar", text: "View climbing frequency trends")
                FeatureRow(icon: "figure.climbing", text: "Analyze send rates by discipline")
                FeatureRow(icon: "brain.head.profile", text: "Identify strengths and weaknesses")
            }
            .padding()
            .background(SCColors.surfaceSecondary)
            .cornerRadius(SCCornerRadius.card)

            Spacer()

            SCPrimaryButton(
                title: "Upgrade to Premium",
                action: onUpgrade,
                isFullWidth: true
            )
        }
        .padding()
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: SCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(SCTypography.body)
        }
    }
}
