import SwiftUI

/// Two-tap attempt logging flow: Add Attempt -> Fall/Send
struct AttemptLogButtons: View {
    let climb: SCClimb
    let onLogAttempt: (AttemptOutcome, SendType?) async throws -> Void

    @State private var showOutcomeChoice = false
    @State private var showSendTypeOverride = false
    @State private var inferredSendType: SendType = .flash
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: SCSpacing.sm) {
            if showOutcomeChoice {
                outcomeButtons
            } else {
                addAttemptButton
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
            "Send Type",
            isPresented: $showSendTypeOverride,
            titleVisibility: .visible
        ) {
            sendTypeOptions
        } message: {
            Text("This will be logged as a \(inferredSendType.displayName). Change?")
        }
    }

    // MARK: - Add Attempt Button

    @ViewBuilder
    private var addAttemptButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                inferSendType()
                showOutcomeChoice = true
            }
        } label: {
            Label("Add Attempt", systemImage: "plus.circle")
                .font(SCTypography.body.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }

    // MARK: - Outcome Buttons (Fall/Send)

    @ViewBuilder
    private var outcomeButtons: some View {
        HStack(spacing: SCSpacing.md) {
            // Fall button
            Button {
                Task { await logAttempt(.try, sendType: nil) }
            } label: {
                Label("Fall", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isLoading)

            // Send button
            Button {
                // Show send type confirmation
                showSendTypeOverride = true
            } label: {
                Label("Send", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isLoading)

            // Cancel button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOutcomeChoice = false
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Send Type Options

    @ViewBuilder
    private var sendTypeOptions: some View {
        Button("Log as \(inferredSendType.displayName)") {
            Task { await logAttempt(.send, sendType: inferredSendType) }
        }

        ForEach(SendType.allCases.filter { $0 != inferredSendType }, id: \.self) { type in
            Button("Change to \(type.displayName)") {
                Task { await logAttempt(.send, sendType: type) }
            }
        }

        Button("Cancel", role: .cancel) {
            showOutcomeChoice = false
        }
    }

    // MARK: - Helper Methods

    private func inferSendType() {
        let attemptCount = climb.attempts.filter { $0.deletedAt == nil }.count
        inferredSendType = attemptCount == 0 ? .flash : .redpoint
    }

    private func logAttempt(_ outcome: AttemptOutcome, sendType: SendType?) async {
        isLoading = true
        defer {
            isLoading = false
            showOutcomeChoice = false
        }

        do {
            try await onLogAttempt(outcome, sendType)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AttemptLogButtons(
        climb: SCClimb(
            userId: UUID(),
            sessionId: UUID(),
            discipline: .bouldering,
            isOutdoor: false
        ),
        onLogAttempt: { _, _ in }
    )
    .padding()
}
