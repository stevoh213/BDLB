import SwiftUI

/// Flowing grid of tag chips organized by category.
///
/// Displays tags in a flexible layout that wraps to fit available width.
/// Tags are grouped by category with section headers.
///
/// ## Example
///
/// ```swift
/// @State private var holdSelections: [TagSelection] = []
///
/// TagSelectionGrid(
///     title: "Hold Types",
///     selections: $holdSelections
/// )
/// ```
struct TagSelectionGrid: View {
    let title: String
    @Binding var selections: [TagSelection]

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text(title)
                .font(SCTypography.cardTitle)
                .foregroundStyle(SCColors.textPrimary)

            FlowLayout(spacing: SCSpacing.xs) {
                ForEach($selections, id: \.tagId) { $selection in
                    TagImpactChip(selection: $selection)
                }
            }
        }
    }
}

/// A layout that arranges views in a flowing left-to-right, top-to-bottom pattern.
///
/// Views are placed left-to-right until they would exceed the available width,
/// then wrap to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selections: [TagSelection] = [
            TagSelection(tagId: UUID(), tagName: "Crimp", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Sloper", impact: .helped),
            TagSelection(tagId: UUID(), tagName: "Jug", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Pinch", impact: .hindered),
            TagSelection(tagId: UUID(), tagName: "Pocket", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Sidepull", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Undercling", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Gaston", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Smear", impact: nil),
            TagSelection(tagId: UUID(), tagName: "Heel Hook", impact: .helped),
            TagSelection(tagId: UUID(), tagName: "Toe Hook", impact: nil)
        ]

        var body: some View {
            ScrollView {
                TagSelectionGrid(
                    title: "Hold Types",
                    selections: $selections
                )
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
