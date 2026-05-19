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

    /// Goal context is set, but we have not yet asked the user for HealthKit
    /// permission this install. Show the explainer + system prompt.
    case healthKitPermission

    /// Steady-state: read HealthKit metrics and show today's insight.
    case dailyInsight

    /// Hard cold-start failure (auth bootstrap or first server call). The
    /// associated string is the user-facing message.
    case error(String)
}
