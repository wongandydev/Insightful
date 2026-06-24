import Foundation
import Observation

/// Drives the Home tab.
///
/// On ``load(goalContext:)`` the VM reads a 30-day window from HealthKit for
/// every entry in ``GoalContext/priorityMetrics`` that maps to a known
/// ``HealthKitMetric``, and in parallel fetches today's ``Insight`` via the
/// usual `/insight` route. The backend caches per `(userId, date)` so the same
/// insight is served cheaply if the user then taps into ``DailyInsightView``.
@MainActor
@Observable
final class HomeViewModel {
    /// Top-level state of the Home tab. The view switches on this.
    enum Phase: Equatable {
        case loading
        case ready(HomeData)
        case error(String)
    }

    /// Window over which HealthKit is sampled for the priority-metric charts.
    static let chartTrailingDays = 30
    /// Window matching ``DailyInsightViewModel/trailingDays`` so the insight
    /// generated for Home is the same one the sheet would generate.
    static let insightTrailingDays = 7

    private(set) var phase: Phase
    /// Whether the daily-insight sheet is currently presented.
    var isShowingInsight: Bool
    /// Whether the Settings sheet is currently presented.
    var isShowingSettings: Bool

    private let healthKitService: any HealthKitServicing
    private let insightService: any InsightServicing

    init(
        healthKitService: any HealthKitServicing,
        insightService: any InsightServicing
    ) {
        self.healthKitService = healthKitService
        self.insightService = insightService
        self.phase = .loading
        self.isShowingInsight = false
        self.isShowingSettings = false
    }

    /// Loads the chart series and today's insight.
    ///
    /// `goalContext` is `nil` when the user has not yet completed goal setup —
    /// in that case there are no priority metrics to chart, but we still load
    /// the insight so the tile renders.
    ///
    /// The HK auth-prompt check is opportunistic: if it fails we default to
    /// `false` so the empty-state falls back to the Settings CTA rather than
    /// blocking the whole screen on the auth probe.
    func load(goalContext: GoalContext?) async {
        phase = .loading
        let priorityMetrics = priorityHealthKitMetrics(from: goalContext)
        let needsPrompt = (try? await healthKitService.needsAuthorizationPrompt()) ?? false
        do {
            let chartMetrics = try await readChartSeries(for: priorityMetrics)
            let insightMetrics = try await healthKitService.readDailyMetrics(
                over: Self.insightTrailingDays,
                metrics: HealthKitMetric.allCases
            )
            let insight = try await insightService.generate(
                date: LocalCalendarDate.string(from: Date()),
                metrics: insightMetrics
            )
            phase = .ready(HomeData(
                insight: insight,
                charts: chartMetrics,
                needsAuthorizationPrompt: needsPrompt
            ))
        } catch {
            phase = .error("We couldn't load your Home data.")
        }
    }

    /// Triggers the HealthKit system permission sheet inline, then re-runs
    /// ``load(goalContext:)`` so charts and the empty-state CTA reflect the
    /// post-prompt world. Used by the "Connect Apple Health" callout on Home
    /// — saves the user a trip through Settings.
    func grantAccess(goalContext: GoalContext?) async {
        try? await healthKitService.requestAuthorization()
        await load(goalContext: goalContext)
    }

    /// Maps the goal-agent's `priorityMetrics` strings to the typed
    /// ``HealthKitMetric`` cases the HK reader accepts, preserving order and
    /// dropping unknown identifiers.
    private func priorityHealthKitMetrics(from context: GoalContext?) -> [HealthKitMetric] {
        guard let context else { return [] }
        return context.priorityMetrics.compactMap { HealthKitMetric(rawValue: $0) }
    }

    /// Reads the trailing 30-day series for each priority metric and packs the
    /// result into ``HomeData/ChartSeries`` entries in the same order.
    ///
    /// Metrics whose HK read returns a scalar (``MetricValue/scalar``) or no
    /// value are dropped — a 30-day chart needs a series.
    private func readChartSeries(for metrics: [HealthKitMetric]) async throws -> [HomeData.ChartSeries] {
        guard !metrics.isEmpty else { return [] }
        let payload = try await healthKitService.readDailyMetrics(
            over: Self.chartTrailingDays,
            metrics: metrics
        )
        return metrics.compactMap { metric in
            guard case .series(let values) = payload[metric.rawValue], values.count > 1 else {
                return nil
            }
            return HomeData.ChartSeries(metricName: metric.rawValue, values: values)
        }
    }
}

/// Everything Home renders once ``HomeViewModel/load(goalContext:)`` resolves.
struct HomeData: Equatable {
    let insight: Insight
    let charts: [ChartSeries]
    /// `true` when iOS still needs to show the HealthKit permission sheet for
    /// any of our read types — the empty-charts state uses this to offer an
    /// inline "Connect Apple Health" button instead of routing through
    /// Settings.
    let needsAuthorizationPrompt: Bool

    struct ChartSeries: Equatable {
        let metricName: String
        let values: [Double]
    }
}
