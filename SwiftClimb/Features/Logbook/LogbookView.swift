import SwiftUI
import SwiftData

@MainActor
struct LogbookView: View {
    // SwiftData query for completed sessions, sorted by most recent
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt != nil && $0.deletedAt == nil },
        sort: \SCSession.endedAt,
        order: .reverse
    )
    private var sessions: [SCSession]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .padding()
            .navigationTitle("Logbook")
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
    }

    @ViewBuilder
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: SCSpacing.md) {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
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
        .cornerRadius(12)
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

#Preview {
    LogbookView()
}
