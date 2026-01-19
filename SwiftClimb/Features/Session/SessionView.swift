import SwiftUI
import SwiftData

@MainActor
struct SessionView: View {
    // SwiftData query for active sessions
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt == nil && $0.deletedAt == nil },
        sort: \SCSession.startedAt,
        order: .reverse
    )
    private var activeSessions: [SCSession]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.currentUserId) private var currentUserId

    @State private var errorMessage: String?
    @State private var isStartingSession = false

    private var activeSession: SCSession? {
        activeSessions.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SCSpacing.lg) {
                if let session = activeSession {
                    activeSessionView(session)
                } else {
                    emptyStateView
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(SCTypography.secondary)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Session")
        }
    }

    @ViewBuilder
    private func activeSessionView(_ session: SCSession) -> some View {
        VStack(spacing: SCSpacing.md) {
            Text("Active Session")
                .font(SCTypography.screenHeader)

            Text("Started: \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            if let mentalReadiness = session.mentalReadiness {
                Text("Mental Readiness: \(mentalReadiness)/5")
                    .font(SCTypography.secondary)
            }

            if let physicalReadiness = session.physicalReadiness {
                Text("Physical Readiness: \(physicalReadiness)/5")
                    .font(SCTypography.secondary)
            }

            Text("\(session.climbs.count) climbs logged")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)

            Text("Session features coming soon")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .padding(.top, SCSpacing.md)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Active Session")
                .font(SCTypography.sectionHeader)

            Text("Start a session to begin logging climbs")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            SCPrimaryButton(
                title: isStartingSession ? "Starting..." : "Start Session",
                action: startSession,
                isFullWidth: true
            )
            .disabled(isStartingSession)
        }
    }

    private func startSession() {
        guard let startSessionUseCase = startSessionUseCase else {
            errorMessage = "Session service not available"
            return
        }

        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }

        isStartingSession = true
        errorMessage = nil

        Task {
            do {
                let newSession = try await startSessionUseCase.execute(
                    userId: userId,
                    mentalReadiness: nil,
                    physicalReadiness: nil
                )
                modelContext.insert(newSession)
                try modelContext.save()
            } catch {
                errorMessage = "Failed to start session: \(error.localizedDescription)"
            }
            isStartingSession = false
        }
    }
}

#Preview {
    SessionView()
}
