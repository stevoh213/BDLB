import Foundation

/// Protocol for adding a climb to an active session with all details.
///
/// This use case handles the complete workflow of creating a climb and its associated attempts
/// from form data. It orchestrates between ``ClimbServiceProtocol`` and ``AttemptServiceProtocol``
/// to ensure atomic creation of climb records.
///
/// ## Responsibilities
///
/// 1. Parse and validate grade information
/// 2. Create climb entity via ``ClimbServiceProtocol``
/// 3. Create attempt records via ``AttemptServiceProtocol``
/// 4. Apply attempt outcome logic (send vs. project)
///
/// ## Threading
///
/// This protocol is `Sendable` and can be safely shared across actor boundaries.
/// All operations are async and properly isolated.
///
/// - SeeAlso: ``AddClimbUseCase``
protocol AddClimbUseCaseProtocol: Sendable {
    /// Executes the add climb use case with full climb data.
    ///
    /// Creates a new climb and its associated attempts in a coordinated manner.
    /// The climb is created first, then attempts are added sequentially to maintain
    /// proper ordering.
    ///
    /// - Parameters:
    ///   - userId: The ID of the user adding the climb.
    ///   - sessionId: The ID of the active session.
    ///   - discipline: The climbing discipline (boulder, sport, etc.).
    ///   - data: Form data from the Add Climb UI containing all climb details.
    ///   - isOutdoor: Whether this is an outdoor climb (true) or gym climb (false).
    ///   - openBetaClimbId: Optional OpenBeta climb reference for outdoor climbs.
    ///   - openBetaAreaId: Optional OpenBeta area reference for outdoor climbs.
    ///   - locationDisplay: Human-readable location string (e.g., "Brooklyn Boulders" or "Hueco Tanks, TX").
    ///
    /// - Returns: The ID of the newly created climb.
    ///
    /// - Throws: ``ClimbError/invalidGrade(_)`` if the grade string cannot be parsed.
    /// - Throws: Service-level errors if persistence fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let data = AddClimbData(
    ///     name: "Red Corner Problem",
    ///     gradeString: "V5",
    ///     gradeScale: .v,
    ///     attemptCount: 3,
    ///     outcome: .send,
    ///     tickType: .redpoint,
    ///     notes: "Tricky heel hook at the top",
    ///     mentalRating: .positive,
    ///     pacingRating: nil,
    ///     precisionRating: .negative,
    ///     noCutLooseRating: .positive
    /// )
    ///
    /// let climbId = try await useCase.execute(
    ///     userId: currentUserId,
    ///     sessionId: activeSessionId,
    ///     discipline: .bouldering,
    ///     data: data,
    ///     isOutdoor: false,
    ///     openBetaClimbId: nil,
    ///     openBetaAreaId: nil,
    ///     locationDisplay: "Brooklyn Boulders"
    /// )
    /// ```
    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        data: AddClimbData,
        isOutdoor: Bool,
        openBetaClimbId: String?,
        openBetaAreaId: String?,
        locationDisplay: String?
    ) async throws -> UUID
}

