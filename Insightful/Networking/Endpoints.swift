import Foundation

/// Typed builders for every endpoint in `IOS_CONTRACT.md`. Endpoints are values,
/// not methods on the client — keeps ``APIClient`` small and lets services
/// compose them freely.
enum Endpoints {
    static func health() -> APIRequest<HealthCheckResponse> {
        APIRequest(method: .get, path: "/health", body: nil, requiresAuth: false)
    }

    static func syncUser() -> APIRequest<UserSyncResponse> {
        APIRequest(method: .post, path: "/user", body: nil, requiresAuth: true)
    }

    static func startGoal(date: String) throws -> APIRequest<GoalStartResponse> {
        try .json(
            method: .post,
            path: "/goal/start",
            body: GoalStartRequest(date: date),
            requiresAuth: true
        )
    }

    static func sendGoalMessage(
        threadId: String,
        message: String,
        date: String
    ) throws -> APIRequest<GoalMessageResponse> {
        try .json(
            method: .post,
            path: "/goal/message",
            body: GoalMessageRequest(threadId: threadId, message: message, date: date),
            requiresAuth: true
        )
    }

    static func getGoalContext() -> APIRequest<GoalContextResponse> {
        APIRequest(method: .get, path: "/goal/context", body: nil, requiresAuth: true)
    }

    static func generateInsight(
        date: String,
        metrics: [String: MetricValue]
    ) throws -> APIRequest<InsightResponse> {
        try .json(
            method: .post,
            path: "/insight",
            body: InsightRequest(date: date, metrics: metrics),
            requiresAuth: true
        )
    }
}
