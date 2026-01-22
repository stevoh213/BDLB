import SwiftUI
import SwiftData

/// Main view for an active session showing stats and climbs
@MainActor
struct ActiveSessionContent: View {
    @Bindable var session: SCSession
    let onEndSession: () -> Void

    // MARK: - Environment Use Cases
    @Environment(\.addClimbUseCase) private var addClimbUseCase
    @Environment(\.logAttemptUseCase) private var logAttemptUseCase
    @Environment(\.updateClimbUseCase) private var updateClimbUseCase
    @Environment(\.deleteClimbUseCase) private var deleteClimbUseCase
    @Environment(\.deleteAttemptUseCase) private var deleteAttemptUseCase
    @Environment(\.currentUserId) private var currentUserId
    @Environment(\.pendingDeepLink) private var pendingDeepLink

    // MARK: - State
    @State private var showAddClimb = false
    @State private var selectedClimb: SCClimb?
    @State private var errorMessage: String?

    private var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.md) {
                // Session Details (date, location, type)
                sessionDetails

                // Session Header
                sessionHeader

                // Quick Stats
                quickStats

                // Climbs List
                if session.climbs.isEmpty {
                    emptyClimbsState
                } else {
                    climbsList
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            addClimbButton
        }
        .sheet(isPresented: $showAddClimb) {
            AddClimbSheet(session: session, onAdd: handleAddClimb)
        }
        .sheet(item: $selectedClimb) { climb in
            ClimbDetailSheet(
                climb: climb,
                session: session,
                onUpdate: { data in try await handleUpdateClimb(climb.id, data) },
                onDelete: { try await handleDeleteClimb(climb.id) },
                onLogAttempt: { outcome, sendType in
                    try await handleLogAttempt(climb.id, outcome, sendType)
                },
                onDeleteAttempt: handleDeleteAttempt
            )
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: pendingDeepLink?.wrappedValue) { _, deepLink in
            // Handle deep link to show Add Climb sheet
            if case .addClimb(let sessionId) = deepLink,
               sessionId == session.id {
                showAddClimb = true
                // Clear the deep link after handling
                pendingDeepLink?.wrappedValue = nil
            }
        }
    }

    // MARK: - Session Details

    @ViewBuilder
    private var sessionDetails: some View {
        HStack(spacing: SCSpacing.lg) {
            // Date
            Label {
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(SCTypography.secondary)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            }

            // Discipline/Session Type
            Label {
                Text(session.discipline.displayName)
                    .font(SCTypography.secondary)
            } icon: {
                Image(systemName: "figure.climbing")
                    .foregroundStyle(.tint)
            }

            Spacer()
        }
        .foregroundStyle(SCColors.textSecondary)
    }

    @ViewBuilder
    private var sessionHeader: some View {
        SCGlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Session")
                        .font(SCTypography.cardTitle)
                    Text("Started \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(elapsedTime)
                        .font(SCTypography.sectionHeader)
                        .monospacedDigit()
                    Text("elapsed")
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var quickStats: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SCSpacing.md) {
                if let mental = session.mentalReadiness {
                    MetricStatPill(
                        icon: "brain.head.profile",
                        value: "\(mental)/5",
                        label: "Mental"
                    )
                }

                if let physical = session.physicalReadiness {
                    MetricStatPill(
                        icon: "figure.stand",
                        value: "\(physical)/5",
                        label: "Physical"
                    )
                }

                MetricStatPill(
                    icon: "number",
                    value: "\(session.climbs.count)",
                    label: "Climbs"
                )

                MetricStatPill(
                    icon: "arrow.counterclockwise",
                    value: "\(session.attemptCount)",
                    label: "Attempts"
                )
            }
        }
    }

    @ViewBuilder
    private var emptyClimbsState: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 50))
                .foregroundStyle(SCColors.textSecondary)

            Text("No climbs yet")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Tap below to add your first climb")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SCSpacing.xl)
    }

    @ViewBuilder
    private var climbsList: some View {
        LazyVStack(spacing: SCSpacing.sm) {
            ForEach(session.climbs.filter { $0.deletedAt == nil }) { climb in
                ClimbRow(climb: climb) {
                    selectedClimb = climb
                }
            }
        }
    }

    @ViewBuilder
    private var addClimbButton: some View {
        SCPrimaryButton(
            title: "Add Climb",
            action: { showAddClimb = true },
            isFullWidth: true
        )
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Handler Functions

    private func handleAddClimb(_ data: AddClimbData) async throws {
        guard let useCase = addClimbUseCase,
              let userId = currentUserId else {
            throw NSError(domain: "ActiveSessionContent", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Add climb service not available"
            ])
        }

        _ = try await useCase.execute(
            userId: userId,
            sessionId: session.id,
            discipline: session.discipline,
            data: data,
            isOutdoor: false,
            openBetaClimbId: nil,
            openBetaAreaId: nil,
            locationDisplay: nil
        )
    }

    private func handleUpdateClimb(_ climbId: UUID, _ data: ClimbEditData) async throws {
        guard let useCase = updateClimbUseCase,
              let userId = currentUserId else {
            throw NSError(domain: "ActiveSessionContent", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Update climb service not available"
            ])
        }

        try await useCase.execute(
            userId: userId,
            climbId: climbId,
            data: data
        )
    }

    private func handleDeleteClimb(_ climbId: UUID) async throws {
        guard let useCase = deleteClimbUseCase else {
            throw NSError(domain: "ActiveSessionContent", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Delete climb service not available"
            ])
        }

        try await useCase.execute(climbId: climbId, sessionId: session.id)
    }

    private func handleLogAttempt(
        _ climbId: UUID,
        _ outcome: AttemptOutcome,
        _ sendType: SendType?
    ) async throws {
        guard let useCase = logAttemptUseCase,
              let userId = currentUserId else {
            throw NSError(domain: "ActiveSessionContent", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Log attempt service not available"
            ])
        }

        _ = try await useCase.execute(
            userId: userId,
            sessionId: session.id,
            climbId: climbId,
            outcome: outcome,
            discipline: session.discipline,
            sendTypeOverride: sendType
        )
    }

    private func handleDeleteAttempt(_ attemptId: UUID) async throws {
        guard let useCase = deleteAttemptUseCase else {
            throw NSError(domain: "ActiveSessionContent", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Delete attempt service not available"
            ])
        }

        try await useCase.execute(attemptId: attemptId, sessionId: session.id)
    }
}

