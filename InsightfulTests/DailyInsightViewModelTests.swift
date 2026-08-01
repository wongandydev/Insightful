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
    func loadWhenWorkoutsPresentPassesThemToService() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let session = WorkoutSummary(
            activityType: "running",
            date: "2026-07-09",
            durationMinutes: 45,
            distanceKm: 8.2,
            energyKcal: nil,
            averageHeartRate: nil
        )
        await healthKit.programReadWorkouts(.success([session]))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        let calls = await insightService.generateCalls
        #expect(calls.first?.workouts == [session])
    }

    @Test
    func loadWhenWorkoutReadThrowsStillGeneratesWithEmptyWorkouts() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        await healthKit.programReadWorkouts(.failure(FakeError.network))
        let insightService = FakeInsightService()
        await insightService.programGenerate(.success(makeInsight()))
        let viewModel = makeViewModel(healthKit: healthKit, insightService: insightService)

        // When
        await viewModel.load()

        // Then
        let calls = await insightService.generateCalls
        #expect(calls.count == 1)
        #expect(calls.first?.workouts.isEmpty == true)
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
        insightService: any InsightServicing
    ) -> DailyInsightViewModel {
        DailyInsightViewModel(healthKitService: healthKit, insightService: insightService)
    }

    private func makeInsight(text: String = "default text") -> Insight {
        Insight(
            insightText: text,
            alerts: [],
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
