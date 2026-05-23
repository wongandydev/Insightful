import Foundation
import Observation

/// Drives the daily insight screen.
///
/// `load()` reads the last 7 days of HealthKit metrics, posts them to
/// `/insight`, and stores the result on ``phase``. The HealthKit payload is
/// kept on ``metricsPayload`` so the view can resolve names in
/// ``Insight/chartsToShow`` back to their per-day values when rendering
/// charts.
///
/// `@MainActor @Observable` because the view binds to ``phase``.
@MainActor
@Observable
final class DailyInsightViewModel {
    /// Top-level state of the screen. The view switches on this.
    enum Phase: Equatable {
        case loading
        case ready(Insight)
        case error(String)
    }

    /// Window over which HealthKit is sampled before `/insight` is called.
    static let trailingDays = 7

    private(set) var phase: Phase
    /// HealthKit metric payload from the most recent ``load()``. Empty
    /// before the first call. The view consults this to map chart names
    /// back to their values.
    private(set) var metricsPayload: [String: MetricValue]

    private let healthKitService: any HealthKitServicing
    private let insightService: any InsightServicing

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.phase = .loading
        self.metricsPayload = [:]
    }

    /// Reads HealthKit for the last ``trailingDays`` days, posts to
    /// `/insight`, and updates ``phase``.
    ///
    /// HealthKit failures are bucketed with `/insight` failures because the
    /// user-facing outcome is the same — the screen cannot proceed. A
    /// HealthKit read that returns an empty dictionary is **not** an error:
    /// the backend treats missing keys as "not synced" and still generates
    /// an insight, so we forward the empty payload as-is.
    func load() async {
        phase = .loading
        do {
            let metrics = try await healthKitService.readDailyMetrics(
                over: Self.trailingDays,
                metrics: HealthKitMetric.allCases
            )
            metricsPayload = metrics
            let insight = try await insightService.generate(
                date: LocalCalendarDate.string(from: Date()),
                metrics: metrics
            )
            phase = .ready(insight)
        } catch {
            phase = .error("We couldn't load today's insight.")
        }
    }
}
