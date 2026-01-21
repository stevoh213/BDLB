import SwiftUI

/// Sheet for starting a new session with optional readiness capture
/// Uses detent-based expansion: pull up to expand and reveal readiness tracking
struct StartSessionSheet: View {
    let onStart: (Discipline, Int?, Int?) -> Void
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var discipline: Discipline = .bouldering
    @State private var mentalReadiness: Int?
    @State private var physicalReadiness: Int?
    @State private var selectedDetent: PresentationDetent = .medium

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SCSpacing.lg) {
                // Discipline picker (always visible)
                DisciplinePicker(selection: $discipline)

                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }

                Spacer()

                startButton
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Collapsed State (Quick Start)

    @ViewBuilder
    private var collapsedContent: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Quick Start")
                .font(SCTypography.body)

            Text("Skip readiness tracking and jump right in")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)

            // Pull-up hint
            VStack(spacing: SCSpacing.xs) {
                Image(systemName: "chevron.up")
                    .font(.caption)
                Text("Pull up to track readiness")
                    .font(SCTypography.metadata)
            }
            .foregroundStyle(SCColors.textTertiary)
            .padding(.top, SCSpacing.sm)
        }
        .padding(.vertical, SCSpacing.lg)
    }

    // MARK: - Expanded State (Readiness Tracking)

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: SCSpacing.lg) {
            Text("How are you feeling today?")
                .font(SCTypography.sectionHeader)

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

            // Pull-down hint
            VStack(spacing: SCSpacing.xs) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                Text("Pull down to skip")
                    .font(SCTypography.metadata)
            }
            .foregroundStyle(SCColors.textTertiary)
            .padding(.top, SCSpacing.sm)
        }
    }

    // MARK: - Start Button

    @ViewBuilder
    private var startButton: some View {
        SCPrimaryButton(
            title: isLoading ? "Starting..." : "Start \(discipline.displayName) Session",
            action: {
                onStart(discipline, mentalReadiness, physicalReadiness)
            },
            isLoading: isLoading,
            isFullWidth: true
        )
        .disabled(isLoading)
        .padding(.horizontal)
        .padding(.bottom, SCSpacing.md)
    }
}

/// Slider component for readiness input
struct ReadinessSlider: View {
    let title: String
    @Binding var value: Int?
    let icon: String

    private let labels = ["Low", "", "Medium", "", "High"]

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(SCTypography.body.weight(.medium))
                Spacer()
                if let value = value {
                    Text("\(value)/5")
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(value ?? 3) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 1...5,
                step: 1
            )

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                    if index < labels.count - 1 {
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }
}

#Preview("Collapsed") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            StartSessionSheet(
                onStart: { _, _, _ in },
                isLoading: false
            )
        }
}
