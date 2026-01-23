import SwiftUI

/// Data structure for session edit form values
struct SessionEditData {
    var startedAt: Date
    var endedAt: Date
    var discipline: Discipline
    var mentalReadiness: Int?
    var physicalReadiness: Int?
    var rpe: Int?
    var pumpLevel: Int?
    var notes: String?
}

/// Sheet for editing a completed session's details
struct EditSessionSheet: View {
    let session: SCSession
    let onSave: (SessionEditData) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state initialized from session
    @State private var sessionDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var discipline: Discipline
    @State private var mentalReadiness: Int?
    @State private var physicalReadiness: Int?
    @State private var rpe: Int
    @State private var pumpLevel: Int
    @State private var notes: String

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isReadinessExpanded = false
    @State private var isExertionExpanded = false

    init(session: SCSession, onSave: @escaping (SessionEditData) async throws -> Void) {
        self.session = session
        self.onSave = onSave

        // Initialize state from session values
        _sessionDate = State(initialValue: session.startedAt)
        _startTime = State(initialValue: session.startedAt)
        _endTime = State(initialValue: session.endedAt ?? Date())
        _discipline = State(initialValue: session.discipline)
        _mentalReadiness = State(initialValue: session.mentalReadiness)
        _physicalReadiness = State(initialValue: session.physicalReadiness)
        _rpe = State(initialValue: session.rpe ?? 5)
        _pumpLevel = State(initialValue: session.pumpLevel ?? 3)
        _notes = State(initialValue: session.notes ?? "")
    }

    /// Combines date from sessionDate with time from the given time Date
    private func combinedDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }

    /// Validates that end time is after start time
    private var isTimeValid: Bool {
        let start = combinedDateTime(date: sessionDate, time: startTime)
        let end = combinedDateTime(date: sessionDate, time: endTime)
        return end > start
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    // Date & Time Section
                    dateTimeSection

                    // Discipline Section
                    DisciplinePicker(selection: $discipline)

                    // Notes Section
                    notesSection

                    // Collapsible Readiness Section
                    readinessDisclosure

                    // Collapsible Exertion Section
                    exertionDisclosure

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(SCTypography.secondary)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || !isTimeValid)
                }
            }
        }
    }

    // MARK: - Date & Time Section

    @ViewBuilder
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Date & Time")
                .font(SCTypography.body.weight(.medium))

            VStack(spacing: SCSpacing.sm) {
                // Session Date
                DatePicker(
                    "Date",
                    selection: $sessionDate,
                    displayedComponents: .date
                )

                // Start Time
                DatePicker(
                    "Start Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )

                // End Time
                DatePicker(
                    "End Time",
                    selection: $endTime,
                    displayedComponents: .hourAndMinute
                )

                // Validation warning
                if !isTimeValid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("End time must be after start time")
                            .font(SCTypography.secondary)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .background(SCColors.surfaceSecondary)
            .cornerRadius(SCCornerRadius.card)
        }
    }

    // MARK: - Readiness Disclosure

    @ViewBuilder
    private var readinessDisclosure: some View {
        DisclosureGroup(isExpanded: $isReadinessExpanded) {
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                ReadinessSlider(
                    title: "Mental Readiness",
                    value: $mentalReadiness,
                    icon: "brain.head.profile"
                )

                ReadinessSlider(
                    title: "Physical Readiness",
                    value: $physicalReadiness,
                    icon: "figure.stand"
                )
            }
            .padding(.top, SCSpacing.sm)
        } label: {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.tint)
                Text("Pre-Session Readiness")
                    .font(SCTypography.body.weight(.medium))
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }

    // MARK: - Exertion Disclosure

    @ViewBuilder
    private var exertionDisclosure: some View {
        DisclosureGroup(isExpanded: $isExertionExpanded) {
            VStack(alignment: .leading, spacing: SCSpacing.md) {
                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    Text("Rate of Perceived Exertion")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)

                    RPEPicker(value: $rpe)
                }

                VStack(alignment: .leading, spacing: SCSpacing.sm) {
                    Text("Pump Level")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)

                    PumpLevelPicker(value: $pumpLevel)
                }
            }
            .padding(.top, SCSpacing.sm)
        } label: {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.tint)
                Text("Post-Session Exertion")
                    .font(SCTypography.body.weight(.medium))
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Session Notes")
                .font(SCTypography.body.weight(.medium))

            TextField("How did it go?", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Actions

    private func saveSession() {
        guard isTimeValid else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let startedAt = combinedDateTime(date: sessionDate, time: startTime)
                let endedAt = combinedDateTime(date: sessionDate, time: endTime)

                let editData = SessionEditData(
                    startedAt: startedAt,
                    endedAt: endedAt,
                    discipline: discipline,
                    mentalReadiness: mentalReadiness,
                    physicalReadiness: physicalReadiness,
                    rpe: rpe,
                    pumpLevel: pumpLevel,
                    notes: notes.isEmpty ? nil : notes
                )

                try await onSave(editData)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    EditSessionSheet(
        session: {
            let session = SCSession(userId: UUID(), discipline: .bouldering)
            session.endedAt = Date()
            session.mentalReadiness = 4
            session.physicalReadiness = 3
            session.rpe = 7
            session.pumpLevel = 3
            session.notes = "Great session!"
            return session
        }(),
        onSave: { _ in }
    )
}
