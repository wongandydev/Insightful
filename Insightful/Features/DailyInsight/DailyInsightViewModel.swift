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
        /// HealthKit returned no metrics for the trailing window — either the
        /// user denied access or has no recorded data on device.
        case noHealthData
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
    private let notificationService: any NotificationScheduling

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing,
        notificationService: any NotificationScheduling
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.notificationService = notificationService
        self.phase = .loading
        self.metricsPayload = [:]
    }

    /// Reads HealthKit for the last ``trailingDays`` days, posts to
    /// `/insight`, and updates ``phase``.
    ///
    /// HealthKit failures are bucketed with `/insight` failures because the
    /// user-facing outcome is the same — the screen cannot proceed. An
    /// empty HealthKit read short-circuits to ``Phase/noHealthData`` so the
    /// view can prompt the user to grant access; `/insight` is not called.
    ///
    /// - Parameter force: When `true`, the server regenerates instead of
    ///   serving the day's cached insight. Driven by the refresh control —
    ///   screen-open loads pass `false` so the cache keeps repeat opens cheap.
    func load(force: Bool = false) async {
        phase = .loading
        do {
            let metrics = try await healthKitService.readDailyMetrics(
                over: Self.trailingDays,
                metrics: HealthKitMetric.allCases
            )
            if metrics.isEmpty {
                phase = .noHealthData
                return
            }
            metricsPayload = metrics
            let insight = try await insightService.generate(
                date: LocalCalendarDate.string(from: Date()),
                metrics: metrics,
                force: force
            )
            phase = .ready(insight)
            if let firstAlert = insight.alerts.first {
                await notificationService.scheduleAlertFollowUp(firstAlert: firstAlert)
            }
        } catch {
            phase = .error("We couldn't load today's insight.")
        }
    }
}
