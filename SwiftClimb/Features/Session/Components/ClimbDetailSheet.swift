import SwiftUI

/// Full edit sheet for climb details - matches AddClimbSheet UI/UX for consistency.
///
/// This view provides the same form structure as AddClimbSheet to ensure users
/// have a consistent experience when adding vs editing climbs. Additional sections
/// for attempt history and delete are added since they're specific to editing.
struct ClimbDetailSheet: View {
    @Bindable var climb: SCClimb
    let session: SCSession
    let onUpdate: (ClimbEditData) async throws -> Void
    let onDelete: () async throws -> Void
    let onLogAttempt: (AttemptOutcome, SendType?) async throws -> Void
    let onDeleteAttempt: (UUID) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.tagService) private var tagService

    // MARK: - Basic Info State
    @State private var editedName: String = ""
    @State private var editedGrade: String = ""
    @State private var editedScale: GradeScale = .v

    // MARK: - Attempts & Outcome State
    @State private var outcome: ClimbOutcome = .project
    @State private var tickType: SendType = .flash
    @State private var showTickTypeOverride = false

    // MARK: - Tag State
    @State private var holdTypeSelections: [TagSelection] = []
    @State private var skillSelections: [TagSelection] = []
    @State private var isLoadingTags = true

    // MARK: - Notes State
    @State private var editedNotes: String = ""

    // MARK: - UI State
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var sortedAttempts: [SCAttempt] {
        climb.attempts
            .filter { $0.deletedAt == nil }
            .sorted { $0.attemptNumber < $1.attemptNumber }
    }

    /// Auto-inferred tick type based on discipline and attempt count.
    private var inferredTickType: SendType {
        SendType.inferred(for: session.discipline, attemptCount: sortedAttempts.count)
    }

    /// Available tick types for the current discipline.
    private var availableTickTypes: [SendType] {
        SendType.availableTypes(for: session.discipline)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                attemptsOutcomeSection
                tagsSection
                notesSection
                attemptHistorySection
                deleteSection
            }
            .navigationTitle(climb.name ?? climb.gradeOriginal ?? "Edit Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .fontWeight(.semibold)
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
            .confirmationDialog(
                "Tick Type",
                isPresented: $showTickTypeOverride,
                titleVisibility: .visible
            ) {
                tickTypeOverrideOptions
            } message: {
                Text("Auto-detected as \(inferredTickType.displayName). Change?")
            }
        }
        .task {
            await loadTags()
        }
        .onAppear {
            setupInitialValues()
        }
    }

    // MARK: - Basic Info Section

    @ViewBuilder
    private var basicInfoSection: some View {
        Section {
            TextField("Route Name", text: $editedName)

            GradePicker(
                discipline: session.discipline,
                selectedGrade: $editedGrade,
                selectedScale: $editedScale
            )
        } header: {
            Text("Basic Info")
        }
    }

    // MARK: - Attempts & Outcome Section

    @ViewBuilder
    private var attemptsOutcomeSection: some View {
        Section {
            // Attempt count (read-only - managed via attempt history)
            HStack {
                Text("Attempts")
                Spacer()
                Text("\(sortedAttempts.count)")
                    .foregroundStyle(SCColors.textSecondary)
                    .monospacedDigit()
            }

            // Outcome picker
            Picker("Outcome", selection: $outcome) {
                ForEach(ClimbOutcome.allCases, id: \.self) { outcome in
                    Label(outcome.displayName, systemImage: outcome.systemImage)
                        .tag(outcome)
                }
            }

            // Tick type (only shown for sends)
            if outcome == .send {
                HStack {
                    Text("Tick Type")
                    Spacer()
                    Button {
                        showTickTypeOverride = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(tickType.displayName)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tint)
                    }
                }
            }
        } header: {
            Text("Attempts & Outcome")
        } footer: {
            if outcome == .send {
                Text("Tick type auto-detected: \(inferredTickType.displayName) (\(inferredTickType.description))")
            } else {
                Text("Mark as Project if you're still working on this climb")
            }
        }
    }

    // MARK: - Tags Section

    @ViewBuilder
    private var tagsSection: some View {
        Section {
            if isLoadingTags {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: SCSpacing.lg) {
                    TagSelectionGrid(
                        title: "Hold Types",
                        selections: $holdTypeSelections
                    )

                    TagSelectionGrid(
                        title: "Skills",
                        selections: $skillSelections
                    )
                }
            }
        } header: {
            Text("Tags")
        } footer: {
            Text("Tap to mark as helped (green) or hindered (red). Tap again to deselect.")
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        Section {
            TextField("Add notes about this climb...", text: $editedNotes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Attempt History Section

    @ViewBuilder
    private var attemptHistorySection: some View {
        Section {
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
        } header: {
            Text("Attempt History (\(sortedAttempts.count))")
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button("Delete Climb", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Tick Type Override Options

    @ViewBuilder
    private var tickTypeOverrideOptions: some View {
        Button("Keep as \(inferredTickType.displayName)") {
            tickType = inferredTickType
        }

        ForEach(availableTickTypes.filter { $0 != inferredTickType }, id: \.self) { type in
            Button("Change to \(type.displayName)") {
                tickType = type
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Helper Methods

    private func setupInitialValues() {
        editedName = climb.name ?? ""
        editedGrade = climb.gradeOriginal ?? ""
        editedScale = climb.gradeScale ?? session.discipline.defaultGradeScale
        editedNotes = climb.notes ?? ""

        // Determine outcome from attempts
        outcome = climb.hasSend ? .send : .project

        // Get tick type from send attempt if exists
        if let sendAttempt = sortedAttempts.first(where: { $0.isSend }),
           let sendType = sendAttempt.sendType {
            tickType = sendType
        } else {
            tickType = inferredTickType
        }
    }

    private func loadTags() async {
        guard let tagService = tagService else {
            await MainActor.run {
                isLoadingTags = false
            }
            return
        }

        let holdTypes = await tagService.getHoldTypeTags()
        let skills = await tagService.getSkillTags()

        // Get existing impacts from climb
        let existingHoldImpacts = climb.techniqueImpacts.filter { $0.deletedAt == nil }
        let existingSkillImpacts = climb.skillImpacts.filter { $0.deletedAt == nil }

        await MainActor.run {
            // Map tags with existing impacts pre-selected
            holdTypeSelections = holdTypes.map { tag in
                let existingImpact = existingHoldImpacts.first { $0.tagId == tag.id }
                return TagSelection(
                    tagId: tag.id,
                    tagName: tag.name,
                    impact: existingImpact?.impact
                )
            }

            skillSelections = skills.map { tag in
                let existingImpact = existingSkillImpacts.first { $0.tagId == tag.id }
                return TagSelection(
                    tagId: tag.id,
                    tagName: tag.name,
                    impact: existingImpact?.impact
                )
            }

            isLoadingTags = false
        }
    }

    private func saveChanges() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Convert selections to impacts (only include selected tags)
            let holdImpacts = holdTypeSelections
                .filter { $0.impact != nil }
                .map { TagImpactInput(tagId: $0.tagId, impact: $0.impact!) }

            let skillImpacts = skillSelections
                .filter { $0.impact != nil }
                .map { TagImpactInput(tagId: $0.tagId, impact: $0.impact!) }

            let data = ClimbEditData(
                name: editedName.isEmpty ? nil : editedName,
                gradeString: editedGrade,
                gradeScale: editedScale,
                notes: editedNotes.isEmpty ? nil : editedNotes,
                holdTypeImpacts: holdImpacts,
                skillImpacts: skillImpacts
            )
            try await onUpdate(data)
            dismiss()
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

/// Data transfer object for editing a climb.
///
/// Similar to AddClimbData but excludes fields that can't be changed after creation
/// (like attempt count, which is managed via the attempt history).
struct ClimbEditData: Sendable {
    let name: String?
    let gradeString: String
    let gradeScale: GradeScale
    let notes: String?
    let holdTypeImpacts: [TagImpactInput]
    let skillImpacts: [TagImpactInput]
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
