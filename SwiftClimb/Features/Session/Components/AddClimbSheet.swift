import SwiftUI

/// Comprehensive sheet for adding a new climb with all details.
///
/// This view provides a single-interaction data capture experience for logging climbs,
/// eliminating the need for separate "quick add" and "detailed edit" workflows. The form
/// is organized into five logical sections:
///
/// 1. **Basic Info** - Route name and grade picker
/// 2. **Attempts & Outcome** - Attempt count, outcome (send/project), and tick type
/// 3. **Performance** - Thumbs up/down ratings for mental, pacing, precision, technique
/// 4. **Characteristics** - Wall features, holds, moves, skills (coming soon)
/// 5. **Notes** - Free-form text for observations
///
/// ## Auto-Inference
///
/// The form automatically infers tick type based on attempt count:
/// - 1 attempt → Flash
/// - 2+ attempts → Redpoint
///
/// Users can override the inferred tick type via a confirmation dialog.
///
/// ## Attempt Creation
///
/// When the form is saved, ``AddClimbUseCase`` creates attempts based on outcome:
/// - **Send**: Last attempt is a send with tick type, previous are tries
/// - **Project**: All attempts are tries (no tick type)
///
/// ## Threading
///
/// This view runs on the main actor and manages its own state using `@State`.
/// The `onAdd` callback is async and may execute on a background actor.
///
/// ## Example
///
/// ```swift
/// .sheet(isPresented: $showAddClimb) {
///     AddClimbSheet(
///         session: session,
///         onAdd: { data in
///             try await addClimbUseCase.execute(
///                 userId: session.userId,
///                 sessionId: session.id,
///                 discipline: session.discipline,
///                 data: data,
///                 isOutdoor: false,
///                 openBetaClimbId: nil,
///                 openBetaAreaId: nil,
///                 locationDisplay: nil
///             )
///         }
///     )
/// }
/// ```
///
/// - SeeAlso: ``AddClimbData``
/// - SeeAlso: ``AddClimbUseCase``
/// - SeeAlso: ``ThumbsToggle``
struct AddClimbSheet: View {
    /// The active climbing session this climb belongs to.
    let session: SCSession

    /// Callback invoked when user saves the form.
    ///
    /// This callback receives ``AddClimbData`` and should coordinate with
    /// ``AddClimbUseCase`` to persist the climb and its attempts.
    let onAdd: (AddClimbData) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Basic Info State
    @State private var climbName: String = ""
    @State private var selectedGrade: String = "V5"
    @State private var selectedScale: GradeScale = .v

    // MARK: - Attempts & Outcome State
    @State private var attemptCount: Int = 1
    @State private var outcome: ClimbOutcome = .send
    @State private var tickType: SendType = .flash
    @State private var showTickTypeOverride = false

    // MARK: - Tag State
    @State private var holdTypeSelections: [TagSelection] = []
    @State private var skillSelections: [TagSelection] = []
    @State private var isLoadingTags = true

    // MARK: - Notes State
    @State private var notes: String = ""

    // MARK: - UI State
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Dependencies
    @Environment(\.tagService) private var tagService

    /// Auto-inferred tick type based on discipline and attempt count.
    ///
    /// Uses discipline-aware inference:
    /// - 1 attempt = Flash (first try with beta)
    /// - 2+ attempts on sport/trad = Redpoint (worked then sent)
    /// - 2+ attempts on boulder/top rope = Flash (redpoint doesn't apply)
    ///
    /// The inferred value is displayed in the footer and can be overridden
    /// by the user via a confirmation dialog.
    private var inferredTickType: SendType {
        SendType.inferred(for: session.discipline, attemptCount: attemptCount)
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
            }
            .navigationTitle("New Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveClimb() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
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
        .onChange(of: attemptCount) { _, newCount in
            // Update tick type when attempts change (discipline-aware)
            tickType = SendType.inferred(for: session.discipline, attemptCount: newCount)
        }
    }

    // MARK: - Basic Info Section

    @ViewBuilder
    private var basicInfoSection: some View {
        Section {
            TextField("Route Name", text: $climbName)

            GradePicker(
                discipline: session.discipline,
                selectedGrade: $selectedGrade,
                selectedScale: $selectedScale
            )
        } header: {
            Text("Basic Info")
        }
    }

