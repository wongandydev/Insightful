import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct DailyInsightViewModelTests {

    @Test
    func loadWhenSucceedsSurfacesInsight() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0, 6.2])]))
        let insightService = FakeInsightService()
        let expected = makeInsight(text: "Your sleep is trending up.")
        await insightService.programGenerate(.success(expected))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        #expect(viewModel.phase == .ready(expected))
    }

    @Test
    func loadWhenHealthKitReturnsEmptyShortCircuitsToNoHealthData() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success([:]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        let calls = await insightService.generateCalls
        #expect(viewModel.phase == .noHealthData)
        #expect(calls.isEmpty)
    }

    @Test
    func loadWhenDefaultDoesNotForceRegeneration() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        let calls = await insightService.generateCalls
        #expect(calls.first?.force == false)
    }

    @Test
    func loadWhenForcedPassesForceToService() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load(force: true)

        // Then
        let calls = await insightService.generateCalls
        #expect(calls.first?.force == true)
    }

    @Test
    func loadWhenInsightHasAlertsSchedulesFollowUpWithFirstAlert() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([5.1, 5.4])]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight(alerts: ["Two short nights in a row", "HRV down 15%"])))
        let notifications = FakeNotificationService()
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService, notifications: notifications)

        // When
        await viewModel.load()

        // Then
        let followUps = await notifications.alertFollowUps
        #expect(followUps == ["Two short nights in a row"])
    }

    @Test
    func loadWhenInsightHasNoAlertsSchedulesNothing() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let notifications = FakeNotificationService()
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService, notifications: notifications)

        // When
        await viewModel.load()

        // Then
        let followUps = await notifications.alertFollowUps
        #expect(followUps.isEmpty)
    }

    @Test
    func loadWhenInsightServiceThrowsSetsErrorPhase() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.failure(FakeError.network))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        #expect(isErrorPhase(viewModel.phase))
    }

    // MARK: - Helpers

    private func makeViewModel(
        healthKit: any HealthKitServicing,
        insightService: any InsightServicing,
        notifications: any NotificationScheduling = FakeNotificationService()
    ) -> DailyInsightViewModel {
        DailyInsightViewModel(
            healthKitService: healthKit,
            insightService: insightService,
            notificationService: notifications
        )
    }

    private func makeInsight(text: String = "default text", alerts: [String] = []) -> Insight {
        Insight(
            insightText: text,
            alerts: alerts,
            chartsToShow: [],
            chartMetadata: [:],
            recommendedActions: [],
            progress: nil,
            generatedAt: nil
        )
    }

    private func isErrorPhase(_ phase: DailyInsightViewModel.Phase) -> Bool {
        if case .error = phase { return true }
        return false
    }
}