/// Simple metric pill for stats display
private struct MetricStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: SCSpacing.xs) {
            Image(systemName: icon)
                .font(SCTypography.secondary)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(SCTypography.body.weight(.semibold))
                Text(label)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
        .padding(.horizontal, SCSpacing.sm)
        .padding(.vertical, SCSpacing.xs)
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.chip)
    }
}

/// Row displaying a climb with attempts - tappable for editing
struct ClimbRow: View {
    let climb: SCClimb
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SCGlassCard {
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(climb.name ?? climb.discipline.displayName)
                                .font(SCTypography.body.weight(.medium))

                            if let grade = climb.gradeOriginal {
                                Text(grade)
                                    .font(SCTypography.secondary)
                                    .foregroundStyle(SCColors.textSecondary)
                            }
                        }

                        Spacer()

                        if climb.hasSend {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(SCColors.textTertiary)
                    }

                    // Attempt pills
                    if !climb.attempts.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(climb.attempts
                                .filter { $0.deletedAt == nil }
                                .sorted(by: { $0.attemptNumber < $1.attemptNumber })
                            ) { attempt in
                                AttemptPill(attempt: attempt)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Visual indicator for an attempt
struct AttemptPill: View {
    let attempt: SCAttempt

    var body: some View {
        Image(systemName: attempt.isSend ? "checkmark.circle.fill" : "xmark.circle")
            .font(.caption)
            .foregroundStyle(attempt.isSend ? .green : .red)
            .padding(4)
            .background(
                (attempt.isSend ? Color.green : Color.red).opacity(0.1)
            )
            .cornerRadius(4)
    }
}

#Preview {
    ActiveSessionContent(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onEndSession: {}
    )
}
