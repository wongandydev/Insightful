import Foundation

// TODO(typed-throws): the contract here is "throws any Error", but the
// actor-based fakes (`FakeInsightService` etc.) require Sendable error
// storage, so their `program(_:)` helpers are stricter than this protocol.
// Switching every service protocol + impl + `APIClient.send` to
// `throws(any Error & Sendable)` would let the test API mirror the protocol
// exactly. ~12 files of churn; not blocking, revisit when the pattern is
// painful enough to justify the move.
protocol InsightServicing: Sendable {
    /// Generates an insight for `date` from the supplied HealthKit-derived
    /// metrics.
    func generate(date: String, metrics: [String: MetricValue]) async throws -> Insight
}

/// Wraps `/insight`. The server caches per `(userId, date)` so calling twice on
/// the same day returns the cached generation cheaply — that flag is server
/// telemetry, not user-facing, so it is discarded at this boundary.
struct InsightService: InsightServicing {
    let client: APIClient

    func generate(date: String, metrics: [String: MetricValue]) async throws -> Insight {
        let response = try await client.send(Endpoints.generateInsight(date: date, metrics: metrics))
        return response.insight
    }
}