/// Implementation of ``AddClimbUseCaseProtocol`` with grade parsing, validation, and attempt creation.
///
/// This use case coordinates between climb and attempt services to create a complete
/// climb record with all associated attempts. It implements the offline-first architecture
/// by delegating persistence to services that handle local SwiftData storage and background sync.
///
/// ## Attempt Creation Logic
///
/// Attempts are created based on the ``ClimbOutcome`` and attempt count:
///
/// | Attempt Count | Outcome | Result |
/// |---------------|---------|--------|
/// | 1 | Send | 1 send with tick type |
/// | 3 | Send | 2 tries + 1 send with tick type |
/// | 5 | Project | 5 tries (no tick type) |
///
/// ## Threading
///
/// This class is `Sendable` and can be safely shared across actor boundaries.
/// Dependencies (services) must also be `Sendable` and thread-safe.
///
/// ## Example
///
/// ```swift
/// let useCase = AddClimbUseCase(
///     climbService: ClimbService(modelContext: context),
///     attemptService: AttemptService(modelContext: context)
/// )
///
/// let climbId = try await useCase.execute(...)
/// ```
final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let attemptService: AttemptServiceProtocol
    private let tagService: TagServiceProtocol
    private let liveActivityManager: LiveActivityManagerProtocol?

    /// Creates a new add climb use case.
    ///
    /// - Parameters:
    ///   - climbService: Service for climb persistence operations.
    ///   - attemptService: Service for attempt persistence operations.
    ///   - tagService: Service for tag impact operations.
    ///   - liveActivityManager: Optional manager for Live Activity updates.
    init(
        climbService: ClimbServiceProtocol,
        attemptService: AttemptServiceProtocol,
        tagService: TagServiceProtocol,
        liveActivityManager: LiveActivityManagerProtocol? = nil
    ) {
        self.climbService = climbService
        self.attemptService = attemptService
        self.tagService = tagService
        self.liveActivityManager = liveActivityManager
    }

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        data: AddClimbData,
        isOutdoor: Bool = false,
        openBetaClimbId: String? = nil,
        openBetaAreaId: String? = nil,
        locationDisplay: String? = nil
    ) async throws -> UUID {
        // Parse grade from string
        guard let grade = Grade.parse(data.gradeString) else {
            throw ClimbError.invalidGrade(data.gradeString)
        }

        // Create climb via service (validates and persists locally)
        let climbId = try await climbService.createClimb(
            userId: userId,
            sessionId: sessionId,
            discipline: discipline,
            isOutdoor: isOutdoor,
            name: data.name,
            grade: grade,
            openBetaClimbId: openBetaClimbId,
            openBetaAreaId: openBetaAreaId,
            locationDisplay: locationDisplay,
            notes: data.notes
        )

        // Create attempts based on the form data
        try await createAttempts(
            userId: userId,
            sessionId: sessionId,
            climbId: climbId,
            attemptCount: data.attemptCount,
            outcome: data.outcome,
            tickType: data.tickType
        )

        // Create tag impacts
        if !data.holdTypeImpacts.isEmpty {
            try await tagService.setHoldTypeImpacts(
                userId: userId,
                climbId: climbId,
                impacts: data.holdTypeImpacts
            )
        }

        if !data.skillImpacts.isEmpty {
            try await tagService.setSkillImpacts(
                userId: userId,
                climbId: climbId,
                impacts: data.skillImpacts
            )
        }

        // Update Live Activity with new counts
        // Note: We need to get the updated counts from the session
        // For now, we increment based on what we just added
        if let liveActivityManager = liveActivityManager {
            // Fetch current counts from climbService
            let counts = try await climbService.getSessionCounts(sessionId: sessionId)
            await liveActivityManager.updateActivity(
                sessionId: sessionId,
                climbCount: counts.climbCount,
                attemptCount: counts.attemptCount
            )
        }

        return climbId
    }

    /// Creates attempts for the climb based on form input.
    ///
    /// This method implements the attempt creation logic based on ``ClimbOutcome``:
    ///
    /// - **Send outcome**: Last attempt is marked as send with the specified tick type,
    ///   all previous attempts are marked as tries.
    /// - **Project outcome**: All attempts are marked as tries with no tick type.
    ///
    /// Attempts are created sequentially to maintain proper ordering. Each attempt
    /// is persisted locally via ``AttemptServiceProtocol/logAttempt(userId:sessionId:climbId:outcome:sendType:)``
    /// and queued for background sync.
    ///
    /// - Parameters:
    ///   - userId: The ID of the user creating the attempts.
    ///   - sessionId: The ID of the session.
    ///   - climbId: The ID of the climb these attempts belong to.
    ///   - attemptCount: Total number of attempts to create (1-99).
    ///   - outcome: Whether the climb was sent or is still a project.
    ///   - tickType: Type of send (flash, redpoint, etc.) if outcome is send.
    ///
    /// - Throws: Service-level errors if persistence fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Creates 3 attempts: 2 tries + 1 redpoint send
    /// try await createAttempts(
    ///     userId: userId,
    ///     sessionId: sessionId,
    ///     climbId: climbId,
    ///     attemptCount: 3,
    ///     outcome: .send,
    ///     tickType: .redpoint
    /// )
    /// ```
    private func createAttempts(
        userId: UUID,
        sessionId: UUID,
        climbId: UUID,
        attemptCount: Int,
        outcome: ClimbOutcome,
        tickType: SendType?
    ) async throws {
        // If outcome is Project, all attempts are tries
        // If outcome is Send, last attempt is a send with tick type, previous are tries
        for attemptNumber in 1...attemptCount {
            let isLastAttempt = attemptNumber == attemptCount
            let attemptOutcome: AttemptOutcome
            let attemptSendType: SendType?

            if outcome == .send && isLastAttempt {
                // Last attempt is the successful send
                attemptOutcome = .send
                attemptSendType = tickType
            } else {
                // All other attempts are tries
                attemptOutcome = .try
                attemptSendType = nil
            }

            // Create attempt via service (auto-calculates attempt number)
            _ = try await attemptService.logAttempt(
                userId: userId,
                sessionId: sessionId,
                climbId: climbId,
                outcome: attemptOutcome,
                sendType: attemptSendType
            )
        }
    }
}
