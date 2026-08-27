import Foundation

/// Our internal session representation. We do not surface Supabase's `Session`
/// type to the rest of the app — it's an SDK detail. `SupabaseAuthBackend`
/// maps between the two at the boundary.
struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

/// Failure modes of ``AuthBackend/linkApple(idToken:nonce:)`` that callers
/// branch on.
enum IdentityLinkError: Error, Equatable {
    /// The Apple ID is already attached to an account. Whether that account is
    /// this user's or someone else's is not distinguishable from the error
    /// alone, so callers surface it and stop.
    case identityAlreadyInUse
}

/// Failure modes of ``AuthBackend/signIn(email:password:)`` that callers
/// branch on.
enum SignInError: Error, Equatable {
    /// The email/password pair was rejected. Covers a wrong password, an
    /// unknown address, and an unconfirmed one — GoTrue deliberately returns
    /// the same code for all three so the endpoint can't enumerate accounts.
    case invalidCredentials
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

    /// Sign the current user out and clear any SDK-side cached session.
    /// A subsequent `currentSession()` returns `nil`.
    func signOut() async throws

    /// Attaches an email + password credential to the current (anonymous)
    /// user, converting it to a permanent account while preserving the
    /// user id — existing goal and insight rows stay attached.
    ///
    /// - Parameters:
    ///   - email: The address to attach. When the Supabase project has email
    ///     confirmation on, the change is pending until the user confirms.
    ///   - password: The password for future sign-ins.
    func linkEmail(email: String, password: String) async throws

    /// The linked email of the current user, or `nil` for anonymous users.
    func currentUserEmail() async -> String?

    /// Attaches an Apple identity to the current (anonymous) user, preserving
    /// the user id — existing goal and insight rows stay attached.
    ///
    /// - Parameters:
    ///   - idToken: The identity token from `ASAuthorizationAppleIDCredential`.
    ///   - nonce: The raw nonce whose SHA-256 hash was sent on the Apple
    ///     request.
    /// - Throws: ``IdentityLinkError/identityAlreadyInUse`` when this Apple ID
    ///   is already attached to an account.
    func linkApple(idToken: String, nonce: String) async throws

    /// Whether an Apple identity is attached to the current user.
    func hasAppleIdentity() -> Bool

    /// Signs in the account that owns `email`, replacing any cached session.
    ///
    /// - Parameters:
    ///   - email: The address attached to the account.
    ///   - password: The account's password.
    /// - Returns: The new session.
    /// - Throws: ``SignInError/invalidCredentials`` when the pair is rejected.
    func signIn(email: String, password: String) async throws -> AuthSession

    /// Signs in the account that owns the Apple identity in `idToken`,
    /// replacing any cached session.
    ///
    /// Unlike ``linkApple(idToken:nonce:)`` this attaches nothing to the
    /// current user — it resolves the token to whichever account already owns
    /// that Apple ID, creating one when none does.
    ///
    /// - Parameters:
    ///   - idToken: The identity token from `ASAuthorizationAppleIDCredential`.
    ///   - nonce: The raw nonce whose SHA-256 hash was sent on the Apple
    ///     request.
    /// - Returns: The new session.
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
}
