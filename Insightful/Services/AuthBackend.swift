import Foundation

/// Our internal session representation. We do not surface Supabase's `Session`
/// type to the rest of the app — it's an SDK detail. `SupabaseAuthBackend`
/// maps between the two at the boundary.
struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

/// The narrow auth surface `AuthService` depends on.
///
/// Production is `SupabaseAuthBackend`; tests use an `actor FakeAuthBackend`.
/// Same `rules.md` exception as `HTTPClient` — we genuinely need to swap.
///
/// The Supabase SDK already handles session persistence (Keychain), proactive
/// refresh, and crash-recovery internally. This protocol just exposes the
/// three operations our app initiates explicitly.
protocol AuthBackend: Sendable {
    /// The session the SDK already has cached, if any. Returns `nil` on first
    /// launch or after sign-out.
    func currentSession() async throws -> AuthSession?

    /// Sign in anonymously and return the new session.
    func signInAnonymously() async throws -> AuthSession

    /// Force a token refresh. Called by `APIClient` on a 401.
    func refreshSession() async throws -> AuthSession
}
