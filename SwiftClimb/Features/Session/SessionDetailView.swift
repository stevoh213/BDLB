import SwiftUI

/// Detail view for completed sessions (used in Logbook)
@MainActor
struct SessionDetailView: View {
    let session: SCSession

    @Environment(\.deleteSessionUseCase) private var deleteSessionUseCase
    @Environment(\.updateSessionUseCase) private var updateSessionUseCase
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var isDeleting = false

    private var formattedDuration: String {
        guard let duration = session.duration else { return "N/A" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SCSpacing.lg) {
                // Header Card
                headerCard

                // Metrics
                metricsSection

                // Climbs
                climbsSection

                // Notes
                if let notes = session.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Session", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSessionSheet(session: session) { editData in
                try await updateSession(with: editData)
            }
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("This will delete the session and all its climbs. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        SCGlassCard {
            VStack(spacing: SCSpacing.sm) {
                if let endedAt = session.endedAt {
                    Text(endedAt.formatted(date: .long, time: .shortened))
                        .font(SCTypography.sectionHeader)
                }

                HStack(spacing: SCSpacing.lg) {
                    StatBlock(value: formattedDuration, label: "Duration")
                    StatBlock(value: "\(session.climbs.count)", label: "Climbs")
                    StatBlock(value: "\(session.attemptCount)", label: "Attempts")
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Metrics")
                .font(SCTypography.cardTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SCSpacing.sm) {
                if let mental = session.mentalReadiness {
                    MetricCard(
                        icon: "brain.head.profile",
                        title: "Mental Readiness",
                        value: "\(mental)/5"
                    )
                }

                if let physical = session.physicalReadiness {
                    MetricCard(
                        icon: "figure.stand",
                        title: "Physical Readiness",
                        value: "\(physical)/5"
                    )
                }

                if let rpe = session.rpe {
                    MetricCard(
                        icon: "heart.fill",
                        title: "RPE",
                        value: "\(rpe)/10"
                    )
                }

                if let pump = session.pumpLevel {
                    MetricCard(
                        icon: "flame.fill",
                        title: "Pump Level",
                        value: "\(pump)/5"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var climbsSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Climbs")
                .font(SCTypography.cardTitle)

            if session.climbs.isEmpty {
                Text("No climbs logged")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(session.climbs.filter { $0.deletedAt == nil }) { climb in
                    ClimbRow(climb: climb) {
                        // No-op for past session detail view (read-only)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Notes")
                .font(SCTypography.cardTitle)

            Text(notes)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(SCColors.surfaceSecondary)
                .cornerRadius(SCCornerRadius.card)
        }
    }

    private func deleteSession() {
        guard let useCase = deleteSessionUseCase else { return }

        isDeleting = true

        Task {
            do {
                try await useCase.execute(sessionId: session.id)
                dismiss()
            } catch {
                // Handle error - session might already be deleted
            }
            isDeleting = false
        }
    }

    private func updateSession(with editData: SessionEditData) async throws {
        guard let useCase = updateSessionUseCase else { return }

        try await useCase.execute(
            sessionId: session.id,
            startedAt: editData.startedAt,
            endedAt: editData.endedAt,
            discipline: editData.discipline,
            mentalReadiness: editData.mentalReadiness,
            physicalReadiness: editData.physicalReadiness,
            rpe: editData.rpe,
            pumpLevel: editData.pumpLevel,
            notes: editData.notes
        )
    }
}

private struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SCTypography.sectionHeader)
            Text(label)
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textSecondary)
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: SCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
                Text(value)
                    .font(SCTypography.body.weight(.semibold))
            }

            Spacer()
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: SCSession(userId: UUID(), discipline: .bouldering))
    }
}
