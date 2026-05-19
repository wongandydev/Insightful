import Foundation

/// View-model-facing protocol for the goal-setup endpoints.
///
/// Production type is ``GoalService``. Test seam: `FakeGoalService` in the
/// test support folder. The protocol exists so view-model tests can stub
/// this service directly without standing up an ``APIClient`` and stubbing
/// HTTP responses.
protocol GoalServicing: Sendable {
    /// Begins the goal-setup conversation. Returns the agent's first
    /// question.
    func start(date: String) async throws -> GoalStartResponse

    /// Sends a user reply on an active goal thread.
    func sendMessage(threadId: String, message: String, date: String) async throws -> GoalMessageResponse

    /// Returns the user's saved goal context if any.
    func getContext() async throws -> GoalContextResponse
}

/// Wraps the `/goal/*` endpoints. Used by the goal-setup view model and by
/// ``RootViewModel/start()`` to decide cold-start routing.
struct GoalService: GoalServicing {
    let client: APIClient

    func start(date: String) async throws -> GoalStartResponse {
        try await client.send(Endpoints.startGoal(date: date))
    }

    func sendMessage(threadId: String, message: String, date: String) async throws -> GoalMessageResponse {
        try await client.send(Endpoints.sendGoalMessage(threadId: threadId, message: message, date: date))
    }

    func getContext() async throws -> GoalContextResponse {
        try await client.send(Endpoints.getGoalContext())
    }
}
