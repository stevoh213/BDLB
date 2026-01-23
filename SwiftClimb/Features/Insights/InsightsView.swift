// InsightsView.swift
// SwiftClimb
//
// Main view for the Insights tab showing premium analytics.

import SwiftUI
import SwiftData

@MainActor
struct InsightsView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.syncActor) private var syncActor
    @Environment(\.currentUserId) private var currentUserId

    // Query all sessions for insights
    @Query(
        filter: #Predicate<SCSession> { $0.deletedAt == nil },
        sort: \SCSession.startedAt,
        order: .reverse
    )
    private var allSessions: [SCSession]

    // Query tag catalogs for radar chart lookups
    @Query private var skillTags: [SCSkillTag]
    @Query private var techniqueTags: [SCTechniqueTag]
    @Query private var wallStyleTags: [SCWallStyleTag]

    // Query impacts directly (workaround for SwiftData relationship not being established during sync)
    @Query(filter: #Predicate<SCSkillImpact> { $0.deletedAt == nil })
    private var skillImpacts: [SCSkillImpact]

    @Query(filter: #Predicate<SCTechniqueImpact> { $0.deletedAt == nil })
    private var techniqueImpacts: [SCTechniqueImpact]

    @Query(filter: #Predicate<SCWallStyleImpact> { $0.deletedAt == nil })
    private var wallStyleImpacts: [SCWallStyleImpact]

    @State private var isPremium = false
    @State private var isLoading = true
    @State private var showPaywall = false
    @State private var isSyncing = false
    @State private var dataProvider = InsightsDataProvider()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if isPremium {
                    PremiumInsightsContent(dataProvider: dataProvider)
                } else {
                    ScrollView {
                        InsightsUpsellView(onUpgrade: { showPaywall = true })
                    }
                }
            }
            .refreshable {
                await performManualSync()
            }
            .navigationTitle("Insights")
        }
        .task {
            await checkPremiumStatus()
        }
        .task(id: allSessions.count) {
            // Update data provider when sessions change
            dataProvider.updateSessions(allSessions)
        }
        .task(id: skillTags.count) {
            // Update tag lookups for radar charts
            dataProvider.updateSkillTags(skillTags)
            dataProvider.updateTechniqueTags(techniqueTags)
            dataProvider.updateWallStyleTags(wallStyleTags)
        }
        .task(id: skillImpacts.count + techniqueImpacts.count + wallStyleImpacts.count) {
            // Update impacts directly (bypasses broken SwiftData relationship)
            dataProvider.updateSkillImpacts(skillImpacts)
            dataProvider.updateTechniqueImpacts(techniqueImpacts)
            dataProvider.updateWallStyleImpacts(wallStyleImpacts)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var loadingView: some View {
        VStack(spacing: SCSpacing.md) {
            ProgressView()
            Text("Loading insights...")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performManualSync() async {
        guard let syncActor = syncActor, let userId = currentUserId else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await syncActor.performSync(userId: userId)
            // Re-check premium status after sync
            await checkPremiumStatus()
        } catch {
            print("Manual sync failed: \(error)")
        }
    }

    private func checkPremiumStatus() async {
        isLoading = true
        defer { isLoading = false }

        isPremium = await premiumService?.isPremium() ?? false
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
                FeatureRow(icon: "triangle.fill", text: "Visualize your grade pyramid")
                FeatureRow(icon: "hexagon.fill", text: "See tag impact patterns")
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

// MARK: - Preview

#Preview("Premium") {
    InsightsView()
        .modelContainer(for: SCSession.self, inMemory: true)
}

#Preview("Non-Premium") {
    InsightsView()
        .modelContainer(for: SCSession.self, inMemory: true)
}
