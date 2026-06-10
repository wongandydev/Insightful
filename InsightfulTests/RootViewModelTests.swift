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
    func startWhenContextExistsButHealthKitNotYetAskedRoutesToPermissionAndStoresContext() async throws {
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
        #expect(viewModel.goalContext == populatedGoalContextResponse.context)
    }

    @Test
    func startWhenNoCachedGoalContextLeavesGoalContextNil() async throws {
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
        #expect(viewModel.goalContext == nil)
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
        #expect(viewModel.route == .main)
    }

    // MARK: - Cold start failures

    @Test
    func startWhenUserSyncFailsWithUntypedErrorRoutesToUnknown() async throws {
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
        #expect(viewModel.route == .error(.unknown))
    }

    @Test
    func startWhenTransportFailsRoutesToOffline() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.failure(APIError.transport("no network")))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(.offline))
    }

    @Test
    func startWhenServerFailsRoutesToServer() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.failure(APIError.server(status: 503, requestId: nil)))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(.server))
    }

    @Test
    func startWhenRateLimitedRoutesToRateLimited() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.failure(APIError.rateLimited(retryAfterSeconds: 10, requestId: nil)))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(.rateLimited))
    }

    @Test
    func startWhenDecodingFailsRoutesToDecoding() async throws {
        // Given
        let goalService = FakeGoalService()
        await goalService.programGetContext(.failure(APIError.decoding("bad json", requestId: nil)))
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(
            goalService: goalService,
            userDefaults: defaults
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .error(.decoding))
    }

    // MARK: - Child-feature transitions

    @Test
    func goalSetupCompletedRoutesToGoalSummaryAndStoresContext() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)
        let context = populatedGoalContextResponse.context!

        // When
        viewModel.goalSetupCompleted(context: context)

        // Then
        #expect(viewModel.route == .goalSummary(context))
        #expect(viewModel.goalContext == context)
    }

    @Test
    func goalSummaryConfirmedWhenHealthKitNotYetAskedRoutesToPermission() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.goalSummaryConfirmed()

        // Then
        #expect(viewModel.route == .healthKitPermission)
    }

    @Test
    func goalSummaryConfirmedWhenHealthKitAlreadyAskedRoutesToDailyInsight() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: true)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.goalSummaryConfirmed()

        // Then
        #expect(viewModel.route == .main)
    }

    @Test
    func goalSummaryRequestedEditPreservesContextAndRoutesToGoalSetup() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)
        let context = populatedGoalContextResponse.context!
        viewModel.goalSetupCompleted(context: context)

        // When
        viewModel.goalSummaryRequestedEdit()

        // Then
        #expect(viewModel.route == .goalSetup)
        #expect(viewModel.goalContext == context)
    }

    @Test
    func cancelGoalRefinementWhenContextCachedRoutesBackToSteadyState() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: true)
        let viewModel = await makeViewModel(userDefaults: defaults)
        viewModel.goalSetupCompleted(context: populatedGoalContextResponse.context!)

        // When
        viewModel.cancelGoalRefinement()

        // Then
        #expect(viewModel.route == .main)
        #expect(viewModel.goalContext != nil)
    }

    @Test
    func userRequestedGoalResetRoutesToGoalSetup() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: true)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.userRequestedGoalReset()

        // Then
        #expect(viewModel.route == .goalSetup)
    }

    @Test
    func healthKitPermissionFinishedRoutesToDailyInsightAndPersistsAskedFlag() async {
        // Given
        let defaults = makeTestUserDefaults(hasAskedForHealthKit: false)
        let viewModel = await makeViewModel(userDefaults: defaults)

        // When
        viewModel.healthKitPermissionFinished()

        // Then
        #expect(viewModel.route == .main)
        #expect(defaults.bool(forKey: PreferenceKeys.hasAskedForHealthKitAuthorization))
    }

    // MARK: - Helpers

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
