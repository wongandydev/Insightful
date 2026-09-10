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
/// - Distinguishes "never had a session" from "had one and lost it", so a
///   server-terminated session routes to sign-in instead of silently
///   replacing the user's identity. See ``BootstrapOutcome``.
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
    private let userDefaults: UserDefaults

    init(backend: AuthBackend, userDefaults: UserDefaults) {
        self.backend = backend
        self.userDefaults = userDefaults
    }

    /// Restore the cached session, or sign in anonymously on a device that has
    /// never held one. Idempotent — safe to call on every cold start.
    ///
    /// Returns ``BootstrapOutcome/sessionLost`` instead of signing in when this
    /// device has authenticated before and the session is now gone. The Supabase
    /// SDK deletes the stored session and reports `.sessionMissing` whenever the
    /// server rejects a refresh with `session_not_found`, `session_expired`,
    /// `refresh_token_not_found`, or `refresh_token_already_used` — states that
    /// are indistinguishable from a first launch at this layer. Signing in
    /// anonymously there mints a new user id and strands the previous one's
    /// goals and insights with no way to reach them again.
    func bootstrap() async throws -> BootstrapOutcome {
        if let cached = try await backend.currentSession() {
            adopt(cached)
            return .ready
        }
        guard !hasEverAuthenticated else { return .sessionLost }
        adopt(try await backend.signInAnonymously())
        return .ready
    }

    /// Starts a new anonymous identity after a lost session, abandoning the
    /// previous one for good. Only the sign-in screen's "continue without an
    /// account" path calls this — ``bootstrap()`` deliberately will not.
    func continueAnonymously() async throws {
        adopt(try await backend.signInAnonymously())
    }

    /// Triggered by `APIClient` on 401. Updates the cached session in place.
    func refresh() async throws {
        session = try await backend.refreshSession()
    }

    /// Sign out and clear the cached session. The device stays marked as having
    /// authenticated, so the next `bootstrap()` reports
    /// ``BootstrapOutcome/sessionLost`` and offers sign-in rather than minting a
    /// replacement anonymous user.
    func signOut() async throws {
        try await backend.signOut()
        session = nil
        isReady = false
    }

    /// Converts the current anonymous user to a permanent email + password
    /// account. The user id — and therefore all saved goals and insights —
    /// is preserved.
    func linkEmail(email: String, password: String) async throws {
        try await backend.linkEmail(email: email, password: password)
    }

    /// The linked email of the signed-in user, or `nil` while anonymous.
    func linkedEmail() async -> String? {
        await backend.currentUserEmail()
    }

    /// Attaches an Apple identity to the current anonymous user. The user id
    /// — and therefore all saved goals and insights — is preserved.
    ///
    /// - Throws: ``IdentityLinkError/identityAlreadyInUse`` when the Apple ID
    ///   is already attached to an account.
    func linkApple(idToken: String, nonce: String) async throws {
        try await backend.linkApple(idToken: idToken, nonce: nonce)
    }

    /// Whether an Apple identity is attached to the signed-in user.
    func hasAppleIdentity() -> Bool {
        backend.hasAppleIdentity()
    }

    /// Signs in an existing email + password account, replacing the current
    /// session. Used by the sign-in screen to return a signed-out user to
    /// their own data rather than a fresh anonymous identity.
    ///
    /// - Throws: ``SignInError/invalidCredentials`` when the pair is rejected.
    func signIn(email: String, password: String) async throws {
        adopt(try await backend.signIn(email: email, password: password))
    }

    /// Signs in the account that owns the Apple identity in `idToken`,
    /// replacing the current session.
    func signInWithApple(idToken: String, nonce: String) async throws {
        adopt(try await backend.signInWithApple(idToken: idToken, nonce: nonce))
    }

    var accessToken: String? { session?.accessToken }

    // MARK: - Internals

    /// Whether this device has ever held a session. Survives the session itself
    /// — it is the only evidence left once the SDK deletes a terminated one.
    private var hasEverAuthenticated: Bool {
        get { userDefaults.bool(forKey: Keys.hasEverAuthenticated) }
        set { userDefaults.set(newValue, forKey: Keys.hasEverAuthenticated) }
    }

    private func adopt(_ newSession: AuthSession) {
        session = newSession
        isReady = true
        hasEverAuthenticated = true
    }

    private enum Keys {
        static let hasEverAuthenticated = "auth.hasEverAuthenticated"
    }
}

/// What ``AuthService/bootstrap()`` found on this device.
enum BootstrapOutcome: Equatable {
    /// A session is active — restored from storage, or freshly created for a
    /// device that had never authenticated.
    case ready
    /// This device held a session and the server has since terminated it. No
    /// replacement identity was created; the caller decides what to offer.
    case sessionLost
}
