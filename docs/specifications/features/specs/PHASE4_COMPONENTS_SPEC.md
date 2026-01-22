# Phase 4: Components Specification

> **Feature**: Social Profile Feature - UI Components
> **Phase**: 4 of 7
> **Status**: Ready for Implementation
> **Created**: 2026-01-19
> **Author**: Agent 1 (Architect)

---

## Table of Contents
1. [Overview](#overview)
2. [Design System Integration](#design-system-integration)
3. [Component Specifications](#component-specifications)
   - [4.1 ProfileHeaderView](#41-profileheaderview)
   - [4.2 ProfileStatsView](#42-profilestatsview)
   - [4.3 ProfileAvatarView](#43-profileavatarview)
   - [4.4 ProfileRowView](#44-profilerowview)
   - [4.5 FollowButton](#45-followbutton)
4. [Shared Types](#shared-types)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Builder Handoff Notes](#builder-handoff-notes)

---

## Overview

### Purpose
This phase creates five reusable UI components for the Social Profile feature. These components will be composed by Phase 5 views (MyProfileView, OtherProfileView, ProfileSearchView, etc.) and follow SwiftClimb design system patterns.

### Component Summary

| Component | Purpose | Used By |
|-----------|---------|---------|
| `ProfileHeaderView` | Display name, handle, bio, home gym | MyProfileView, OtherProfileView |
| `ProfileStatsView` | Follower/following/sends counts with tap actions | MyProfileView, OtherProfileView |
| `ProfileAvatarView` | Profile photo with edit capability | MyProfileView, OtherProfileView, ProfileRowView |
| `ProfileRowView` | Compact profile display for lists | FollowersListView, FollowingListView, ProfileSearchView |
| `FollowButton` | Follow/unfollow toggle button | OtherProfileView, ProfileRowView |

### File Locations

All components will be created in:
```
SwiftClimb/Features/Profile/Components/
  ProfileHeaderView.swift
  ProfileStatsView.swift
  ProfileAvatarView.swift
  ProfileRowView.swift
  FollowButton.swift
```

---

## Design System Integration

### Available Design Tokens

Components must use these existing design system tokens:

#### Spacing (`SCSpacing`)
```swift
SCSpacing.xxs  // 4pt  - Micro spacing (icon-text gaps)
SCSpacing.xs   // 8pt  - Tight spacing (within compact elements)
SCSpacing.sm   // 12pt - Small spacing (related elements)
SCSpacing.md   // 16pt - Medium spacing (standard padding)
SCSpacing.lg   // 24pt - Large spacing (section gaps)
SCSpacing.xl   // 32pt - Extra large (major sections)
```

#### Typography (`SCTypography`)
```swift
SCTypography.screenHeader  // .largeTitle - Display name
SCTypography.sectionHeader // .title - Section titles
SCTypography.cardTitle     // .headline - Row titles
SCTypography.body          // .body - Primary content
SCTypography.secondary     // .callout - Secondary content
SCTypography.metadata      // .caption - Metadata
SCTypography.label         // .caption2 - Small labels
```

#### Colors (`SCColors`)
```swift
SCColors.primary           // Blue - Brand color, links
SCColors.textPrimary       // .primary - Primary text
SCColors.textSecondary     // .secondary - Secondary text
SCColors.textTertiary      // Gray 0.6 - Tertiary text
SCColors.surfaceSecondary  // .secondarySystemBackground - Backgrounds
```

#### Corner Radius (`SCCornerRadius`)
```swift
SCCornerRadius.card    // 12pt - Cards and containers
SCCornerRadius.chip    // 8pt - Small elements
SCCornerRadius.button  // 12pt - Buttons
```

### Pattern Reference

Follow the existing component patterns from `SCPrimaryButton` and `SCTagChip`:
- Use `@ViewBuilder` for conditional content
- Define clear input parameters (not overly coupled to domain models)
- Include `#Preview` blocks for design verification
- Support accessibility with labels and minimum touch targets

---

## Component Specifications

### 4.1 ProfileHeaderView

#### Purpose
Displays the profile header section with display name, @handle, bio, and home gym information. Used at the top of both own profile and other users' profiles.

#### Visual Layout
```
+----------------------------------+
|                                  |
|     [ProfileAvatarView 100pt]    |
|                                  |
|         Display Name             |  <- screenHeader, bold
|         @handle                  |  <- secondary, textSecondary
|                                  |
|   "Bio text goes here and can    |  <- body
|    wrap to multiple lines..."    |
|                                  |
|   [pin icon] Home Gym Name       |  <- metadata, textSecondary
|                                  |
+----------------------------------+
```

#### Input Parameters
```swift
struct ProfileHeaderView: View {
    // Required
    let handle: String

    // Optional display fields
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let homeGym: String?

    // Edit capability (for own profile)
    let isEditable: Bool
    let onAvatarTap: (() -> Void)?
}
```

#### SwiftUI Implementation Structure
```swift
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
```

#### Accessibility Requirements
- Combined accessibility element for VoiceOver
- Announce display name, handle, bio, and home gym
- If editable, announce "Double tap to change profile photo" on avatar

---

### 4.2 ProfileStatsView

#### Purpose
Displays follower count, following count, and sends count in a horizontal row. Each stat is tappable to navigate to the respective list.

#### Visual Layout
```
+----------------------------------+
|   123         45         678     |
| Followers  Following    Sends    |
|  [tap]       [tap]      [tap]    |
+----------------------------------+
```

#### Input Parameters
```swift
struct ProfileStatsView: View {
    let followerCount: Int
    let followingCount: Int
    let sendCount: Int

    // Navigation callbacks
    let onFollowersTap: (() -> Void)?
    let onFollowingTap: (() -> Void)?
    let onSendsTap: (() -> Void)?
}
```

#### SwiftUI Implementation Structure
```swift
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
```

#### Accessibility Requirements
- Each stat is a separate accessibility element
- Announce full count value (not abbreviated) for VoiceOver
- Include hint "Double tap to view list" when tappable

---

### 4.3 ProfileAvatarView

#### Purpose
Displays a user's profile photo with support for:
- Loading from URL (AsyncImage)
- Placeholder when no photo
- Edit overlay indicator for own profile
- Photo picker integration via callback

#### Visual Layout
```
Size: Small (40pt)     Size: Medium (60pt)    Size: Large (100pt)
+--------+             +----------+            +---------------+
|  [img] |             |  [img]   |            |               |
|        |             |          |            |     [img]     |
+--------+             +----------+            |               |
                                               +---------------+
                                                    [camera]   <- Edit badge (when editable)
```

#### Input Parameters
```swift
struct ProfileAvatarView: View {
    let photoURL: String?
    let size: AvatarSize
    let isEditable: Bool
    let onTap: (() -> Void)?

    enum AvatarSize {
        case small   // 40pt - For list rows
        case medium  // 60pt - For compact displays
        case large   // 100pt - For profile headers

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
}
```

#### SwiftUI Implementation Structure
```swift
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
```

#### Accessibility Requirements
- Label: "Profile photo" or "No profile photo"
- Hint for editable: "Double tap to change photo"
- Minimum touch target 44pt (satisfied by all sizes)

---

### 4.4 ProfileRowView

#### Purpose
Compact profile display for use in lists (followers, following, search results). Shows avatar, name, handle, and optional trailing content (like FollowButton).

#### Visual Layout
```
+--------------------------------------------------+
| [Avatar]  Display Name                 [Follow]  |
|    40pt   @handle                      [Button]  |
+--------------------------------------------------+
```

#### Input Parameters
```swift
struct ProfileRowView<TrailingContent: View>: View {
    // Profile data
    let id: UUID
    let handle: String
    let displayName: String?
    let photoURL: String?
    let bio: String?

    // Optional trailing content (e.g., FollowButton)
    let trailingContent: TrailingContent?

    // Navigation
    let onTap: (() -> Void)?
}
```

#### SwiftUI Implementation Structure
```swift
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
```

#### Accessibility Requirements
- Combined accessibility element
- Label: "Display Name, @handle"
- Hint: "Double tap to view profile"
- Trailing content (FollowButton) handled separately

---

### 4.5 FollowButton

#### Purpose
Toggle button for follow/unfollow actions. Shows different states:
- "Follow" (not following)
- "Following" (currently following)
- Loading spinner during action

#### Visual Layout
```
State: Not Following      State: Following        State: Loading
+----------+              +-----------+           +-----------+
|  Follow  |              | Following |           |   [...]   |
+----------+              +-----------+           +-----------+
  Primary                   Secondary               Disabled
```

#### Input Parameters
```swift
struct FollowButton: View {
    let isFollowing: Bool
    let isLoading: Bool
    let onTap: () -> Void
}
```

#### SwiftUI Implementation Structure
```swift
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
                        .tint(isFollowing ? SCColors.textPrimary : .white)
                }

                Text(buttonTitle)
                    .font(SCTypography.body)
                    .fontWeight(.medium)
            }
            .frame(minWidth: 90)
            .frame(height: 36)
            .padding(.horizontal, SCSpacing.sm)
        }
        .buttonStyle(followButtonStyle)
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to \(isFollowing ? "unfollow" : "follow")")
    }

    private var buttonTitle: String {
        if isLoading {
            return ""
        }
        return isFollowing ? "Following" : "Follow"
    }

    private var followButtonStyle: some ButtonStyle {
        if isFollowing {
            return AnyButtonStyle(.bordered)
        } else {
            return AnyButtonStyle(.borderedProminent)
        }
    }

    private var accessibilityLabel: String {
        if isLoading {
            return "Loading"
        }
        return isFollowing ? "Following" : "Follow"
    }
}

// MARK: - AnyButtonStyle helper

/// Type-erased button style for conditional styling
private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init(_ style: some ButtonStyle) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
```

**Alternative Implementation (Simpler)**

If the AnyButtonStyle approach is too complex, use conditional modifiers:

```swift
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
```

#### Accessibility Requirements
- Label: "Follow", "Following", or "Loading"
- Hint: "Double tap to follow" or "Double tap to unfollow"
- Minimum touch target 44pt height (36pt button + padding)

---

## Shared Types

### ProfileDisplayData Protocol

Components can optionally use this protocol for type-safe profile data binding:

```swift
/// Common profile display data shared across components
///
/// This protocol allows components to accept either SCProfile (SwiftData model)
/// or ProfileSearchResultDTO (network response) without coupling to specific types.
protocol ProfileDisplayData {
    var id: UUID { get }
    var handle: String { get }
    var displayName: String? { get }
    var photoURL: String? { get }
    var bio: String? { get }
    var followerCount: Int { get }
    var followingCount: Int { get }
    var sendCount: Int { get }
}

// MARK: - SCProfile Conformance

extension SCProfile: ProfileDisplayData {}

// MARK: - ProfileSearchResultDTO Conformance

extension ProfileSearchResultDTO: ProfileDisplayData {}
```

**Note**: This protocol is optional. Components accept individual parameters to maximize reusability and avoid tight coupling.

---

## Acceptance Criteria

### Task 4.1: ProfileHeaderView
- [ ] Displays profile avatar using ProfileAvatarView
- [ ] Shows display name (falls back to handle if nil)
- [ ] Shows @handle below display name
- [ ] Shows bio text when present (multiline, centered)
- [ ] Shows home gym with map pin icon when present
- [ ] Avatar is tappable when isEditable is true
- [ ] All text uses correct SCTypography tokens
- [ ] Spacing uses SCSpacing tokens
- [ ] VoiceOver reads all visible information
- [ ] Preview compiles and renders correctly

### Task 4.2: ProfileStatsView
- [ ] Displays three stats horizontally: Followers, Following, Sends
- [ ] Each stat shows count above label
- [ ] Large numbers abbreviated (1.2K, 1.5M)
- [ ] Each stat is tappable button
- [ ] Tap triggers respective callback
- [ ] Stats disabled when callback is nil
- [ ] VoiceOver announces full count values
- [ ] Minimum 44pt touch targets
- [ ] Preview compiles and renders correctly

### Task 4.3: ProfileAvatarView
- [ ] Supports three sizes: small (40pt), medium (60pt), large (100pt)
- [ ] Loads image from URL using AsyncImage
- [ ] Shows placeholder when photoURL is nil
- [ ] Shows loading indicator while image loads
- [ ] Shows placeholder on image load failure
- [ ] Shows camera badge when isEditable is true
- [ ] Tappable when onTap is provided
- [ ] Circular clip shape
- [ ] VoiceOver announces "Profile photo" or "No profile photo"
- [ ] Preview compiles and renders correctly

### Task 4.4: ProfileRowView
- [ ] Shows avatar (small size), name, and @handle
- [ ] Name truncates with ellipsis if too long
- [ ] Supports generic trailing content (e.g., FollowButton)
- [ ] Supports version without trailing content
- [ ] Entire row is tappable
- [ ] VoiceOver combines elements appropriately
- [ ] Minimum 44pt row height
- [ ] Preview compiles and renders correctly

### Task 4.5: FollowButton
- [ ] Shows "Follow" in primary style when not following
- [ ] Shows "Following" in secondary style when following
- [ ] Shows loading spinner when isLoading is true
- [ ] Button disabled during loading
- [ ] Calls onTap when tapped
- [ ] Minimum 90pt width, 36pt height
- [ ] VoiceOver announces current state
- [ ] VoiceOver provides appropriate hint
- [ ] Preview compiles and renders correctly

### General Acceptance Criteria
- [ ] All components are in `/Features/Profile/Components/` directory
- [ ] All components use SCSpacing, SCTypography, SCColors, SCCornerRadius tokens
- [ ] No hardcoded color or spacing values
- [ ] All components have documentation comments
- [ ] All components have #Preview blocks
- [ ] Build succeeds with no warnings
- [ ] All components support Dynamic Type

---

## Builder Handoff Notes

### Implementation Order

Build components in this sequence due to dependencies:

1. **ProfileAvatarView** (no dependencies)
2. **FollowButton** (no dependencies)
3. **ProfileStatsView** (no dependencies)
4. **ProfileHeaderView** (depends on ProfileAvatarView)
5. **ProfileRowView** (depends on ProfileAvatarView)

### Directory Setup

Create the Components directory if it doesn't exist:
```
mkdir -p SwiftClimb/Features/Profile/Components
```

### Dependencies

These components have **no external dependencies** beyond:
- SwiftUI (standard)
- Design System Tokens (already exist in `/Core/DesignSystem/Tokens/`)

### Integration Notes

1. **AvatarSize enum**: Place in `ProfileAvatarView.swift` file, outside the struct, so it can be referenced by other components.

2. **Photo Picker**: `ProfileAvatarView` only provides the `onTap` callback. The actual PhotosPicker UI will be in the parent view (MyProfileView in Phase 5).

3. **Follow State**: `FollowButton` is stateless. Parent views manage the `isFollowing` and `isLoading` state and call the `ToggleFollowUseCase`.

4. **Generic Trailing Content**: `ProfileRowView` uses `@ViewBuilder` for flexibility. The `EmptyView` extension provides a convenient initializer when no trailing content is needed.

### Testing in Previews

Each component should have multiple preview variations:

```swift
#Preview("ProfileAvatarView - Sizes") {
    HStack(spacing: 20) {
        ProfileAvatarView(photoURL: nil, size: .small)
        ProfileAvatarView(photoURL: nil, size: .medium)
        ProfileAvatarView(photoURL: nil, size: .large)
    }
}

#Preview("ProfileAvatarView - Editable") {
    ProfileAvatarView(
        photoURL: nil,
        size: .large,
        isEditable: true
    ) {
        print("Avatar tapped")
    }
}
```

### Code Review Checklist

Before marking Phase 4 complete, verify:

- [ ] All 5 component files created
- [ ] All acceptance criteria met
- [ ] Build succeeds (Cmd+B)
- [ ] Previews render correctly
- [ ] No compiler warnings
- [ ] VoiceOver works in preview simulator
- [ ] Update SOCIAL_PROFILE_FEATURE.md task tracking

---

## References

### Existing Files to Reference
- `/SwiftClimb/Core/DesignSystem/Components/SCPrimaryButton.swift` - Button pattern
- `/SwiftClimb/Core/DesignSystem/Components/SCTagChip.swift` - Conditional styling pattern
- `/SwiftClimb/Core/DesignSystem/Tokens/` - All design tokens
- `/SwiftClimb/Features/Profile/ProfileView.swift` - Current profile view structure

### Related Documentation
- `/Documentation/Features/SOCIAL_PROFILE_FEATURE.md` - Master feature document
- `/Documentation/Features/Specs/PHASE2_SERVICES_SPEC.md` - Services layer reference
- `/Documentation/Features/Specs/PHASE3_USECASES_SPEC.md` - Use cases layer reference

---

**End of Phase 4 Components Specification**
