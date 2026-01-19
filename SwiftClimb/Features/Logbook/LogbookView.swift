import SwiftUI
import SwiftData

@MainActor
struct LogbookView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.modelContext) private var modelContext

    // Query all completed sessions
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt != nil && $0.deletedAt == nil },
        sort: \SCSession.endedAt,
        order: .reverse
    )
    private var allSessions: [SCSession]

    @State private var isPremium = false
    @State private var showPaywall = false

    // Cutoff date for free users (30 days ago)
    private var freeTierCutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }

    // Sessions visible to current user
    private var visibleSessions: [SCSession] {
        if isPremium {
            return allSessions
        } else {
            return allSessions.filter { session in
                guard let endedAt = session.endedAt else { return false }
                return endedAt >= freeTierCutoffDate
            }
        }
    }

    // Count of gated sessions
    private var gatedSessionCount: Int {
        allSessions.count - visibleSessions.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if allSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Logbook")
        }
        .task {
            isPremium = await premiumService?.isPremium() ?? false
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Sessions Yet")
                .font(SCTypography.sectionHeader)

            Text("Complete your first climbing session to see it here")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: SCSpacing.md) {
                ForEach(visibleSessions) { session in
                    sessionRow(session)
                }

                // Show upgrade prompt if there are gated sessions
                if gatedSessionCount > 0 {
                    gatedSessionsPrompt
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: SCSession) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                if let endedAt = session.endedAt {
                    Text(endedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(SCTypography.body)
                }
                Spacer()
                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            HStack {
                Text("\(session.climbs.count) climbs")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)

                if let rpe = session.rpe {
                    Text("RPE: \(rpe)/10")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }

    @ViewBuilder
    private var gatedSessionsPrompt: some View {
        VStack(spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tint)
                Text("\(gatedSessionCount) older sessions")
                    .font(SCTypography.body.weight(.semibold))
            }

            Text("Upgrade to Premium to access your complete climbing history")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("View Upgrade Options") {
                showPaywall = true
            }
            .font(SCTypography.body.weight(.medium))
            .padding(.top, SCSpacing.xs)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(SCColors.surfaceSecondary.opacity(0.5))
        .cornerRadius(SCCornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: SCCornerRadius.card)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(SCColors.textSecondary.opacity(0.3))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
