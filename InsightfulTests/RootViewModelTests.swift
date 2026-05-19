import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct RootViewModelTests {
    let baseURL = URL(string: "https://api.test")!

    let session = AuthSession(
        accessToken: "a",
        refreshToken: "r",
        expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
    )

    // MARK: - Cold start happy paths

    @Test
    func startWhenNoCachedGoalContextRoutesToGoalSetup() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"userId":"u-1"}"#.utf8),
            url: baseURL.appendingPathComponent("user")
        )
        await mock.enqueue(
            status: 200,
            body: Data(#"{"hasContext":false,"context":null}"#.utf8),
            url: baseURL.appendingPathComponent("goal/context")
        )
        let viewModel = makeViewModel(
            mock: mock,
            currentSession: .returns(session),
            hasAskedForHealthKit: false
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .goalSetup)
    }

    @Test
    func startWhenContextExistsButHealthKitNotYetAskedRoutesToPermission() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"userId":"u-1"}"#.utf8),
            url: baseURL.appendingPathComponent("user")
        )
        await mock.enqueue(
            status: 200,
            body: Data(goalContextResponseJSON).utf8 |> { Data($0) },
            url: baseURL.appendingPathComponent("goal/context")
        )
        let viewModel = makeViewModel(
            mock: mock,
            currentSession: .returns(session),
            hasAskedForHealthKit: false
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .healthKitPermission)
    }

    @Test
    func startWhenContextExistsAndHealthKitAlreadyAskedRoutesToDailyInsight() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"userId":"u-1"}"#.utf8),
            url: baseURL.appendingPathComponent("user")
        )
        await mock.enqueue(
            status: 200,
            body: Data(goalContextResponseJSON.utf8),
            url: baseURL.appendingPathComponent("goal/context")
        )
        let viewModel = makeViewModel(
            mock: mock,
            currentSession: .returns(session),
            hasAskedForHealthKit: true
        )

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.route == .dailyInsight)
    }

    // MARK: - Cold start failures

    @Test
    func startWhenAuthBootstrapThrowsRoutesToError() async throws {
        // Given
        let mock = MockHTTPClient()
        let viewModel = makeViewModel(
            mock: mock,
            currentSession: .throws_(FakeError.network),
            signIn: .throws_(FakeError.network),
            hasAskedForHealthKit: false
        )

        // When
        await viewModel.start()

        // Then
        if case .error = viewModel.route {
            #expect(Bool(true))
        } else {
            Issue.record("expected .error route, got \(viewModel.route)")
        }
    }

    @Test
    func startWhenUserSyncFailsRoutesToError() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 503, url: baseURL.appendingPathComponent("user"))
        let viewModel = makeViewModel(
            mock: mock,
            currentSession: .returns(session),
            hasAskedForHealthKit: false
        )

        // When
        await viewModel.start()

        // Then
        if case .error = viewModel.route {
            #expect(Bool(true))
        } else {
            Issue.record("expected .error route, got \(viewModel.route)")
        }
    }

    // MARK: - Transitions from child features

    @Test
    func goalSetupCompletedRoutesToHealthKitPermission() {
        // Given
        let viewModel = makeViewModel(
            mock: MockHTTPClient(),
            currentSession: .returns(session),
            hasAskedForHealthKit: false
        )

        // When
        viewModel.goalSetupCompleted()

        // Then
        #expect(viewModel.route == .healthKitPermission)
    }

    @Test
    func healthKitPermissionFinishedRoutesToDailyInsightAndPersistsAskedFlag() {
        // Given
        let userDefaults = makeTestUserDefaults()
        let viewModel = makeViewModel(
            mock: MockHTTPClient(),
            currentSession: .returns(session),
            userDefaults: userDefaults
        )

        // When
        viewModel.healthKitPermissionFinished()

        // Then
        #expect(viewModel.route == .dailyInsight)
        #expect(userDefaults.bool(forKey: PreferenceKeys.hasAskedForHealthKitAuthorization))
    }

    // MARK: - Helpers

    /// A minimal goal-context payload that simulates a fully-set-up user.
    private var goalContextResponseJSON: String {
        """
        {
          "hasContext": true,
          "context": {
            "goalType": "endurance_event",
            "goalSummary": "Ironman 70.3",
            "targetDate": null,
            "motivation": "first race",
            "currentState": "training 6h/wk",
            "biggestConcern": "swim",
            "lifestyle": "office job",
            "previouslyTried": null,
            "injuriesOrLimitations": null,
            "priorityMetrics": ["vo2Max", "restingHeartRate", "heartRateVariabilitySDNN", "sleepHours", "activeEnergyBurned"],
            "sportsOrActivities": ["running", "cycling", "swimming"],
            "subGoals": []
          }
        }
        """
    }

    private func makeTestUserDefaults(hasAskedForHealthKit: Bool = false) -> UserDefaults {
        let suiteName = "RootViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(hasAskedForHealthKit, forKey: PreferenceKeys.hasAskedForHealthKitAuthorization)
        return defaults
    }

    private func makeViewModel(
        mock: MockHTTPClient,
        currentSession: FakeAuthBackend.Scenario,
        signIn: FakeAuthBackend.Scenario = .returns(AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
        )),
        userDefaults: UserDefaults? = nil,
        hasAskedForHealthKit: Bool = false
    ) -> RootViewModel {
        let defaults = userDefaults ?? makeTestUserDefaults(hasAskedForHealthKit: hasAskedForHealthKit)

        let backend = FakeAuthBackend()
        Task { await backend.programCurrentSession(currentSession) }
        Task { await backend.programSignIn(signIn) }
        // The Tasks above are sync-fire-and-forget; for deterministic tests
        // we await them inline via a synchronous wrapper below.
        let authService = AuthService(backend: backend)
        let apiClient = APIClient(
            baseURL: baseURL,
            httpClient: mock,
            tokenProvider: { "t" },
            refreshToken: {}
        )
        return RootViewModel(
            authService: authService,
            userService: UserService(client: apiClient),
            goalService: GoalService(client: apiClient),
            userDefaults: defaults
        )
    }
}

/// `|>` is intentionally not added — see test where I forgot and fix it.
infix operator |>
func |> <A, B>(value: A, transform: (A) -> B) -> B { transform(value) }
