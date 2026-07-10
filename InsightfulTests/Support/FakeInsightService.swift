import Foundation
@testable import Insightful

/// Scriptable ``InsightServicing`` for view-model tests.
///
/// Each call is recorded with the arguments the system under test passed,
/// and the next return value is programmed via ``programGenerate(_:)``.
actor FakeInsightService: InsightServicing {
    private var generateResult: Result<Insight, any Error & Sendable> = .failure(FakeError.notProgrammed)
    private(set) var generateCalls: [(date: String, metrics: [String: MetricValue], workouts: [WorkoutSummary], force: Bool)] = []

    func programGenerate(_ result: Result<Insight, any Error & Sendable>) {
        generateResult = result
    }

    func generate(date: String, metrics: [String: MetricValue], workouts: [WorkoutSummary], force: Bool) async throws -> Insight {
        generateCalls.append((date: date, metrics: metrics, workouts: workouts, force: force))
        return try generateResult.get()
    }
}
