import SwiftUI
import SwiftData

@MainActor
struct SessionView: View {
    // MARK: - SwiftData Query
    @Query(
        filter: #Predicate<SCSession> { $0.endedAt == nil && $0.deletedAt == nil },
        sort: \SCSession.startedAt,
        order: .reverse
    )
    private var activeSessions: [SCSession]

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.startSessionUseCase) private var startSessionUseCase
    @Environment(\.endSessionUseCase) private var endSessionUseCase
    @Environment(\.currentUserId) private var currentUserId
    @Environment(\.syncActor) private var syncActor

    // MARK: - State
    @State private var showStartSheet = false
    @State private var showEndSheet = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSyncing = false

    private var activeSession: SCSession? {
        activeSessions.first
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = activeSession {
                    ActiveSessionContent(
                        session: session,
                        onEndSession: { showEndSheet = true }
                    )
                } else {
                    EmptySessionState(onStartSession: { showStartSheet = true })
                }
            }
            .refreshable {
                await performManualSync()
            }
            .navigationTitle("Session")
            .toolbar {
                if activeSession != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End") {
                            showEndSheet = true
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showStartSheet) {
            StartSessionSheet(
                onStart: startNewSession,
                isLoading: isLoading
            )
        }
        .sheet(isPresented: $showEndSheet) {
            if let session = activeSession {
                EndSessionSheet(
                    session: session,
                    onEnd: endCurrentSession,
                    isLoading: isLoading
                )
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func startNewSession(mentalReadiness: Int?, physicalReadiness: Int?) {
        guard let useCase = startSessionUseCase,
              let userId = currentUserId else {
            errorMessage = "Session service not available"
            return
        }

        isLoading = true

        Task {
            do {
                _ = try await useCase.execute(
                    userId: userId,
                    mentalReadiness: mentalReadiness,
                    physicalReadiness: physicalReadiness
                )
                showStartSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func endCurrentSession(rpe: Int?, pumpLevel: Int?, notes: String?) {
        guard let useCase = endSessionUseCase,
              let session = activeSession else {
            errorMessage = "Session service not available"
            return
        }

        isLoading = true

        Task {
            do {
                try await useCase.execute(
                    sessionId: session.id,
                    rpe: rpe,
                    pumpLevel: pumpLevel,
                    notes: notes
                )
                showEndSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Sync

    private func performManualSync() async {
        guard let syncActor = syncActor, let userId = currentUserId else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await syncActor.performSync(userId: userId)
        } catch {
            print("Manual sync failed: \(error)")
        }
    }
}

#Preview {
    SessionView()
}
