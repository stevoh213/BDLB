// Environment+UseCases.swift
// SwiftClimb
//
// Environment keys for dependency injection of use cases.
//
// This file defines SwiftUI EnvironmentKeys for injecting use cases into views.
// Use cases are set at the app root and accessed via @Environment in views.
//
// ## Usage
//
// ```swift
// // In app root:
// .environment(\.sessionUseCase, SessionUseCase(repository: sessionRepo))
//
// // In view:
// @Environment(\.sessionUseCase) private var sessionUseCase
// ```

import SwiftUI

// MARK: - Auth Manager

private struct AuthManagerKey: EnvironmentKey {
    static let defaultValue: SupabaseAuthManager? = nil
}

extension EnvironmentValues {
    var authManager: SupabaseAuthManager? {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }
}

// MARK: - Current User ID

private struct CurrentUserIdKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var currentUserId: UUID? {
        get { self[CurrentUserIdKey.self] }
        set { self[CurrentUserIdKey.self] = newValue }
    }
}

// MARK: - Start Session Use Case

private struct StartSessionUseCaseKey: EnvironmentKey {
    static let defaultValue: StartSessionUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var startSessionUseCase: StartSessionUseCaseProtocol? {
        get { self[StartSessionUseCaseKey.self] }
        set { self[StartSessionUseCaseKey.self] = newValue }
    }
}

// MARK: - End Session Use Case

private struct EndSessionUseCaseKey: EnvironmentKey {
    static let defaultValue: EndSessionUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var endSessionUseCase: EndSessionUseCaseProtocol? {
        get { self[EndSessionUseCaseKey.self] }
        set { self[EndSessionUseCaseKey.self] = newValue }
    }
}

// MARK: - Add Climb Use Case

private struct AddClimbUseCaseKey: EnvironmentKey {
    static let defaultValue: AddClimbUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var addClimbUseCase: AddClimbUseCaseProtocol? {
        get { self[AddClimbUseCaseKey.self] }
        set { self[AddClimbUseCaseKey.self] = newValue }
    }
}

// MARK: - Log Attempt Use Case

private struct LogAttemptUseCaseKey: EnvironmentKey {
    static let defaultValue: LogAttemptUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var logAttemptUseCase: LogAttemptUseCaseProtocol? {
        get { self[LogAttemptUseCaseKey.self] }
        set { self[LogAttemptUseCaseKey.self] = newValue }
    }
}

// MARK: - Create Post Use Case

private struct CreatePostUseCaseKey: EnvironmentKey {
    static let defaultValue: CreatePostUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var createPostUseCase: CreatePostUseCaseProtocol? {
        get { self[CreatePostUseCaseKey.self] }
        set { self[CreatePostUseCaseKey.self] = newValue }
    }
}

// MARK: - Toggle Follow Use Case

private struct ToggleFollowUseCaseKey: EnvironmentKey {
    static let defaultValue: ToggleFollowUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var toggleFollowUseCase: ToggleFollowUseCaseProtocol? {
        get { self[ToggleFollowUseCaseKey.self] }
        set { self[ToggleFollowUseCaseKey.self] = newValue }
    }
}

// MARK: - Search OpenBeta Use Case

private struct SearchOpenBetaUseCaseKey: EnvironmentKey {
    static let defaultValue: SearchOpenBetaUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var searchOpenBetaUseCase: SearchOpenBetaUseCaseProtocol? {
        get { self[SearchOpenBetaUseCaseKey.self] }
        set { self[SearchOpenBetaUseCaseKey.self] = newValue }
    }
}

// MARK: - Update Profile Use Case

private struct UpdateProfileUseCaseKey: EnvironmentKey {
    static let defaultValue: UpdateProfileUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var updateProfileUseCase: UpdateProfileUseCaseProtocol? {
        get { self[UpdateProfileUseCaseKey.self] }
        set { self[UpdateProfileUseCaseKey.self] = newValue }
    }
}

// MARK: - Search Profiles Use Case

private struct SearchProfilesUseCaseKey: EnvironmentKey {
    static let defaultValue: SearchProfilesUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var searchProfilesUseCase: SearchProfilesUseCaseProtocol? {
        get { self[SearchProfilesUseCaseKey.self] }
        set { self[SearchProfilesUseCaseKey.self] = newValue }
    }
}

// MARK: - Upload Profile Photo Use Case

private struct UploadProfilePhotoUseCaseKey: EnvironmentKey {
    static let defaultValue: UploadProfilePhotoUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var uploadProfilePhotoUseCase: UploadProfilePhotoUseCaseProtocol? {
        get { self[UploadProfilePhotoUseCaseKey.self] }
        set { self[UploadProfilePhotoUseCaseKey.self] = newValue }
    }
}

// MARK: - Get Followers Use Case

private struct GetFollowersUseCaseKey: EnvironmentKey {
    static let defaultValue: GetFollowersUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var getFollowersUseCase: GetFollowersUseCaseProtocol? {
        get { self[GetFollowersUseCaseKey.self] }
        set { self[GetFollowersUseCaseKey.self] = newValue }
    }
}

// MARK: - Get Following Use Case

private struct GetFollowingUseCaseKey: EnvironmentKey {
    static let defaultValue: GetFollowingUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var getFollowingUseCase: GetFollowingUseCaseProtocol? {
        get { self[GetFollowingUseCaseKey.self] }
        set { self[GetFollowingUseCaseKey.self] = newValue }
    }
}

// MARK: - Fetch Profile Use Case

private struct FetchProfileUseCaseKey: EnvironmentKey {
    static let defaultValue: FetchProfileUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var fetchProfileUseCase: FetchProfileUseCaseProtocol? {
        get { self[FetchProfileUseCaseKey.self] }
        set { self[FetchProfileUseCaseKey.self] = newValue }
    }
}

// MARK: - Feed Use Case (TODO: Implement)

private struct FeedUseCaseKey: EnvironmentKey {
    static let defaultValue: FeedUseCaseProtocol? = nil
}

extension EnvironmentValues {
    var feedUseCase: FeedUseCaseProtocol? {
        get { self[FeedUseCaseKey.self] }
        set { self[FeedUseCaseKey.self] = newValue }
    }
}

/// Placeholder protocol for feed operations (needs implementation)
protocol FeedUseCaseProtocol: Sendable {
    func loadFeed() async throws -> [SCPost]
    func toggleKudos(postId: UUID) async throws
}

// MARK: - Premium Service

private struct PremiumServiceKey: EnvironmentKey {
    static let defaultValue: PremiumServiceProtocol? = nil
}

extension EnvironmentValues {
    var premiumService: PremiumServiceProtocol? {
        get { self[PremiumServiceKey.self] }
        set { self[PremiumServiceKey.self] = newValue }
    }
}
