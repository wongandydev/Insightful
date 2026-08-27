import Foundation
import Auth

/// Production `AuthBackend` — a thin adapter over the Supabase `AuthClient`.
///
/// The SDK already handles session persistence (built-in Keychain store on
/// Apple platforms), proactive refresh, and crash-recovery. We surface only
/// the operations our app initiates explicitly: read cache, sign in, force
/// refresh, and attach or resolve a durable identity.
///
/// We talk to `AuthClient` directly (not the umbrella `SupabaseClient`) since
/// auth is the only Supabase product we use. Keeps the binary lean.
struct SupabaseAuthBackend: AuthBackend {
    let client: AuthClient

    init(client: AuthClient) {
        self.client = client
    }

    init(url: URL, anonKey: String) {
        let authURL = url.appendingPathComponent("auth/v1")
        self.client = AuthClient(
            url: authURL,
            headers: [
                "apikey": anonKey,
                "Authorization": "Bearer \(anonKey)",
            ],
            localStorage: AuthClient.Configuration.defaultLocalStorage
        )
    }

    func currentSession() async throws -> AuthSession? {
        // `client.session` throws in two very different cases and only one
        // means "no session": `AuthError.sessionMissing` (first launch /
        // signed out). Any other throw — typically a failed network refresh
        // of an expired token — must PROPAGATE. Mapping it to `nil` made
        // `bootstrap()` sign in a fresh anonymous user, overwriting the
        // Keychain session and orphaning the previous identity's data
        // (observed 2026-06-04 as "rebuild produces a fresh user").
        do {
            return try await Self.adapt(client.session)
        } catch let error as AuthError {
            if case .sessionMissing = error { return nil }
            throw error
        }
    }

    func signInAnonymously() async throws -> AuthSession {
        let session = try await client.signInAnonymously()
        return Self.adapt(session)
    }

    func refreshSession() async throws -> AuthSession {
        let session = try await client.refreshSession()
        return Self.adapt(session)
    }

    func signOut() async throws {
        try await client.signOut()
    }

    func linkEmail(email: String, password: String) async throws {
        try await client.update(user: UserAttributes(email: email, password: password))
    }

    func currentUserEmail() async -> String? {
        client.currentUser?.email
    }

    func linkApple(idToken: String, nonce: String) async throws {
        do {
            try await client.linkIdentityWithIdToken(credentials: Self.appleCredentials(idToken: idToken, nonce: nonce))
        } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
            throw IdentityLinkError.identityAlreadyInUse
        }
    }

    func hasAppleIdentity() -> Bool {
        let identities = client.currentUser?.identities ?? []
        return identities.contains { $0.provider == OpenIDConnectCredentials.Provider.apple.rawValue }
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        do {
            return Self.adapt(try await client.signIn(email: email, password: password))
        } catch let error as AuthError where error.errorCode == .invalidCredentials {
            throw SignInError.invalidCredentials
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let session = try await client.signInWithIdToken(
            credentials: Self.appleCredentials(idToken: idToken, nonce: nonce)
        )
        return Self.adapt(session)
    }

    private static func appleCredentials(idToken: String, nonce: String) -> OpenIDConnectCredentials {
        OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
    }

    private static func adapt(_ session: Session) -> AuthSession {
        AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
