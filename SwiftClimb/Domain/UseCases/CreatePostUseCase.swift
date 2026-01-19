import Foundation

/// Create a social feed post
protocol CreatePostUseCaseProtocol: Sendable {
    func execute(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws -> SCPost
}

// Stub implementation
final class CreatePostUseCase: CreatePostUseCaseProtocol, @unchecked Sendable {
    private let socialService: SocialServiceProtocol

    init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
    }

    func execute(
        authorId: UUID,
        sessionId: UUID?,
        climbId: UUID?,
        content: String?
    ) async throws -> SCPost {
        // TODO: Implement use case
        // 1. Validate at least one of sessionId/climbId/content is present
        // 2. Create post via service
        // 3. Mark for sync
        return try await socialService.createPost(
            authorId: authorId,
            sessionId: sessionId,
            climbId: climbId,
            content: content
        )
    }
}
