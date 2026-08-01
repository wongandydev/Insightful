import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.andy.Insightful", category: "RootViewModel")

/// Drives the top-level routing decision for ``RootView``.
///
/// Responsible for the cold-start sequence (auth bootstrap → user sync →
/// goal-context fetch) and the post-launch transitions triggered by child
/// features completing. Holds the only mutable copy of the current
/// ``RootRoute``.
///
/// `@MainActor @Observable` because views read its `route` directly.
@MainActor
@Observable
final class RootViewModel {
    /// The currently-displayed top-level screen. Starts at ``RootRoute/launching``.
    private(set) var route: RootRoute
    /// The most recent ``GoalContext`` for this user. Hydrated by ``start()``
    /// from `GET /goal/context` on every cold start and overwritten when goal
    /// setup completes, so the summary screen can re-render after re-entry
    /// and downstream features (e.g. the goal-aware HealthKit rationale) can
    /// read it without re-fetching. `nil` only while launching or when the
    /// user has never completed goal setup.
    private(set) var goalContext: GoalContext?

    private let authService: AuthService
    private let userService: any UserServicing
    private let goalService: any GoalServicing
    private let userDefaults: UserDefaults

    init(
        authService: AuthService,
        userService: any UserServicing,
        goalService: any GoalServicing,
        userDefaults: UserDefaults
    ) {
        self.authService = authService
        self.userService = userService
        self.goalService = goalService
        self.userDefaults = userDefaults
        self.route = .launching
        self.goalContext = nil
    }

    /// Runs the cold-start sequence and sets ``route`` accordingly.
    ///
    /// 1. Bootstrap the Supabase session via ``AuthService/bootstrap()``.
    /// 2. Upsert the user row via ``UserService/sync()``.
    /// 3. Fetch the saved goal context via ``GoalService/getContext()``.
    /// 4. Pick a route: missing context → ``RootRoute/goalSetup``; have
    ///    context but never asked HealthKit → ``RootRoute/healthKitPermission``;
    ///    otherwise → ``RootRoute/main``.
    ///
    /// Any throw is bucketed into an ``AppError`` via ``AppError/from(_:)`` so
    /// the error screen can render offline / server / rate-limited / unknown
    /// copy distinctly. Idempotent: safe to call again after a retry from
    /// the error screen.
    func start() async {
        route = .launching
        logger.info("start: beginning cold-start sequence")
        do {
            logger.info("start: step 1/3 — auth bootstrap")
            try await authService.bootstrap()

            logger.info("start: step 2/3 — user sync")
            let userId = try await userService.sync()
            logger.info("start: user synced (id=\(userId, privacy: .private))")

            logger.info("start: step 3/3 — goal context")
            let context = try await goalService.getContext()
            goalContext = context.context

            let next = decideRoute(hasGoalContext: context.hasContext)
            logger.info("start: success → \(String(describing: next), privacy: .public)")
            route = next
        } catch {
            let bucket = AppError.from(error)
            logger.error("start: failed — type=\(String(describing: type(of: error)), privacy: .public) bucket=\(String(describing: bucket), privacy: .public) detail=\(String(describing: error), privacy: .public)")
            route = .error(bucket)
        }
    }

    /// Called by ``GoalSetupViewModel`` when the agent reports
    /// ``GoalStatus/goalComplete``. Stores the structured ``GoalContext`` so
    /// downstream views can render it without a refetch, then routes to
    /// ``RootRoute/goalSummary(_:)`` for a read-only review.
    func goalSetupCompleted(context: GoalContext) {
        goalContext = context
        route = .goalSummary(context)
    }

    /// Called by ``GoalSummaryView`` when the user accepts the agent's
    /// interpretation. Defers the next-screen choice to
    /// ``decideRoute(hasGoalContext:)`` so a returning user who already
    /// granted HealthKit lands directly on ``RootRoute/main``
    /// instead of seeing the permission explainer again.
    func goalSummaryConfirmed() {
        route = decideRoute(hasGoalContext: true)
    }

    /// Called by ``GoalSummaryView`` when the user rejects the agent's
    /// interpretation and wants to refine the conversation. The cached
    /// ``goalContext`` is preserved on purpose — Settings reads it to render
    /// the "View / edit my goal" entry while the refinement is in progress,
    /// and ``goalSetupCompleted(context:)`` overwrites it cleanly when the
    /// agent returns the updated context.
    func goalSummaryRequestedEdit() {
        route = .goalSetup
    }

    /// Called by ``GoalSetupView``'s Cancel button when the user backs out
    /// of a refinement chat without letting the agent finish. The cached
    /// ``goalContext`` is intact, so we route back to whatever the user
    /// would have seen had they never entered refinement. The backend
    /// thread that `/goal/start` reopened stays `active` (orphan) until the
    /// stale-thread cleanup job sweeps it — `user_context` is untouched, so
    /// the daily insight keeps using the prior goal.
    func cancelGoalRefinement() {
        route = decideRoute(hasGoalContext: goalContext != nil)
    }

    /// Called by ``HealthKitPermissionViewModel`` when the permission sheet
    /// has been shown (regardless of grant/deny outcome — iOS doesn't expose
    /// read state to apps). Records that we've asked and routes to the
    /// main tabbed shell.
    func healthKitPermissionFinished() {
        userDefaults.set(true, forKey: PreferenceKeys.hasAskedForHealthKitAuthorization)
        route = .main
    }

    /// Called by ``SettingsViewModel/resetGoal()`` when the user opts to
    /// redo goal setup. Routes back to the goal-setup screen; auth and
    /// HealthKit-asked state stay intact.
    func userRequestedGoalReset() {
        route = .goalSetup
    }

    /// Called by ``OnboardingView``'s continue button. Records that the
    /// explainer has been shown so it never reappears, then routes into the
    /// goal-setup conversation it framed.
    func onboardingFinished() {
        userDefaults.set(true, forKey: PreferenceKeys.hasSeenOnboarding)
        route = .goalSetup
    }

    // MARK: - Internals

    private func decideRoute(hasGoalContext: Bool) -> RootRoute {
        if !hasGoalContext {
            if !userDefaults.bool(forKey: PreferenceKeys.hasSeenOnboarding) {
                return .onboarding
            }
            return .goalSetup
        }
        if !userDefaults.bool(forKey: PreferenceKeys.hasAskedForHealthKitAuthorization) {
            return .healthKitPermission
        }
        return .main
    }
}

/// Namespace for ``UserDefaults`` keys.
///
/// iOS does not expose HealthKit read-permission state to apps (an app
/// cannot distinguish "no data" from "permission denied"), so we track
/// "have we ever asked" ourselves to gate the permission screen.
enum PreferenceKeys {
    static let hasAskedForHealthKitAuthorization = "hasAskedForHealthKitAuthorization"
    /// Whether the one-time onboarding explainer has been shown. Set by
    /// ``RootViewModel/onboardingFinished()``; never reset — onboarding only
    /// frames the first goal-setup conversation.
    static let hasSeenOnboarding = "hasSeenOnboarding"
}