    // MARK: - Attempts & Outcome Section

    @ViewBuilder
    private var attemptsOutcomeSection: some View {
        Section {
            // Attempt count stepper
            Stepper(value: $attemptCount, in: 1...99) {
                HStack {
                    Text("Attempts")
                    Spacer()
                    Text("\(attemptCount)")
                        .foregroundStyle(SCColors.textSecondary)
                        .monospacedDigit()
                }
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
            TextField("Add notes about this climb...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Tick Type Override Options

    @ViewBuilder
    private var tickTypeOverrideOptions: some View {
        Button("Keep as \(inferredTickType.displayName)") {
            tickType = inferredTickType
        }

        // Only show tick types valid for this discipline
        ForEach(availableTickTypes.filter { $0 != inferredTickType }, id: \.self) { type in
            Button("Change to \(type.displayName)") {
                tickType = type
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Helper Methods

    private func setupInitialValues() {
        let grades = Grade.grades(for: session.discipline.defaultGradeScale)
        selectedScale = session.discipline.defaultGradeScale
        selectedGrade = grades[grades.count / 2]
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

        await MainActor.run {
            holdTypeSelections = holdTypes.map { tag in
                TagSelection(tagId: tag.id, tagName: tag.name, impact: nil)
            }

            skillSelections = skills.map { tag in
                TagSelection(tagId: tag.id, tagName: tag.name, impact: nil)
            }

            isLoadingTags = false
        }
    }

    private func saveClimb() async {
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

            let data = AddClimbData(
                name: climbName.isEmpty ? nil : climbName,
                gradeString: selectedGrade,
                gradeScale: selectedScale,
                attemptCount: attemptCount,
                outcome: outcome,
                tickType: outcome == .send ? tickType : nil,
                notes: notes.isEmpty ? nil : notes,
                holdTypeImpacts: holdImpacts,
                skillImpacts: skillImpacts
            )
            try await onAdd(data)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Data transfer object for adding a new climb.
///
/// This struct packages all form data from ``AddClimbSheet`` for transfer to
/// ``AddClimbUseCase``. It provides a clear contract between the UI layer and
/// business logic layer.
///
/// ## Optional Fields
///
/// All fields except core climb data are optional, allowing for quick logging
/// with minimal input when desired:
///
/// - `name` - Route can be unnamed (common for gym problems)
/// - `tickType` - Only required for sends, nil for projects
/// - `notes` - Optional personal observations
/// - Tag impacts - Arrays of selected tags with their impact ratings
///
/// ## Example
///
/// ```swift
/// let data = AddClimbData(
///     name: "Red Corner",
///     gradeString: "V5",
///     gradeScale: .v,
///     attemptCount: 3,
///     outcome: .send,
///     tickType: .redpoint,
///     notes: "Tricky heel hook",
///     holdTypeImpacts: [
///         TagImpactInput(tagId: crimpId, impact: .helped)
///     ],
///     skillImpacts: [
///         TagImpactInput(tagId: mentalId, impact: .hindered)
///     ]
/// )
/// ```
struct AddClimbData: Sendable {
    /// Optional route or problem name.
    ///
    /// Nil indicates an unnamed climb (common for gym boulder problems).
    let name: String?

    /// Raw grade string as entered by user (e.g., "V5", "5.12a").
    let gradeString: String

    /// The grade scale used (V Scale, YDS, French, UIAA).
    let gradeScale: GradeScale

    /// Number of attempts made on this climb (1-99).
    let attemptCount: Int

    /// Whether the climb was sent or is still a project.
    let outcome: ClimbOutcome

    /// Type of send (flash, redpoint, etc.).
    ///
    /// Required if outcome is send, nil if outcome is project.
    let tickType: SendType?

    /// Optional personal notes about the climb.
    let notes: String?

    /// Hold type tag impacts (only selected tags with helped/hindered).
    let holdTypeImpacts: [TagImpactInput]

    /// Skill tag impacts (only selected tags with helped/hindered).
    let skillImpacts: [TagImpactInput]
}

#Preview {
    AddClimbSheet(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onAdd: { _ in }
    )
}
