import Foundation

/// View-model-facing protocol for the user-sync operation.
///
/// Production type is ``UserService``. Test seam: `FakeUserService` in the
/// test support folder. The protocol exists so view-model tests can stub
/// this service directly without standing up an ``APIClient`` and stubbing
/// HTTP responses.
protocol UserServicing: Sendable {
    /// Idempotent sync of the current user row.
    ///
    /// - Returns: The server-side user id (same as the JWT subject).
    func sync() async throws -> String
}

/// Wraps the `/user` endpoint. Idempotent — view models call ``sync()`` on
/// every cold start to upsert the user row keyed to the JWT.
struct UserService: UserServicing {
    let client: APIClient

    func sync() async throws -> String {
        try await client.send(Endpoints.syncUser()).userId
    }
}
