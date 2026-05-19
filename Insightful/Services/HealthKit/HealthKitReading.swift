import Foundation
import HealthKit

/// The narrow HealthKit surface `HealthKitService` depends on.
///
/// Production is `HealthKitStoreReader` (wraps `HKHealthStore`); tests use an
/// `actor FakeHealthKitReader`. Same `rules.md` exception we already use for
/// `HTTPClient` and `AuthBackend` — Apple's `HKHealthStore` isn't unit-testable
/// in the simulator without granting permissions interactively, so we swap.
protocol HealthKitReading: Sendable {
    /// Triggers the system permission sheet for the supplied read types.
    /// `share` is empty in our case — we only read.
    func requestAuthorization(read: Set<HKSampleType>) async throws

    /// Reads a quantity-typed metric, bucketed into daily values over the
    /// given interval, aggregated by the supplied strategy. Returns one
    /// `Double` per calendar day (oldest → newest), with missing days dropped.
    func readDailyQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        aggregation: HealthKitMetric.Aggregation,
        interval: DateInterval
    ) async throws -> [Double]

    /// Reads total asleep hours per night across the interval. One value per
    /// night, oldest → newest. Missing nights are dropped.
    func readSleepHours(in interval: DateInterval) async throws -> [Double]

    /// Sums `totalDistance` (in meters) for running workouts that occurred on
    /// each calendar day. One value per day, oldest → newest. Missing days dropped.
    func readRunningWorkoutDistances(in interval: DateInterval) async throws -> [Double]
}
