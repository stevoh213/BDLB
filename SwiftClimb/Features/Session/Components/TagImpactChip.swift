import SwiftUI

/// Selection state for a tag with impact rating.
///
/// Represents the three possible states of a tag in the selection UI:
/// - `nil` = unselected (tag not relevant to this climb)
/// - `.helped` = selected with positive impact (thumbs up)
/// - `.hindered` = selected with negative impact (thumbs down)
struct TagSelection: Equatable, Sendable {
    let tagId: UUID
    let tagName: String
    var impact: TagImpact?
}

/// Three-state tag chip with inline thumbs up/down toggle.
///
/// Displays a tag name in a chip format with visual indication of selection state.
/// Tapping cycles through: unselected -> helped -> hindered -> unselected
///
/// ## Visual States
///
/// | State | Background | Left Icon | Right Icon |
/// |-------|------------|-----------|------------|
/// | Unselected | Gray | None | None |
/// | Helped | Green tint | Thumbs up (filled) | None |
/// | Hindered | Red tint | None | Thumbs down (filled) |
///
/// ## Interaction
///
/// Single tap cycles through states. Long press could be added for
/// future direct state selection via menu.
///
/// ## Example
///
/// ```swift
/// @State private var crimpSelection = TagSelection(
///     tagId: UUID(),
///     tagName: "Crimp",
///     impact: nil
/// )
///
/// TagImpactChip(selection: $crimpSelection)
/// ```
struct TagImpactChip: View {
    @Binding var selection: TagSelection

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                cycleImpact()
            }
        } label: {
            HStack(spacing: SCSpacing.xxs) {
                // Thumbs up indicator (shown when helped)
                if selection.impact == .helped {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Text(selection.tagName)
                    .font(SCTypography.label)
                    .foregroundStyle(textColor)

                // Thumbs down indicator (shown when hindered)
                if selection.impact == .hindered {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, SCSpacing.sm)
            .padding(.vertical, SCSpacing.xs)
            .background(chipBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to change selection")
    }

    private var textColor: Color {
        switch selection.impact {
        case .helped:
            return .green
        case .hindered:
            return .red
        case .neutral, nil:
            return selection.impact == nil ? SCColors.textSecondary : SCColors.textPrimary
        }
    }

    @ViewBuilder
    private var chipBackground: some View {
        switch selection.impact {
        case .helped:
            Capsule()
                .fill(Color.green.opacity(0.15))
                .overlay {
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                }
        case .hindered:
            Capsule()
                .fill(Color.red.opacity(0.15))
                .overlay {
                    Capsule()
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                }
        case .neutral, nil:
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }

    private func cycleImpact() {
        switch selection.impact {
        case nil:
            selection.impact = .helped
        case .helped:
            selection.impact = .hindered
        case .hindered, .neutral:
            selection.impact = nil
        }
    }

    private var accessibilityLabel: String {
        let state: String
        switch selection.impact {
        case nil:
            state = "unselected"
        case .helped:
            state = "helped"
        case .hindered:
            state = "hindered"
        case .neutral:
            state = "neutral"
        }
        return "\(selection.tagName), \(state)"
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var crimp = TagSelection(tagId: UUID(), tagName: "Crimp", impact: nil)
        @State private var sloper = TagSelection(tagId: UUID(), tagName: "Sloper", impact: .helped)
        @State private var pinch = TagSelection(tagId: UUID(), tagName: "Pinch", impact: .hindered)

        var body: some View {
            VStack(spacing: SCSpacing.md) {
                Text("Tap to cycle: unselected -> helped -> hindered")
                    .font(.caption)

                HStack(spacing: SCSpacing.xs) {
                    TagImpactChip(selection: $crimp)
                    TagImpactChip(selection: $sloper)
                    TagImpactChip(selection: $pinch)
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
