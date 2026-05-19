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
        // `client.session` throws when no cached session exists — that's the
        // "no session" signal we want to surface as `nil`.
        do {
            return try await Self.adapt(client.session)
        } catch {
            return nil
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

    private static func adapt(_ session: Session) -> AuthSession {
        AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
