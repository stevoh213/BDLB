import SwiftUI

/// Follow/unfollow toggle button
///
/// Displays contextual button state for follow actions:
/// - "Follow" (primary style) when not following
/// - "Following" (secondary style) when following
/// - Loading spinner during action
///
/// ## Usage
/// ```swift
/// @State private var isFollowing = false
/// @State private var isLoading = false
///
/// FollowButton(
///     isFollowing: isFollowing,
///     isLoading: isLoading,
///     onTap: {
///         isLoading = true
///         Task {
///             let result = try await toggleFollowUseCase.execute(...)
///             isFollowing = result
///             isLoading = false
///         }
///     }
/// )
/// ```
struct FollowButton: View {
    let isFollowing: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SCSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if !isLoading {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(SCTypography.body)
                        .fontWeight(.medium)
                }
            }
            .frame(minWidth: 90, minHeight: 36)
            .padding(.horizontal, SCSpacing.sm)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.button))
            .overlay {
                if isFollowing {
                    RoundedRectangle(cornerRadius: SCCornerRadius.button)
                        .stroke(SCColors.textSecondary.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Loading" : (isFollowing ? "Following" : "Follow"))
        .accessibilityHint("Double tap to \(isFollowing ? "unfollow" : "follow")")
    }

    private var buttonBackground: Color {
        isFollowing ? Color.clear : SCColors.primary
    }

    private var buttonForeground: Color {
        isFollowing ? SCColors.textPrimary : .white
    }
}

// MARK: - Previews

#Preview("Follow States") {
    VStack(spacing: SCSpacing.md) {
        FollowButton(
            isFollowing: false,
            isLoading: false,
            onTap: { print("Follow tapped") }
        )

        FollowButton(
            isFollowing: true,
            isLoading: false,
            onTap: { print("Unfollow tapped") }
        )

        FollowButton(
            isFollowing: false,
            isLoading: true,
            onTap: { }
        )

        FollowButton(
            isFollowing: true,
            isLoading: true,
            onTap: { }
        )
    }
    .padding()
}
