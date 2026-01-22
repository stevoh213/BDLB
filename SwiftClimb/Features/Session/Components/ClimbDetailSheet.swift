import SwiftUI

/// Full edit sheet for climb details and attempt history
struct ClimbDetailSheet: View {
    @Bindable var climb: SCClimb
    let session: SCSession
    let onUpdate: (ClimbUpdates) async throws -> Void
    let onDelete: () async throws -> Void
    let onLogAttempt: (AttemptOutcome, SendType?) async throws -> Void
    let onDeleteAttempt: (UUID) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var editedName: String = ""
    @State private var editedGrade: String = ""
    @State private var editedScale: GradeScale = .v
    @State private var editedNotes: String = ""
    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var sortedAttempts: [SCAttempt] {
        climb.attempts
            .filter { $0.deletedAt == nil }
            .sorted { $0.attemptNumber < $1.attemptNumber }
    }

    var body: some View {
        NavigationStack {
            List {
                // Climb Info Section
                Section("Climb Details") {
                    if isEditing {
                        editingContent
                    } else {
                        displayContent
                    }
                }

                // TODO: [Climb Characteristics] - Add characteristics display and editing section
                // - Display wall style tags with impact indicators (helped/hindered/neutral)
                // - Display technique tags with impact indicators
                // - Display skill tags with impact indicators
                // - In edit mode, allow adding/removing tags and changing impact ratings
                // - Use chip/badge UI pattern for compact tag display
                // - Consider grouping by category (e.g., "Wall Features", "Techniques", "Skills")

                // Attempts Section
                Section("Attempts (\(sortedAttempts.count))") {
                    if sortedAttempts.isEmpty {
                        Text("No attempts yet")
                            .foregroundStyle(SCColors.textSecondary)
                    } else {
                        ForEach(sortedAttempts) { attempt in
                            AttemptRow(attempt: attempt)
                        }
                        .onDelete(perform: deleteAttempts)
                    }

                    // Add attempt inline
                    AttemptLogButtons(
                        climb: climb,
                        onLogAttempt: onLogAttempt
                    )
                }

                // Delete Section
                Section {
                    Button("Delete Climb", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(climb.name ?? climb.gradeOriginal ?? "Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task { await saveChanges() }
                        } else {
                            startEditing()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Delete Climb?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteClimb() }
                }
            } message: {
                Text("This will delete the climb and all its attempts. This cannot be undone.")
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
    }

    // MARK: - Display Content

    @ViewBuilder
    private var displayContent: some View {
        LabeledContent("Grade", value: climb.gradeOriginal ?? "Unknown")

        if let name = climb.name, !name.isEmpty {
            LabeledContent("Name", value: name)
        }

        LabeledContent("Discipline", value: climb.discipline.displayName)

        if climb.hasSend {
            LabeledContent("Status") {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }

        if let notes = climb.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: SCSpacing.xs) {
                Text("Notes")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
                Text(notes)
            }
        }
    }

    // MARK: - Editing Content

    @ViewBuilder
    private var editingContent: some View {
        TextField("Name", text: $editedName)

        GradePicker(
            discipline: session.discipline,
            selectedGrade: $editedGrade,
            selectedScale: $editedScale
        )

        TextField("Notes", text: $editedNotes, axis: .vertical)
            .lineLimit(3...6)
    }

    // MARK: - Helper Methods

    private func startEditing() {
        editedName = climb.name ?? ""
        editedGrade = climb.gradeOriginal ?? ""
        editedScale = climb.gradeScale ?? session.discipline.defaultGradeScale
        editedNotes = climb.notes ?? ""
        isEditing = true
    }

    private func saveChanges() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let updates = ClimbUpdates(
                name: editedName.isEmpty ? nil : editedName,
                grade: Grade.parse(editedGrade),
                notes: editedNotes.isEmpty ? nil : editedNotes
            )
            try await onUpdate(updates)
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteClimb() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAttempts(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let attempt = sortedAttempts[index]
                try? await onDeleteAttempt(attempt.id)
            }
        }
    }
}

/// Row displaying attempt details
struct AttemptRow: View {
    let attempt: SCAttempt

    var body: some View {
        HStack {
            Text("#\(attempt.attemptNumber)")
                .font(SCTypography.body.monospacedDigit())
                .foregroundStyle(SCColors.textSecondary)

            Image(systemName: attempt.outcome.systemImage)
                .foregroundStyle(attempt.isSend ? .green : .red)

            Text(attempt.outcome.displayName)
                .font(SCTypography.body)

            if let sendType = attempt.sendType {
                Text("(\(sendType.displayName))")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }

            Spacer()

            if let time = attempt.occurredAt {
                Text(time, style: .time)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
    }
}

#Preview {
    let session = SCSession(userId: UUID(), discipline: .bouldering)
    let climb = SCClimb(
        userId: UUID(),
        sessionId: session.id,
        discipline: .bouldering,
        isOutdoor: false,
        name: "Test Climb",
        gradeOriginal: "V5"
    )

    ClimbDetailSheet(
        climb: climb,
        session: session,
        onUpdate: { _ in },
        onDelete: { },
        onLogAttempt: { _, _ in },
        onDeleteAttempt: { _ in }
    )
}
