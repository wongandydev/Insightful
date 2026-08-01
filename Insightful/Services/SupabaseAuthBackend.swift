import Foundation
import Auth

/// Production `AuthBackend` — a thin adapter over the Supabase `AuthClient`.
///
/// The SDK already handles session persistence (built-in Keychain store on
/// Apple platforms), proactive refresh, and crash-recovery. We only surface
/// the three explicit operations our app initiates: read cache, sign in,
/// force refresh.
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

    private static func adapt(_ session: Session) -> AuthSession {
        AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
