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
    }

    /// Runs the cold-start sequence and sets ``route`` accordingly.
    ///
    /// 1. Bootstrap the Supabase session via ``AuthService/bootstrap()``.
    /// 2. Upsert the user row via ``UserService/sync()``.
    /// 3. Fetch the saved goal context via ``GoalService/getContext()``.
    /// 4. Pick a route: missing context → ``RootRoute/goalSetup``; have
    ///    context but never asked HealthKit → ``RootRoute/healthKitPermission``;
    ///    otherwise → ``RootRoute/dailyInsight``.
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
    /// ``GoalStatus/goalComplete``. Transitions to the HealthKit permission
    /// screen since the user has just finished goal setup and we haven't
    /// asked for HealthKit access yet.
    func goalSetupCompleted() {
        route = .healthKitPermission
    }

    /// Called by ``HealthKitPermissionViewModel`` when the permission sheet
    /// has been shown (regardless of grant/deny outcome — iOS doesn't expose
    /// read state to apps). Records that we've asked and routes to the
    /// daily insight.
    func healthKitPermissionFinished() {
        userDefaults.set(true, forKey: PreferenceKeys.hasAskedForHealthKitAuthorization)
        route = .dailyInsight
    }

    /// Called by ``SettingsViewModel/resetGoal()`` when the user opts to
    /// redo goal setup. Routes back to the goal-setup screen; auth and
    /// HealthKit-asked state stay intact.
    func userRequestedGoalReset() {
        route = .goalSetup
    }

    // MARK: - Internals

    private func decideRoute(hasGoalContext: Bool) -> RootRoute {
        if !hasGoalContext {
            return .goalSetup
        }
        if !userDefaults.bool(forKey: PreferenceKeys.hasAskedForHealthKitAuthorization) {
            return .healthKitPermission
        }
        return .dailyInsight
    }
}

/// Namespace for ``UserDefaults`` keys.
///
/// iOS does not expose HealthKit read-permission state to apps (an app
/// cannot distinguish "no data" from "permission denied"), so we track
/// "have we ever asked" ourselves to gate the permission screen.
enum PreferenceKeys {
    static let hasAskedForHealthKitAuthorization = "hasAskedForHealthKitAuthorization"
}
