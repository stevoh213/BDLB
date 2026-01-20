import SwiftUI

/// Profile header displaying identity information
///
/// Shows avatar, name, handle, bio, and home gym in a vertical stack.
/// Used at the top of MyProfileView and OtherProfileView.
///
/// ## Usage
/// ```swift
/// ProfileHeaderView(
///     handle: profile.handle,
///     displayName: profile.displayName,
///     photoURL: profile.photoURL,
///     bio: profile.bio,
///     homeGym: profile.homeGym,
///     isEditable: true,
///     onAvatarTap: { showPhotoPicker = true }
/// )
/// ```
struct ProfileHeaderView: View {
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let homeGym: String?
    let isEditable: Bool
    let onAvatarTap: (() -> Void)?

    init(
        handle: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        bio: String? = nil,
        homeGym: String? = nil,
        isEditable: Bool = false,
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.handle = handle
        self.displayName = displayName
        self.photoURL = photoURL
        self.bio = bio
        self.homeGym = homeGym
        self.isEditable = isEditable
        self.onAvatarTap = onAvatarTap
    }

    var body: some View {
        VStack(spacing: SCSpacing.md) {
            // Avatar
            ProfileAvatarView(
                photoURL: photoURL,
                size: .large,
                isEditable: isEditable,
                onTap: onAvatarTap
            )

            // Name and handle
            VStack(spacing: SCSpacing.xxs) {
                Text(displayName ?? handle)
                    .font(SCTypography.screenHeader)
                    .fontWeight(.bold)

                Text("@\(handle)")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }

            // Bio (if present)
            if let bio = bio, !bio.isEmpty {
                Text(bio)
                    .font(SCTypography.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Home gym (if present)
            if let homeGym = homeGym, !homeGym.isEmpty {
                Label(homeGym, systemImage: "mappin.circle.fill")
                    .font(SCTypography.metadata)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [displayName ?? handle, "@\(handle)"]
        if let bio = bio { parts.append(bio) }
        if let homeGym = homeGym { parts.append("Home gym: \(homeGym)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("Complete Profile") {
    ProfileHeaderView(
        handle: "climber_alex",
        displayName: "Alex Chen",
        photoURL: nil,
        bio: "Weekend warrior, lover of crimps and slopers. Training for my first V10.",
        homeGym: "Brooklyn Boulders",
        isEditable: false
    )
    .padding()
}

#Preview("Editable - Own Profile") {
    ProfileHeaderView(
        handle: "climber_alex",
        displayName: "Alex Chen",
        photoURL: nil,
        bio: "Weekend warrior, lover of crimps and slopers.",
        homeGym: "Brooklyn Boulders",
        isEditable: true,
        onAvatarTap: { print("Avatar tapped") }
    )
    .padding()
}

#Preview("Minimal Profile") {
    ProfileHeaderView(
        handle: "new_climber",
        displayName: nil,
        photoURL: nil,
        bio: nil,
        homeGym: nil,
        isEditable: false
    )
    .padding()
}

#Preview("No Display Name") {
    ProfileHeaderView(
        handle: "climber_123",
        displayName: nil,
        photoURL: nil,
        bio: "Just started climbing, loving every moment!",
        homeGym: "Movement Gym",
        isEditable: false
    )
    .padding()
}

#Preview("Long Bio") {
    ProfileHeaderView(
        handle: "pro_climber",
        displayName: "Jordan Smith",
        photoURL: nil,
        bio: "Professional climber competing internationally. Training 6 days a week. Love outdoor bouldering in Bishop and sport climbing in Red River Gorge. Follow my journey as I attempt to send my first 5.14d!",
        homeGym: "Sender One Climbing",
        isEditable: false
    )
    .padding()
}
