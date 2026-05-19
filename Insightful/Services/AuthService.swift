import Foundation
import Observation

/// Orchestrates the app's anonymous Supabase session.
///
/// Responsibilities:
/// - On launch, `bootstrap()` either restores the SDK's cached session or
///   signs in anonymously.
/// - Exposes the current `accessToken` for `APIClient`'s `tokenProvider` closure.
/// - Performs an explicit `refresh()` when `APIClient` sees a 401.
/// - On refresh failure, keeps the previously cached session intact — a
///   transient network blip should not blow away the user's identity.
///   `APIClient` will surface `.unauthorized` to the view layer for the user
///   to retry. *(Decision: option (b) in plan.)*
///
/// `@MainActor + @Observable` because views observe the session state. The
/// `tokenProvider` and `refreshToken` closures `APIClient` consumes hop back
/// to MainActor automatically when called from background contexts.
@MainActor
@Observable
final class AuthService {
    private(set) var session: AuthSession?
    private(set) var isReady = false

    private let backend: AuthBackend

    init(backend: AuthBackend) {
        self.backend = backend
    }

    /// Restore the SDK's cached session or sign in anonymously. Idempotent —
    /// safe to call on every cold start.
    func bootstrap() async throws {
        if let cached = try await backend.currentSession() {
            session = cached
        } else {
            session = try await backend.signInAnonymously()
        }
        isReady = true
    }

    /// Triggered by `APIClient` on 401. Updates the cached session in place.
    func refresh() async throws {
        session = try await backend.refreshSession()
    }

    var accessToken: String? { session?.accessToken }
}
