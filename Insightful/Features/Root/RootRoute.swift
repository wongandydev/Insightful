import Foundation

/// The state machine driving ``RootView``'s top-level routing decision.
///
/// `RootViewModel` transitions between cases as the cold-start sequence
/// resolves (``RootViewModel/start()``) and as child features signal they
/// are done (``RootViewModel/goalSetupCompleted()``,
/// ``RootViewModel/healthKitPermissionFinished()``).
enum RootRoute: Equatable, Sendable {
    /// Initial state. Cold-start work is in progress; the view shows a
    /// launch placeholder.
    case launching

    /// User has no saved goal context — route them through the goal-setup
    /// conversation.
    case goalSetup

    /// Read-only review of the agent's interpretation of the user's goal.
    /// Reached immediately after a successful goal-setup conversation and
    /// before the HealthKit permission prompt. The associated ``GoalContext``
    /// is what was returned by the agent on ``GoalStatus/goalComplete``.
    case goalSummary(GoalContext)

    /// Goal context is set, but we have not yet asked the user for HealthKit
    /// permission this install. Show the explainer + system prompt.
    case healthKitPermission

    /// Steady-state: the tabbed main shell. Home is the default tab; the
    /// daily insight is launched from there as a sheet.
    case main

    /// Hard cold-start failure (auth bootstrap or first server call). The
    /// associated ``AppError`` carries the user-facing category so the view
    /// can render distinct copy and iconography per failure mode.
    case error(AppError)
}
