import SwiftUI

/// Steady-state container shown once auth, goal setup, and the HealthKit
/// prompt are behind the user. Hosts three tabs:
///
/// 1. ``HomeView`` — the default tab; launches the daily insight as a sheet
///    and hosts the gear that opens Settings.
/// 2. A Coach tab — the free-form ``CoachChatView`` conversation.
/// 3. A Goal tab — read-only ``GoalSummaryView`` whose edit button bubbles
///    up to ``RootViewModel/goalSummaryRequestedEdit()`` so refinement
///    flows through the existing top-level route.
/// 4. A History placeholder — stub until the backend exposes a past-insight
///    list.
struct MainTabView: View {
    private let healthKitService: any HealthKitServicing
    private let insightService: any InsightServicing
    private let adviceService: any AdviceServicing
    private let authService: AuthService
    private let goalContext: GoalContext?
    private let onSignedOut: () -> Void
    private let onResetGoal: () -> Void
    private let onEditGoal: () -> Void

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing,
        adviceService: any AdviceServicing,
        authService: AuthService,
        goalContext: GoalContext?,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void,
        onEditGoal: @escaping () -> Void
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.adviceService = adviceService
        self.authService = authService
        self.goalContext = goalContext
        self.onSignedOut = onSignedOut
        self.onResetGoal = onResetGoal
        self.onEditGoal = onEditGoal
    }

    var body: some View {
        TabView {
            HomeView(
                healthKitService: healthKitService,
                insightService: insightService,
                authService: authService,
                goalContext: goalContext,
                onSignedOut: onSignedOut,
                onResetGoal: onResetGoal
            )
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                CoachChatView(
                    adviceService: adviceService,
                    healthKitService: healthKitService
                )
            }
            .tabItem {
                Label("Coach", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                if let goalContext {
                    GoalSummaryView(
                        context: goalContext,
                        onContinue: nil,
                        onEditGoal: onEditGoal
                    )
                    .navigationTitle("Your goal")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    MissingGoalState()
                        .navigationTitle("Your goal")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .tabItem {
                Label("Goal", systemImage: "target")
            }

            NavigationStack {
                HistoryPlaceholderView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

private struct MissingGoalState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No goal saved yet.")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Past insights")
                .font(.headline)
            Text("Coming soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
