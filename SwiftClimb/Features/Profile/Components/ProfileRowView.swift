import SwiftUI

/// Compact profile row for lists
///
/// Displays avatar, name, and handle in a horizontal row with optional
/// trailing content (typically a FollowButton). Used in follower lists,
/// following lists, and search results.
///
/// ## Usage
/// ```swift
/// // Basic usage
/// ProfileRowView(
///     id: profile.id,
///     handle: profile.handle,
///     displayName: profile.displayName,
///     photoURL: profile.photoURL
/// ) {
///     // Navigate to profile
/// }
///
/// // With follow button
/// ProfileRowView(
///     id: profile.id,
///     handle: profile.handle,
///     displayName: profile.displayName,
///     photoURL: profile.photoURL,
///     trailingContent: {
///         FollowButton(
///             isFollowing: isFollowing,
///             isLoading: isLoading,
///             onTap: { toggleFollow(profile.id) }
///         )
///     }
/// ) {
///     navigateToProfile(profile.id)
/// }
/// ```
struct ProfileRowView<TrailingContent: View>: View {
    let id: UUID
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let trailingContent: (() -> TrailingContent)?
    let onTap: (() -> Void)?

    init(
        id: UUID,
        handle: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        bio: String? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.photoURL = photoURL
        self.bio = bio
        self.trailingContent = trailingContent
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: SCSpacing.sm) {
                // Avatar
                ProfileAvatarView(
                    photoURL: photoURL,
                    size: .small
                )

                // Name and handle
                VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                    Text(displayName ?? handle)
                        .font(SCTypography.cardTitle)
                        .foregroundStyle(SCColors.textPrimary)
                        .lineLimit(1)

                    Text("@\(handle)")
                        .font(SCTypography.metadata)
                        .foregroundStyle(SCColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Trailing content (e.g., FollowButton)
                if let trailingContent = trailingContent {
                    trailingContent()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(onTap != nil ? "Double tap to view profile" : "")
    }

    private var accessibilityLabel: String {
        displayName ?? handle + ", @\(handle)"
    }
}

// MARK: - Convenience initializer without trailing content

extension ProfileRowView where TrailingContent == EmptyView {
    init(
        id: UUID,
        handle: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        bio: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.photoURL = photoURL
        self.bio = bio
        self.trailingContent = nil
        self.onTap = onTap
    }
}

// MARK: - Previews

#Preview("Basic Rows") {
    List {
        ProfileRowView(
            id: UUID(),
            handle: "climber_alex",
            displayName: "Alex Chen",
            photoURL: nil,
            onTap: { print("Profile tapped") }
        )

        ProfileRowView(
            id: UUID(),
            handle: "boulder_pro",
            displayName: "Jordan Smith",
            photoURL: nil,
            onTap: { print("Profile tapped") }
        )

        ProfileRowView(
            id: UUID(),
            handle: "sender_123",
            displayName: nil,
            photoURL: nil,
            onTap: { print("Profile tapped") }
        )
    }
}

#Preview("With Follow Buttons") {
    List {
        ProfileRowView(
            id: UUID(),
            handle: "climber_alex",
            displayName: "Alex Chen",
            photoURL: nil,
            trailingContent: {
                FollowButton(
                    isFollowing: false,
                    isLoading: false,
                    onTap: { print("Follow tapped") }
                )
            },
            onTap: { print("Profile tapped") }
        )

        ProfileRowView(
            id: UUID(),
            handle: "boulder_pro",
            displayName: "Jordan Smith",
            photoURL: nil,
            trailingContent: {
                FollowButton(
                    isFollowing: true,
                    isLoading: false,
                    onTap: { print("Unfollow tapped") }
                )
            },
            onTap: { print("Profile tapped") }
        )

        ProfileRowView(
            id: UUID(),
            handle: "sender_123",
            displayName: nil,
            photoURL: nil,
            trailingContent: {
                FollowButton(
                    isFollowing: false,
                    isLoading: true,
                    onTap: { }
                )
            },
            onTap: { print("Profile tapped") }
        )
    }
}

#Preview("Long Names") {
    List {
        ProfileRowView(
            id: UUID(),
            handle: "really_long_handle_name",
            displayName: "Alexander Chen The Third",
            photoURL: nil,
            trailingContent: {
                FollowButton(
                    isFollowing: false,
                    isLoading: false,
                    onTap: { print("Follow tapped") }
                )
            },
            onTap: { print("Profile tapped") }
        )

        ProfileRowView(
            id: UUID(),
            handle: "short",
            displayName: "A",
            photoURL: nil,
            trailingContent: {
                FollowButton(
                    isFollowing: true,
                    isLoading: false,
                    onTap: { print("Unfollow tapped") }
                )
            },
            onTap: { print("Profile tapped") }
        )
    }
}
