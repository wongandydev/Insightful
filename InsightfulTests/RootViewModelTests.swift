import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct RootViewModelTests {

    // MARK: - Cold start: routing by goal context + HealthKit-asked state

    @Test
    func startWhenNoCachedGoalContextRoutesToGoalSetup() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.success(GoalContextResponse(hasContext: false, context: nil)))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .goalSetup)
    }

    @Test
    func startWhenContextExistsButHealthKitNotYetAskedRoutesToPermission() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.success(populatedGoalContextResponse))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .healthKitPermission)
    }

    @Test
    func startWhenContextExistsAndHealthKitAlreadyAskedRoutesToDailyInsight() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.success(populatedGoalContextResponse))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: true)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .dailyInsight)
    }

    // MARK: - Cold start failures

    @Test
    func startWhenUserSyncFailsRoutesToError() async throws {
        // Given
        let userService = FakeUserService()
        await userService.program(.failure(FakeError.network))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            userService: userService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(genericErrorMessage))
    }

    @Test
    func startWhenGetContextFailsRoutesToError() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.failure(FakeError.network))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(genericErrorMessage))
    }

    // MARK: - Child-feature transitions

    @Test
    func goalSetupCompletedRoutesToHealthKitPermission() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.goalSetupCompleted()

        // Then
        #expect(viewModel.route == .healthKitPermission)
    }

    @Test
    func healthKitPermissionFinishedRoutesToDailyInsightAndPersistsAskedFlag() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.healthKitPermissionFinished()

        // Then
        #expect(viewModel.route == .dailyInsight)
        #expect(defaults.bool(forKey: PreferenceKeys.hasAskedForHealthKitAuthorization))
    }

    // MARK: - Helpers

    /// Matches the literal in ``RootViewModel/start()`` for the error route.
    private let genericErrorMessage = "We couldn't reach the server. Try again."

    private var populatedGoalContextResponse: GoalContextResponse {
        GoalContextResponse(
            hasContext: true,
            context: GoalContext(
                goalType: .enduranceEvent,
                goalSummary: "Ironman 70.3",
                targetDate: nil,
                motivation: "first race",
                currentState: "training 6h/wk",
                biggestConcern: "swim",
                lifestyle: "office job",
                previouslyTried: nil,
                injuriesOrLimitations: nil,
                priorityMetrics: ["vo2Max", "restingHeartRate", "heartRateVariabilitySDNN", "sleepHours", "activeEnergyBurned"],
                sportsOrActivities: ["running", "cycling", "swimming"],
                subGoals: []
            )
        )
    }

    /// Builds a `RootViewModel` with sensible defaults for happy-path tests.
    /// Tests that need a specific failure pre-program their fake and pass it in.
    private func makeViewModel(
        userService: any UserServicing = FakeUserService(),
        goalService: any GoalServicing = FakeGoalService(),
        userDefaults: UserDefaults
    ) async -> RootViewModel {
        let session = AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(session))

        return RootViewModel(
            authService: AuthService(backend: backend),
            userService: userService,
            goalService: goalService,
            userDefaults: userDefaults
        )
    }

    private func makeTestUserDefaults(hasAskedForHealthKit: Bool) -> UserDefaults {
        let suiteName = "RootViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(hasAskedForHealthKit, forKey: PreferenceKeys.hasAskedForHealthKitAuthorization)
        return defaults
    }
}
