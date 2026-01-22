// ClimbingSessionActivity.swift
// SwiftClimbWidgets
//
// ActivityConfiguration for the climbing session Live Activity.
//
// This file defines the main Live Activity configuration, including
// Lock Screen, Dynamic Island compact, and Dynamic Island expanded views.

import ActivityKit
import SwiftClimbFeature
import SwiftUI
import WidgetKit

/// Live Activity configuration for active climbing sessions.
///
/// This widget displays session information on the Lock Screen and Dynamic Island,
/// including an elapsed timer, climb count, and attempt count.
struct ClimbingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingSessionAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(WidgetDesignTokens.accentColor)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region (when user long-presses)
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandLeadingView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandTrailingView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandCenterView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBottomView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                // Compact leading (left side of pill)
                CompactLeadingView(attributes: context.attributes)
            } compactTrailing: {
                // Compact trailing (right side of pill)
                CompactTrailingView(
                    attributes: context.attributes,
                    state: context.state
                )
            } minimal: {
                // Minimal view (when another Live Activity is present)
                MinimalView(attributes: context.attributes)
            }
        }
    }
}

// MARK: - Lock Screen View

/// Full Lock Screen / Banner view for the Live Activity.
private struct LockScreenView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header row with discipline and timer
            HStack {
                // Discipline badge
                HStack(spacing: 4) {
                    Image(systemName: "figure.climbing")
                        .font(.caption)
                    Text(attributes.disciplineDisplayName)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2))
                .cornerRadius(8)

                Spacer()

                // Elapsed timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(attributes.startedAt, style: .timer)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .monospacedDigit()
                }
            }

            // Session info row
            HStack(spacing: 16) {
                // Date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(dateFormatter.string(from: attributes.startedAt))
                        .font(.caption)
                }

                // Start time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(timeFormatter.string(from: attributes.startedAt))
                        .font(.caption)
                }

                Spacer()
            }
            .foregroundStyle(.white.opacity(0.8))

            // Stats and action row
            HStack(spacing: 16) {
                // Climbs
                StatView(
                    icon: "number",
                    value: "\(state.climbCount)",
                    label: "Climbs"
                )

                // Attempts
                StatView(
                    icon: "arrow.counterclockwise",
                    value: "\(state.attemptCount)",
                    label: "Attempts"
                )

                Spacer()

                // Add Climb button
                if let url = attributes.addClimbDeepLink {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Climb")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetDesignTokens.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white)
                        .cornerRadius(20)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

/// Small stat display used in Lock Screen view.
private struct StatView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Dynamic Island Compact Views

/// Compact leading view (left side of pill).
private struct CompactLeadingView: View {
    let attributes: ClimbingSessionAttributes

    var body: some View {
        Image(systemName: "figure.climbing")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(WidgetDesignTokens.accentColor)
    }
}

/// Compact trailing view (right side of pill).
private struct CompactTrailingView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        Text(attributes.startedAt, style: .timer)
            .font(.system(size: 14, design: .monospaced).weight(.medium))
            .monospacedDigit()
    }
}

/// Minimal view (when another Live Activity is present).
private struct MinimalView: View {
    let attributes: ClimbingSessionAttributes

    var body: some View {
        Image(systemName: "figure.climbing")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(WidgetDesignTokens.accentColor)
    }
}

// MARK: - Dynamic Island Expanded Views

/// Leading section of expanded Dynamic Island.
private struct DynamicIslandLeadingView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        // Keep minimal - stats moved to center
        EmptyView()
    }
}

/// Trailing section of expanded Dynamic Island.
private struct DynamicIslandTrailingView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        // Keep minimal - stats moved to center
        EmptyView()
    }
}

/// Center section of expanded Dynamic Island.
private struct DynamicIslandCenterView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(spacing: 6) {
            // Top row: Stats
            HStack(spacing: 16) {
                // Climbs
                HStack(spacing: 4) {
                    Text("\(state.climbCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetDesignTokens.accentColor)
                    Text("Climbs")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Attempts
                HStack(spacing: 4) {
                    Text("\(state.attemptCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetDesignTokens.accentColor)
                    Text("Attempts")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Discipline + Timer row
            HStack(spacing: 8) {
                // Discipline badge
                HStack(spacing: 4) {
                    Image(systemName: "figure.climbing")
                        .font(.caption2)
                    Text(attributes.disciplineDisplayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(WidgetDesignTokens.accentColor)

                // Elapsed timer
                Text(attributes.startedAt, style: .timer)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .monospacedDigit()
            }

            // Start time
            Text("Started \(timeFormatter.string(from: attributes.startedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Bottom section of expanded Dynamic Island.
private struct DynamicIslandBottomView: View {
    let attributes: ClimbingSessionAttributes
    let state: ClimbingSessionAttributes.ContentState

    var body: some View {
        if let url = attributes.addClimbDeepLink {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Climb")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WidgetDesignTokens.accentColor)
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: ClimbingSessionAttributes(
    sessionId: UUID(),
    discipline: "bouldering",
    startedAt: Date().addingTimeInterval(-3600)
)) {
    ClimbingSessionLiveActivity()
} contentStates: {
    ClimbingSessionAttributes.ContentState(
        climbCount: 5,
        attemptCount: 12,
        lastUpdated: Date()
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: ClimbingSessionAttributes(
    sessionId: UUID(),
    discipline: "sport",
    startedAt: Date().addingTimeInterval(-1800)
)) {
    ClimbingSessionLiveActivity()
} contentStates: {
    ClimbingSessionAttributes.ContentState(
        climbCount: 3,
        attemptCount: 8,
        lastUpdated: Date()
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: ClimbingSessionAttributes(
    sessionId: UUID(),
    discipline: "bouldering",
    startedAt: Date().addingTimeInterval(-2700)
)) {
    ClimbingSessionLiveActivity()
} contentStates: {
    ClimbingSessionAttributes.ContentState(
        climbCount: 7,
        attemptCount: 15,
        lastUpdated: Date()
    )
}
