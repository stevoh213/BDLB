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

    // MARK: - Performance State
    @State private var mentalRating: PerformanceRating? = nil
    @State private var pacingRating: PerformanceRating? = nil
    @State private var precisionRating: PerformanceRating? = nil
    @State private var noCutLooseRating: PerformanceRating? = nil

    // MARK: - Notes State
    @State private var notes: String = ""

    // MARK: - UI State
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                performanceSection
                characteristicsSection
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

    // MARK: - Performance Section

    @ViewBuilder
    private var performanceSection: some View {
        Section {
            ThumbsToggle(label: "Mental", value: $mentalRating)
            ThumbsToggle(label: "Pacing", value: $pacingRating)
            ThumbsToggle(label: "Precision", value: $precisionRating)

            if session.discipline == .bouldering {
                ThumbsToggle(label: "No Cut Loose", value: $noCutLooseRating)
            }
        } header: {
            Text("Performance")
        } footer: {
            Text("How did specific aspects feel? Leave unselected if neutral.")
        }
    }

    // MARK: - Characteristics Section (Stub)

    // TODO: [Climb Characteristics] - Implement characteristics tagging system
    // - Add state properties for tag selections (wallStyleTags, techniqueTags, skillTags)
    // - Create tag selection views using SCWallStyleTag, SCTechniqueTag, SCSkillTag models
    // - Add impact rating picker (helped/hindered/neutral) for each selected tag
    // - Include tag selections in AddClimbData for persistence via AddClimbUseCase
    // - Consider multi-select UI pattern (chips, checkboxes, or sheet-based picker)
    // - Integrate with existing tag impact relationships on SCClimb model
    @ViewBuilder
    private var characteristicsSection: some View {
        Section {
            comingSoonRow(label: "Wall Features", icon: "square.grid.3x3")
            comingSoonRow(label: "Holds & Moves", icon: "hand.raised")
            comingSoonRow(label: "Skills Used", icon: "star")
        } header: {
            HStack {
                Text("Characteristics")
                Spacer()
                Text("Coming Soon")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func comingSoonRow(label: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(SCColors.textTertiary)
        }
        .foregroundStyle(SCColors.textTertiary)
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

    private func saveClimb() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = AddClimbData(
                name: climbName.isEmpty ? nil : climbName,
                gradeString: selectedGrade,
                gradeScale: selectedScale,
                attemptCount: attemptCount,
                outcome: outcome,
                tickType: outcome == .send ? tickType : nil,
                notes: notes.isEmpty ? nil : notes,
                mentalRating: mentalRating,
                pacingRating: pacingRating,
                precisionRating: precisionRating,
                noCutLooseRating: noCutLooseRating
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
/// - Performance ratings - All optional (nil = neutral)
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
///     mentalRating: .positive,
///     pacingRating: nil,
///     precisionRating: .negative,
///     noCutLooseRating: .positive
/// )
/// ```
// TODO: [Climb Characteristics] - Add tag impact fields when characteristics UI is implemented
// - wallStyleImpacts: [(tagId: UUID, impact: TagImpact)]?
// - techniqueImpacts: [(tagId: UUID, impact: TagImpact)]?
// - skillImpacts: [(tagId: UUID, impact: TagImpact)]?
struct AddClimbData {
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

    /// Mental performance rating (nil = neutral).
    let mentalRating: PerformanceRating?

    /// Pacing performance rating (nil = neutral).
    let pacingRating: PerformanceRating?

    /// Precision performance rating (nil = neutral).
    let precisionRating: PerformanceRating?

    /// No cut loose performance rating (nil = neutral).
    ///
    /// Only applicable for bouldering discipline.
    let noCutLooseRating: PerformanceRating?
}

#Preview {
    AddClimbSheet(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onAdd: { _ in }
    )
}
