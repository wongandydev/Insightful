import Foundation
import HealthKit
@testable import Insightful

/// Scriptable ``HealthKitReading`` for `HealthKitServiceTests`.
///
/// Tests program per-metric outcomes (success-with-values, throws) and inspect
/// the recorded call list to verify the service routed each metric to the
/// correct read method.
actor FakeHealthKitReader: HealthKitReading {
    enum Outcome: Sendable {
        case returns([Double])
        case throws_(any Error & Sendable)
    }

    private var quantityOutcomes: [HKQuantityTypeIdentifier: Outcome] = [:]
    private var sleepOutcome: Outcome = .returns([])
    private var runningWorkoutsOutcome: Outcome = .returns([])
    private var authorizationOutcome: AuthorizationOutcome = .succeeds

    private(set) var authorizationRequests: [Set<HKSampleType>] = []
    private(set) var quantityReads: [HKQuantityTypeIdentifier] = []
    private(set) var sleepReadCount = 0
    private(set) var runningWorkoutReadCount = 0

    enum AuthorizationOutcome: Sendable {
        case succeeds
        case throws_(any Error & Sendable)
    }

    // MARK: - Programming

    func programQuantity(_ identifier: HKQuantityTypeIdentifier, _ outcome: Outcome) {
        quantityOutcomes[identifier] = outcome
    }

    func programSleep(_ outcome: Outcome) {
        sleepOutcome = outcome
    }

    func programRunningWorkouts(_ outcome: Outcome) {
        runningWorkoutsOutcome = outcome
    }

    func programAuthorization(_ outcome: AuthorizationOutcome) {
        authorizationOutcome = outcome
    }

    // MARK: - HealthKitReading

    func requestAuthorization(read: Set<HKSampleType>) async throws {
        authorizationRequests.append(read)
        switch authorizationOutcome {
        case .succeeds: return
        case .throws_(let error): throw error
        }
    }

    func readDailyQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        aggregation: HealthKitMetric.Aggregation,
        interval: DateInterval
    ) async throws -> [Double] {
        quantityReads.append(identifier)
        return try unwrap(quantityOutcomes[identifier] ?? .returns([]))
    }

    func readSleepHours(in interval: DateInterval) async throws -> [Double] {
        sleepReadCount += 1
        return try unwrap(sleepOutcome)
    }

    func readRunningWorkoutDistances(in interval: DateInterval) async throws -> [Double] {
        runningWorkoutReadCount += 1
        return try unwrap(runningWorkoutsOutcome)
    }

    private func unwrap(_ outcome: Outcome) throws -> [Double] {
        switch outcome {
        case .returns(let values): return values
        case .throws_(let error): throw error
        }
    }
}

enum FakeReaderError: Error, Equatable {
    case unauthorized
    case transport
}
