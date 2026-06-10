import SwiftUI

/// The Home tab — a light always-on landing surface that launches the daily
/// insight as a sheet and hosts the gear that opens Settings.
///
/// v1 is a launcher with placeholder copy; the chart, "today's insight" tile,
/// and progress-to-goal callout described in the Home entry in `TODO.md`
/// land in Phase 2.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    private let healthKitService: any HealthKitServicing
    private let insightService: any InsightServicing
    private let authService: AuthService
    private let goalContext: GoalContext?
    private let onSignedOut: () -> Void
    private let onResetGoal: () -> Void

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing,
        authService: AuthService,
        goalContext: GoalContext?,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.authService = authService
        self.goalContext = goalContext
        self.onSignedOut = onSignedOut
        self.onResetGoal = onResetGoal
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 32) {
                placeholder
                Button {
                    viewModel.isShowingInsight = true
                } label: {
                    Text("View today's insight")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 40)
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
                    insightService: insightService
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.isShowingSettings) {
                SettingsView(
                    authService: authService,
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
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "house")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Welcome back.")
                .font(.title2.weight(.semibold))
            Text("Your daily insight is ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
}
