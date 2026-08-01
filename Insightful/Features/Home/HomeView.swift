import SwiftUI
import UIKit

/// The Home tab — landing surface for the always-on user.
///
/// Surfaces today's insight as a tappable tile above 30-day charts of the
/// goal's priority metrics; the gear in the nav bar opens Settings, and
/// tapping the tile pushes the existing ``DailyInsightView`` as a sheet.
struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel: HomeViewModel
    private let healthKitService: any HealthKitServicing
    private let insightService: any InsightServicing
    private let notificationService: any NotificationScheduling
    private let authService: AuthService
    private let goalContext: GoalContext?
    private let onSignedOut: () -> Void
    private let onResetGoal: () -> Void

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing,
        notificationService: any NotificationScheduling,
        authService: AuthService,
        goalContext: GoalContext?,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.notificationService = notificationService
        self.authService = authService
        self.goalContext = goalContext
        self.onSignedOut = onSignedOut
        self.onResetGoal = onResetGoal
        _viewModel = State(initialValue: HomeViewModel(
            healthKitService: healthKitService,
            insightService: insightService,
            notificationService: notificationService
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .sheet(isPresented: $viewModel.isShowingInsight) {
                    DailyInsightView(
                        healthKitService: healthKitService,
                        insightService: insightService,
                        notificationService: notificationService
                    )
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $viewModel.isShowingSettings) {
                    SettingsView(
                        authService: authService,
                        notificationService: notificationService,
                        goalContext: goalContext,
                        onSignedOut: {
                            viewModel.isShowingSettings = false
                            onSignedOut()
                        },
                        onResetGoal: {
                            viewModel.isShowingSettings = false
                            onResetGoal()
                        }
                    )
                }
        }
        .task { await viewModel.load(goalContext: goalContext) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            LoadingState()
        case .ready(let data):
            ReadyContent(
                data: data,
                hasGoal: goalContext != nil,
                onOpenInsight: { viewModel.isShowingInsight = true },
                onSetUpGoal: onResetGoal,
                onGrantAccess: { Task { await viewModel.grantAccess(goalContext: goalContext) } },
                onOpenSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            )
        case .error(let message):
            ErrorState(message: message) {
                Task { await viewModel.load(goalContext: goalContext) }
            }
        }
    }
}

private struct LoadingState: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your home…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message).multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReadyContent: View {
    let data: HomeData
    let hasGoal: Bool
    let onOpenInsight: () -> Void
    let onSetUpGoal: () -> Void
    let onGrantAccess: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let progress = data.insight.progress {
                    ProgressCallout(progress: progress)
                }
                InsightTile(insight: data.insight, onTap: onOpenInsight)
                if hasGoal {
                    if data.charts.isEmpty {
                        if data.needsAuthorizationPrompt {
                            GrantAccessCallout(onGrantAccess: onGrantAccess)
                        } else {
                            EmptyChartsCallout(onOpenSettings: onOpenSettings)
                        }
                    } else {
                        chartSection
                    }
                } else {
                    NoGoalCallout(onSetUpGoal: onSetUpGoal)
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(data.charts, id: \.metricName) { series in
                InsightChart(
                    metricName: series.metricName,
                    values: series.values,
                    metadata: data.insight.chartMetadata[series.metricName]
                )
            }
        }
    }
}

private struct GrantAccessCallout: View {
    let onGrantAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(Color.accentColor)
                Text("Connect Apple Health")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Grant access to chart 30-day trends for your priority metrics here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onGrantAccess) {
                Text("Connect Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct EmptyChartsCallout: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.accentColor)
                Text("No trends to show yet")
                    .font(.subheadline.weight(.semibold))
            }
            Text("We don't have enough Apple Health history for your priority metrics. Check HealthKit access, or come back once a few days of data have recorded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onOpenSettings) {
                Text("Check Apple Health access")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct NoGoalCallout: View {
    let onSetUpGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundStyle(Color.accentColor)
                Text("Set a goal to see your trends")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Once you've set a goal, we'll chart the metrics that matter most for it right here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onSetUpGoal) {
                Text("Set up your goal")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct InsightTile: View {
    let insight: Insight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's insight")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(insight.insightText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens today's full insight")
    }
}
