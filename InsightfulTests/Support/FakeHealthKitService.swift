import Foundation
@testable import Insightful

/// Scriptable ``HealthKitServicing`` for view-model tests.
///
/// Each operation can be programmed independently. Recorded calls expose
/// the arguments the system under test passed.
actor FakeHealthKitService: HealthKitServicing {
    private var requestAuthorizationResult: Result<Void, any Error & Sendable> = .success(())
    private var readDailyMetricsResult: Result<[String: MetricValue], any Error & Sendable> = .success([:])

    private(set) var requestAuthorizationCalls = 0
    private(set) var readDailyMetricsCalls: [(days: Int, metrics: [HealthKitMetric])] = []

    func programRequestAuthorization(_ result: Result<Void, any Error & Sendable>) {
        requestAuthorizationResult = result
    }

    func programReadDailyMetrics(_ result: Result<[String: MetricValue], any Error & Sendable>) {
        readDailyMetricsResult = result
    }

    func requestAuthorization() async throws {
        requestAuthorizationCalls += 1
        try requestAuthorizationResult.get()
    }

    func readDailyMetrics(over days: Int, metrics: [HealthKitMetric]) async throws -> [String: MetricValue] {
        readDailyMetricsCalls.append((days: days, metrics: metrics))
        return try readDailyMetricsResult.get()
    }
}
