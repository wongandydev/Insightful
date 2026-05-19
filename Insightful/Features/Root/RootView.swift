import SwiftUI

/// Top-level router. Routes to a child feature view based on
/// ``RootViewModel/route``. Owns the construction of each child view, so
/// this is the place that knows which services each feature needs — feature
/// views below take only their own dependencies in their inits, never the
/// whole graph.
struct RootView: View {
    private let goalService: GoalService
    private let insightService: InsightService
    private let healthKitService: HealthKitService

    @State private var viewModel: RootViewModel

    init(
        authService: AuthService,
        userService: UserService,
        goalService: GoalService,
        insightService: InsightService,
        healthKitService: HealthKitService,
        userDefaults: UserDefaults
    ) {
        self.goalService = goalService
        self.insightService = insightService
        self.healthKitService = healthKitService
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
            case .goalSetup:
                GoalSetupView(onComplete: { viewModel.goalSetupCompleted() })
            case .healthKitPermission:
                HealthKitPermissionView(onFinished: { viewModel.healthKitPermissionFinished() })
            case .dailyInsight:
                DailyInsightView()
            case .error(let message):
                AppErrorView(
                    message: message,
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
