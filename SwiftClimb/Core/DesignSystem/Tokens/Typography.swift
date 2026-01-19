import SwiftUI

enum SCTypography {
    /// Screen headers
    static let screenHeader: Font = .largeTitle

    /// Section headers
    static let sectionHeader: Font = .title

    /// Card titles
    static let cardTitle: Font = .headline

    /// Primary content
    static let body: Font = .body

    /// Secondary content
    static let secondary: Font = .callout

    /// Metadata
    static let metadata: Font = .caption

    /// Small labels
    static let label: Font = .caption2
}

extension Font {
    /// Convenience for applying font weight
    static func scFont(_ style: Font, weight: Font.Weight = .regular) -> Font {
        return style.weight(weight)
    }
}
