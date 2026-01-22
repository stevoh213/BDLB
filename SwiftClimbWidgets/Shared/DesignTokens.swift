// DesignTokens.swift
// SwiftClimbWidgets
//
// Subset of design system tokens for widget styling.
//
// This provides consistent styling for Live Activity views without
// importing the full design system from the main app.

import SwiftUI

/// Design tokens for widget styling.
///
/// These are a lightweight subset of the main app's design system,
/// optimized for Live Activity and widget contexts.
enum WidgetDesignTokens {

    // MARK: - Colors

    /// Primary accent color for interactive elements.
    static let accentColor = Color.orange

    /// Secondary text color.
    static let textSecondary = Color.secondary

    /// Tertiary text color.
    static let textTertiary = Color(white: 0.6)

    // MARK: - Spacing

    /// Extra small spacing (4pt)
    static let spacingXS: CGFloat = 4

    /// Small spacing (8pt)
    static let spacingSM: CGFloat = 8

    /// Medium spacing (12pt)
    static let spacingMD: CGFloat = 12

    /// Large spacing (16pt)
    static let spacingLG: CGFloat = 16

    // MARK: - Corner Radius

    /// Small corner radius for chips/pills
    static let cornerRadiusSmall: CGFloat = 8

    /// Medium corner radius for cards
    static let cornerRadiusMedium: CGFloat = 12

    /// Large corner radius for buttons
    static let cornerRadiusLarge: CGFloat = 20
}
