import SwiftUI

/// Top-level router. Routes to a child feature view based on
/// ``RootViewModel/route``. Owns the construction of each child view, so
/// this is the place that knows which services each feature needs — feature
/// views below take only their own dependencies in their inits, never the
/// whole graph.
struct RootView: View {
    private let authService: AuthService
    private let goalService: GoalService
    private let insightService: InsightService
    private let adviceService: AdviceService
    private let healthKitService: HealthKitService
    private let notificationService: NotificationService

    @State private var viewModel: RootViewModel

    init(
        authService: AuthService,
        userService: UserService,
        goalService: GoalService,
        insightService: InsightService,
        adviceService: AdviceService,
        healthKitService: HealthKitService,
        notificationService: NotificationService,
        userDefaults: UserDefaults
    ) {
        self.authService = authService
        self.goalService = goalService
        self.insightService = insightService
        self.adviceService = adviceService
        self.healthKitService = healthKitService
        self.notificationService = notificationService
        _viewModel = State(initialValue: RootViewModel(
            authService: authService,
            userService: userService,
            goalService: goalService,
            userDefaults: userDefaults
        ))
    }

    var body: some View {
        Group {
            switch viewModel.route {
            case .launching:
                LaunchView()
            case .onboarding:
                OnboardingView(
                    onContinue: { viewModel.onboardingFinished() }
                )
            case .goalSetup:
                GoalSetupView(
                    goalService: goalService,
                    onComplete: { context in viewModel.goalSetupCompleted(context: context) },
                    onCancel: viewModel.goalContext != nil
                        ? { viewModel.cancelGoalRefinement() }
                        : nil
                )
            case .goalSummary(let context):
                GoalSummaryView(
                    context: context,
                    onContinue: { viewModel.goalSummaryConfirmed() },
                    onEditGoal: { viewModel.goalSummaryRequestedEdit() }
                )
            case .healthKitPermission:
                HealthKitPermissionView(
                    healthKitService: healthKitService,
                    rationale: viewModel.goalContext?.rationale,
                    onFinished: { viewModel.healthKitPermissionFinished() }
                )
            case .main:
                MainTabView(
                    healthKitService: healthKitService,
                    insightService: insightService,
                    adviceService: adviceService,
                    notificationService: notificationService,
                    authService: authService,
                    goalContext: viewModel.goalContext,
                    onSignedOut: { Task { await viewModel.start() } },
                    onResetGoal: { viewModel.userRequestedGoalReset() },
                    onEditGoal: { viewModel.goalSummaryRequestedEdit() }
                )
            case .error(let appError):
                AppErrorView(
                    error: appError,
                    onRetry: { Task { await viewModel.start() } }
                )
            }
        }
        .task { await viewModel.start() }
    }
}

/// Shown while the cold-start sequence is in flight.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Setting things up…")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
