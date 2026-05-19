import Foundation
import Testing
import HealthKit
@testable import Insightful

@Suite
struct HealthKitServiceTests {

    // MARK: - requestAuthorization

    @Test
    func requestAuthorizationCallsReaderWithEveryWhitelistedSampleType() async throws {
        // Given
        let reader = FakeHealthKitReader()
        let service = HealthKitService(reader: reader)
        let expected = HealthKitMetric.allCases.reduce(into: Set<HKSampleType>()) { acc, metric in
            acc.formUnion(metric.sampleTypes)
        }

        // When
        try await service.requestAuthorization()

        // Then
        let requested = try #require(await reader.authorizationRequests.first)
        #expect(await reader.authorizationRequests.count == 1)
        #expect(requested == expected)
    }

    @Test
    func requestAuthorizationWhenReaderThrowsPropagates() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programAuthorization(.throws_(FakeReaderError.unauthorized))
        let service = HealthKitService(reader: reader)

        // When
        let error = await capturedError { try await service.requestAuthorization() }

        // Then
        #expect(error == FakeReaderError.unauthorized)
    }

    // MARK: - readDailyMetrics: routing

    @Test
    func readDailyMetricsRoutesQuantityMetricsToReadDailyQuantity() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programQuantity(.restingHeartRate, .returns([54, 56, 53]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(over: 7, metrics: [.restingHeartRate])

        // Then
        #expect(await reader.quantityReads == [.restingHeartRate])
        #expect(result["restingHeartRate"] == .series([54, 56, 53]))
    }

    @Test
    func readDailyMetricsRoutesSleepToReadSleepHours() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programSleep(.returns([7.2, 6.8, 7.5]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(over: 7, metrics: [.sleepHours])

        // Then
        #expect(await reader.sleepReadCount == 1)
        #expect(result["sleepHours"] == .series([7.2, 6.8, 7.5]))
    }

    @Test
    func readDailyMetricsRoutesRunningDistanceToWorkoutsReader() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programRunningWorkouts(.returns([5000, 7000]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(over: 7, metrics: [.distanceRunning])

        // Then
        #expect(await reader.runningWorkoutReadCount == 1)
        #expect(result["distanceRunning"] == .series([5000, 7000]))
    }

    // MARK: - readDailyMetrics: packing

    @Test
    func readDailyMetricsPacksMostRecentMetricsAsScalar() async throws {
        // Given — vo2Max uses the `.mostRecent` aggregation strategy
        let reader = FakeHealthKitReader()
        await reader.programQuantity(.vo2Max, .returns([45.0, 47.0, 48.2]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(over: 7, metrics: [.vo2Max])

        // Then
        #expect(result["vo2Max"] == .scalar(48.2))
    }

    @Test
    func readDailyMetricsOmitsMetricsWithEmptyResults() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programQuantity(.restingHeartRate, .returns([]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(over: 7, metrics: [.restingHeartRate])

        // Then
        #expect(result["restingHeartRate"] == nil)
        #expect(result.isEmpty)
    }

    // MARK: - readDailyMetrics: per-metric failure tolerance

    @Test
    func readDailyMetricsSwallowsPerMetricErrorsAndShipsTheRest() async throws {
        // Given
        let reader = FakeHealthKitReader()
        await reader.programQuantity(.restingHeartRate, .throws_(FakeReaderError.transport))
        await reader.programQuantity(.heartRateVariabilitySDNN, .returns([52, 48, 61]))
        let service = HealthKitService(reader: reader)

        // When
        let result = try await service.readDailyMetrics(
            over: 7,
            metrics: [.restingHeartRate, .heartRateVariabilitySDNN]
        )

        // Then
        #expect(result["restingHeartRate"] == nil)
        #expect(result["heartRateVariabilitySDNN"] == .series([52, 48, 61]))
    }

    // MARK: - Helpers

    private func capturedError(_ block: () async throws -> Void) async -> FakeReaderError? {
        do {
            try await block()
            return nil
        } catch let error as FakeReaderError {
            return error
        } catch {
            return nil
        }
    }
}
