import SwiftUI

/// Profile avatar with async image loading
///
/// Displays a circular profile photo loaded from URL, with placeholder
/// when no photo is available. Supports edit mode with camera badge overlay.
///
/// ## Size Options
/// - `.small` (40pt): For list rows and compact displays
/// - `.medium` (60pt): For cards and moderate displays
/// - `.large` (100pt): For profile headers
///
/// ## Usage
/// ```swift
/// // Display only
/// ProfileAvatarView(photoURL: profile.photoURL, size: .small)
///
/// // Editable with photo picker
/// ProfileAvatarView(
///     photoURL: profile.photoURL,
///     size: .large,
///     isEditable: true,
///     onTap: { showPhotoPicker = true }
/// )
/// ```
struct ProfileAvatarView: View {
    let photoURL: String?
    let size: AvatarSize
    let isEditable: Bool
    let onTap: (() -> Void)?

    init(
        photoURL: String?,
        size: AvatarSize = .medium,
        isEditable: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.photoURL = photoURL
        self.size = size
        self.isEditable = isEditable
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            avatarContent
                .overlay(alignment: .bottomTrailing) {
                    if isEditable {
                        editBadge
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isEditable ? "Double tap to change photo" : "")
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let photoURL = photoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                        .overlay {
                            ProgressView()
                                .tint(SCColors.textSecondary)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.dimension, height: size.dimension)
                        .clipShape(Circle())
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(SCColors.surfaceSecondary)
            .frame(width: size.dimension, height: size.dimension)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(SCColors.textSecondary)
            }
    }

    private var editBadge: some View {
        Circle()
            .fill(SCColors.primary)
            .frame(width: size.dimension * 0.3, height: size.dimension * 0.3)
            .overlay {
                Image(systemName: "camera.fill")
                    .font(.system(size: size.dimension * 0.15))
                    .foregroundStyle(.white)
            }
            .offset(x: 2, y: 2)
    }

    private var accessibilityLabel: String {
        if photoURL != nil {
            return "Profile photo"
        } else {
            return "No profile photo"
        }
    }
}

// MARK: - AvatarSize

enum AvatarSize: Sendable {
    case small   // 40pt
    case medium  // 60pt
    case large   // 100pt

    var dimension: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 60
        case .large: return 100
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 40
        }
    }
}

// MARK: - Previews

#Preview("Sizes - No Photo") {
    VStack(spacing: SCSpacing.lg) {
        ProfileAvatarView(photoURL: nil, size: .small)
        ProfileAvatarView(photoURL: nil, size: .medium)
        ProfileAvatarView(photoURL: nil, size: .large)
    }
    .padding()
}

#Preview("Large - Editable") {
    ProfileAvatarView(
        photoURL: nil,
        size: .large,
        isEditable: true
    ) {
        print("Avatar tapped")
    }
    .padding()
}

#Preview("With Photo URL") {
    VStack(spacing: SCSpacing.lg) {
        ProfileAvatarView(
            photoURL: "https://example.com/photo.jpg",
            size: .small
        )
        ProfileAvatarView(
            photoURL: "https://example.com/photo.jpg",
            size: .medium
        )
        ProfileAvatarView(
            photoURL: "https://example.com/photo.jpg",
            size: .large
        )
    }
    .padding()
}
