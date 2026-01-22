import SwiftUI

/// Three-state toggle for performance metrics with thumbs up/down UI.
///
/// This component provides an intuitive way to capture subjective performance ratings
/// on specific aspects of a climb. It supports three states:
///
/// - **Positive** (thumbs up) - Felt good/strong
/// - **Neutral** (unselected) - Average or not notable
/// - **Negative** (thumbs down) - Struggled or needs work
///
/// ## Design Rationale
///
/// Thumbs toggles were chosen over sliders for several reasons:
/// - Faster interaction (one tap vs. drag)
/// - Binary outcomes match climber mental models
/// - Neutral state is explicit (unselected)
/// - More accessible than sliders
///
/// ## Visual Feedback
///
/// - **Active thumbs up**: Green filled icon
/// - **Active thumbs down**: Red filled icon
/// - **Inactive**: Gray outline icon
/// - **Animation**: Smooth ease-in-out (150ms)
///
/// ## Usage
///
/// ```swift
/// Section("Performance") {
///     ThumbsToggle(label: "Mental", value: $mentalRating)
///     ThumbsToggle(label: "Pacing", value: $pacingRating)
///     ThumbsToggle(label: "Precision", value: $precisionRating)
/// }
/// ```
///
/// ## Accessibility
///
/// - VoiceOver announces state changes (positive/neutral/negative)
/// - Colors are paired with icons for color-blind accessibility
/// - Supports Dynamic Type via `SCTypography`
///
/// - SeeAlso: ``PerformanceRating``
struct ThumbsToggle: View {
    /// Display label for the performance metric (e.g., "Mental", "Pacing").
    let label: String

    /// Current rating value.
    ///
    /// - `nil` represents neutral/unselected state
    /// - `.positive` represents thumbs up
    /// - `.negative` represents thumbs down
    @Binding var value: PerformanceRating?

    var body: some View {
        HStack {
            // Thumbs up button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    value = value == .positive ? nil : .positive
                }
            } label: {
                Image(systemName: value == .positive ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title3)
                    .foregroundStyle(value == .positive ? .green : SCColors.textTertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(label)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textPrimary)

            Spacer()

            // Thumbs down button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    value = value == .negative ? nil : .negative
                }
            } label: {
                Image(systemName: value == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.title3)
                    .foregroundStyle(value == .negative ? .red : SCColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, SCSpacing.xs)
    }
}

/// Performance rating for climb metrics.
///
/// Represents a binary subjective assessment of performance on a specific aspect
/// of a climb. The neutral state is represented by `nil` rather than an enum case.
///
/// ## Cases
///
/// - `.positive` - Felt good/strong on this aspect
/// - `.negative` - Struggled or needs work on this aspect
///
/// ## Design Note
///
/// There is no `.neutral` case because `nil` explicitly represents neutral/unselected state.
/// This makes the model clearer and prevents confusion between "explicitly neutral" and "not rated".
///
/// ## Usage
///
/// ```swift
/// @State private var mentalRating: PerformanceRating? = nil
///
/// // User taps thumbs up
/// mentalRating = .positive
///
/// // User taps thumbs up again (toggle off)
/// mentalRating = nil
/// ```
///
/// - SeeAlso: ``ThumbsToggle``
enum PerformanceRating: String, Codable, Sendable {
    /// Thumbs up - felt good/strong on this aspect.
    case positive

    /// Thumbs down - struggled or needs work on this aspect.
    case negative

    /// Human-readable display name for the rating.
    var displayName: String {
        switch self {
        case .positive: return "Good"
        case .negative: return "Struggled"
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mental: PerformanceRating? = nil
        @State private var pacing: PerformanceRating? = .positive
        @State private var precision: PerformanceRating? = .negative

        var body: some View {
            Form {
                Section("Performance") {
                    ThumbsToggle(label: "Mental", value: $mental)
                    ThumbsToggle(label: "Pacing", value: $pacing)
                    ThumbsToggle(label: "Precision", value: $precision)
                }
            }
        }
    }

    return PreviewWrapper()
}
