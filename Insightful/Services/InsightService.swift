import Foundation

/// Wraps `/insight`. The server caches per `(userId, date)` so calling twice on
/// the same day returns the cached generation cheaply.
struct InsightService: Sendable {
    let client: APIClient

    func generate(date: String, metrics: [String: MetricValue]) async throws -> InsightResponse {
        try await client.send(Endpoints.generateInsight(date: date, metrics: metrics))
    }
}
