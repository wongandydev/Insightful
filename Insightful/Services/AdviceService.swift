import Foundation

/// View-model-facing protocol for the coaching-chat endpoints.
protocol AdviceServicing: Sendable {
    /// Opens or resumes the user's single long-lived coach thread.
    func start() async throws -> AdviceStartResponse

    /// Sends a user message to the coach and returns its reply.
    ///
    /// - Parameters:
    ///   - threadId: Thread from ``start()``.
    ///   - message: The user's text, 1–2000 characters.
    ///   - date: The user's local calendar date as `YYYY-MM-DD`.
    ///   - metrics: Recent HealthKit payload for grounding, or `nil` when
    ///     unavailable.
    func sendMessage(threadId: String, message: String, date: String, metrics: [String: MetricValue]?) async throws -> AdviceMessageResponse
}

/// Wraps the `/advice/*` endpoints.
struct AdviceService: AdviceServicing {
    let client: APIClient

    func start() async throws -> AdviceStartResponse {
        try await client.send(Endpoints.startAdvice())
    }

    func sendMessage(threadId: String, message: String, date: String, metrics: [String: MetricValue]?) async throws -> AdviceMessageResponse {
        try await client.send(Endpoints.sendAdviceMessage(
            threadId: threadId,
            message: message,
            date: date,
            metrics: metrics
        ))
    }
}
