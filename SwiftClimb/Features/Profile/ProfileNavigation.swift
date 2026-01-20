// ProfileNavigation.swift
// SwiftClimb
//
// Navigation destinations for profile-related views.
//
// This enum defines type-safe navigation destinations used throughout
// the profile feature. It enables SwiftUI's NavigationStack to handle
// push navigation to followers lists and other profiles.
//
// ## Usage
//
// ```swift
// NavigationStack(path: $navigationPath) {
//     // ... view content ...
// }
// .navigationDestination(for: ProfileNavigation.self) { destination in
//     switch destination {
//     case .followers(let userId, let userName):
//         FollowersListView(userId: userId, userName: userName)
//     // ...
//     }
// }
// ```

import Foundation

/// Navigation destinations for profile-related views
enum ProfileNavigation: Hashable {
    case followers(userId: UUID, userName: String)
    case following(userId: UUID, userName: String)
    case otherProfile(userId: UUID)
}
