import SwiftUI

enum SCColors {
    // MARK: - Semantic Colors

    /// Primary brand color
    static let primary: Color = .blue

    /// Secondary brand color
    static let secondary: Color = .cyan

    /// Accent color for highlights
    static let accent: Color = .accentColor

    // MARK: - Metric Colors

    /// Low readiness/RPE (1-3)
    static let metricLow: Color = .red

    /// Medium readiness/RPE (4-6)
    static let metricMedium: Color = .orange

    /// High readiness/RPE (7-10)
    static let metricHigh: Color = .green

    // MARK: - Tag Impact Colors

    /// Helped impact
    static let impactHelped: Color = .green

    /// Hindered impact
    static let impactHindered: Color = .red

    /// Neutral impact
    static let impactNeutral: Color = .gray

    // MARK: - Surface Colors

    /// Card background (uses system material)
    static let cardBackground: Material = .regularMaterial

    /// Sheet background
    static let sheetBackground: Material = .thickMaterial

    /// Secondary surface background
    static let surfaceSecondary: Color = Color(.secondarySystemBackground)

    // MARK: - Text Colors

    /// Primary text
    static let textPrimary: Color = .primary

    /// Secondary text
    static let textSecondary: Color = .secondary

    /// Tertiary text
    static let textTertiary: Color = Color(white: 0.6)
}

// MARK: - Accessibility Support

extension SCColors {
    /// Returns appropriate color based on accessibility settings
    @MainActor
    static func adaptiveColor(
        _ color: Color,
        darkerSystemColors: Bool? = nil
    ) -> Color {
        let useDarker = darkerSystemColors ?? UIAccessibility.isDarkerSystemColorsEnabled
        guard useDarker else { return color }
        return color.opacity(1.2) // System handles actual darkening
    }
}
