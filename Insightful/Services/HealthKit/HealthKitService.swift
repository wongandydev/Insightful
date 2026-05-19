import Foundation
import HealthKit

/// Reads HealthKit and produces a `[String: MetricValue]` ready for
/// ``InsightService/generate(date:metrics:)``.
///
/// The service is an `actor` because the underlying ``HKHealthStore`` calls
/// are inherently I/O-bound. Reads are issued through a ``HealthKitReading``
/// so this type stays unit-testable against an in-memory fake — production
/// wires in ``HealthKitStoreReader``.
actor HealthKitService {
    private let reader: HealthKitReading

    init(reader: HealthKitReading) {
        self.reader = reader
    }

    /// Triggers the iOS permission sheet covering every metric in
    /// ``HealthKitMetric/allCases``.
    ///
    /// Safe to call repeatedly. After the user makes their initial decision
    /// iOS no-ops further requests for the same types, so there's no need
    /// for the caller to guard against re-invocation.
    ///
    /// - Throws: Any error surfaced by ``HKHealthStore`` (typically
    ///   `HKError.errorAuthorizationDenied` or transport failures).
    func requestAuthorization() async throws {
        let types: Set<HKSampleType> = HealthKitMetric.allCases.reduce(into: []) { acc, metric in
            acc.formUnion(metric.sampleTypes)
        }
        try await reader.requestAuthorization(read: types)
    }

    /// Reads the requested metrics for a trailing window of days.
    ///
    /// Each metric is dispatched to the right ``HealthKitReading`` method
    /// based on its ``HealthKitMetric/kind``. The result dictionary is keyed
    /// by ``HealthKitMetric/rawValue``, which matches the backend's
    /// whitelist. Per-metric failures are swallowed so one flaky read does
    /// not deny the user their daily insight — the backend treats absent
    /// keys as "not synced", not as an error.
    ///
    /// - Parameters:
    ///   - days: Size of the trailing window in calendar days, anchored to
    ///     the user's local midnight. `7` produces "last 7 days including
    ///     today".
    ///   - metrics: Which metrics to read. Typically
    ///     `HealthKitMetric.allCases`.
    /// - Returns: A dictionary of metric name → ``MetricValue``. Metrics
    ///   with no samples in the range are omitted.
    func readDailyMetrics(
        over days: Int,
        metrics: [HealthKitMetric]
    ) async throws -> [String: MetricValue] {
        let interval = trailingInterval(days: days)
        var result: [String: MetricValue] = [:]

        for metric in metrics {
            let values: [Double]
            do {
                values = try await read(metric: metric, in: interval)
            } catch {
                continue
            }
            guard let metricValue = pack(values, for: metric) else { continue }
            result[metric.rawValue] = metricValue
        }
        return result
    }

    // MARK: - Internals

    /// Routes one ``HealthKitMetric`` to the appropriate ``HealthKitReading``
    /// method based on its ``HealthKitMetric/Kind``.
    ///
    /// - Parameters:
    ///   - metric: The metric to read.
    ///   - interval: The window to read over.
    /// - Returns: Per-day readings, oldest → newest. Missing days are dropped.
    /// - Throws: Anything ``HealthKitReading`` surfaces.
    private func read(metric: HealthKitMetric, in interval: DateInterval) async throws -> [Double] {
        switch metric.kind {
        case let .quantity(identifier, unit, aggregation):
            return try await reader.readDailyQuantity(
                identifier: identifier,
                unit: unit,
                aggregation: aggregation,
                interval: interval
            )
        case .sleepDuration:
            return try await reader.readSleepHours(in: interval)
        case .runningDistanceFromWorkouts:
            return try await reader.readRunningWorkoutDistances(in: interval)
        }
    }

    /// Wraps daily readings in the right ``MetricValue`` shape for the
    /// backend.
    ///
    /// Metrics whose ``HealthKitMetric/kind`` is
    /// ``HealthKitMetric/Kind/quantity(_:_:_:)`` with the
    /// ``HealthKitMetric/Aggregation/mostRecent`` strategy (e.g. body mass,
    /// VO2 max — measured infrequently) collapse to a single scalar: the
    /// latest reading in the window. All other metrics ship as a daily
    /// ``MetricValue/series(_:)``.
    ///
    /// - Parameters:
    ///   - values: Per-day readings produced by ``read(metric:in:)``,
    ///     oldest → newest.
    ///   - metric: The metric being packed; consulted to decide scalar vs
    ///     series.
    /// - Returns: A ``MetricValue`` ready for the request body, or `nil`
    ///   when `values` is empty (so the key is omitted from the dictionary).
    private func pack(_ values: [Double], for metric: HealthKitMetric) -> MetricValue? {
        guard !values.isEmpty else { return nil }
        if case .quantity(_, _, .mostRecent) = metric.kind, let latest = values.last {
            return .scalar(latest)
        }
        return .series(values)
    }

    /// Builds the trailing-window interval used for daily reads.
    ///
    /// The window ends at the start of *tomorrow* (so today's partial-day
    /// samples are included) and begins `days` calendar days earlier,
    /// anchored to local midnight. Local calendar is intentional — the
    /// contract states all dates are user-local (`IOS_CONTRACT.md` § 2).
    ///
    /// - Parameter days: Window length in calendar days.
    /// - Returns: A ``DateInterval`` covering `[start, end-of-today)`.
    private func trailingInterval(days: Int) -> DateInterval {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let start = calendar.date(byAdding: .day, value: -days, to: endOfToday)!
        return DateInterval(start: start, end: endOfToday)
    }
}
