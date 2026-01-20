import SwiftUI

/// Horizontal row of profile statistics
///
/// Displays follower, following, and send counts with tap actions.
/// Each stat is a tappable button that navigates to the respective list.
///
/// ## Usage
/// ```swift
/// ProfileStatsView(
///     followerCount: profile.followerCount,
///     followingCount: profile.followingCount,
///     sendCount: profile.sendCount,
///     onFollowersTap: { showFollowers = true },
///     onFollowingTap: { showFollowing = true },
///     onSendsTap: nil  // Sends list not yet implemented
/// )
/// ```
struct ProfileStatsView: View {
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int
    let onFollowersTap: (() -> Void)?
    let onFollowingTap: (() -> Void)?
    let onSendsTap: (() -> Void)?

    init(
        followerCount: Int,
        followingCount: Int,
        sendCount: Int,
        onFollowersTap: (() -> Void)? = nil,
        onFollowingTap: (() -> Void)? = nil,
        onSendsTap: (() -> Void)? = nil
    ) {
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.sendCount = sendCount
        self.onFollowersTap = onFollowersTap
        self.onFollowingTap = onFollowingTap
        self.onSendsTap = onSendsTap
    }

    var body: some View {
        HStack(spacing: SCSpacing.xl) {
            StatItem(
                count: followerCount,
                label: "Followers",
                action: onFollowersTap
            )

            StatItem(
                count: followingCount,
                label: "Following",
                action: onFollowingTap
            )

            StatItem(
                count: sendCount,
                label: "Sends",
                action: onSendsTap
            )
        }
    }
}

// MARK: - StatItem (Private)

private struct StatItem: View {
    let count: Int
    let label: String
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: SCSpacing.xxs) {
                Text(formattedCount)
                    .font(SCTypography.sectionHeader)
                    .fontWeight(.semibold)
                    .foregroundStyle(SCColors.textPrimary)

                Text(label)
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
            .frame(minWidth: 60)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(count) \(label)")
        .accessibilityHint(action != nil ? "Double tap to view list" : "")
    }

    /// Formats large numbers with K/M suffix
    private var formattedCount: String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 10_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Previews

#Preview("Small Counts") {
    ProfileStatsView(
        followerCount: 42,
        followingCount: 18,
        sendCount: 156,
        onFollowersTap: { print("Followers tapped") },
        onFollowingTap: { print("Following tapped") },
        onSendsTap: { print("Sends tapped") }
    )
    .padding()
}

#Preview("Large Counts") {
    ProfileStatsView(
        followerCount: 1_234,
        followingCount: 5_678,
        sendCount: 12_345,
        onFollowersTap: { print("Followers tapped") },
        onFollowingTap: { print("Following tapped") },
        onSendsTap: { print("Sends tapped") }
    )
    .padding()
}

#Preview("Million+ Counts") {
    ProfileStatsView(
        followerCount: 1_234_567,
        followingCount: 890,
        sendCount: 2_500_000,
        onFollowersTap: { print("Followers tapped") },
        onFollowingTap: { print("Following tapped") },
        onSendsTap: nil
    )
    .padding()
}

#Preview("Disabled States") {
    ProfileStatsView(
        followerCount: 100,
        followingCount: 50,
        sendCount: 200,
        onFollowersTap: nil,
        onFollowingTap: nil,
        onSendsTap: nil
    )
    .padding()
}
