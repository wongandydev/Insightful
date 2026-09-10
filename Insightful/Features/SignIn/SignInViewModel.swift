import AuthenticationServices
import Foundation
import Observation

/// Backs the sign-in screen shown after sign-out. Owns the three ways back
/// into the app — Apple, email + password, or a fresh anonymous identity —
/// and the in-flight / error state the view renders.
///
/// `@MainActor @Observable` because the view binds to ``isWorking`` and
/// ``errorMessage``.
@MainActor
@Observable
final class SignInViewModel {
    /// Two-way bound to the email field.
    var emailInput: String
    /// Two-way bound to the password field.
    var passwordInput: String
    /// `true` while any sign-in attempt is in flight. The view disables every
    /// action on this, including the Apple button from the moment it's tapped.
    private(set) var isWorking: Bool
    /// User-facing error from the most recent failed attempt. Reset at the
    /// start of every attempt.
    private(set) var errorMessage: String?

    private var nonces = AppleNonceStore()

    private let authService: AuthService
    private let onSignedIn: () -> Void

    init(authService: AuthService, onSignedIn: @escaping () -> Void) {
        self.authService = authService
        self.onSignedIn = onSignedIn
        self.emailInput = ""
        self.passwordInput = ""
        self.isWorking = false
        self.errorMessage = nil
    }

    /// Issues the nonce for a Sign in with Apple request and opens the
    /// in-flight window that ``handleAppleAuthorization(_:)`` closes.
    ///
    /// - Returns: The hashed value to set on
    ///   `ASAuthorizationAppleIDRequest.nonce`.
    func appleRequestNonce() -> String {
        isWorking = true
        return nonces.begin()
    }

    /// Unwraps the result of a Sign in with Apple request and exchanges its
    /// identity token for a session.
    ///
    /// Closes the in-flight window on every path and discards the nonce, so a
    /// cancelled attempt leaves nothing for a later exchange to spend.
    func handleAppleAuthorization(_ result: Result<ASAuthorization, any Error>) async {
        defer {
            nonces.discard()
            isWorking = false
        }
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard
                let idToken = Self.identityToken(from: authorization),
                let nonce = nonces.spend()
            else {
                errorMessage = "Apple didn't return a usable credential. Try again."
                return
            }
            do {
                try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                onSignedIn()
            } catch {
                errorMessage = "Couldn't sign in with Apple. Try again."
            }
        case .failure(let error):
            // A user-cancelled sheet is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Couldn't sign in with Apple. Try again."
            }
        }
    }

    /// Signs in with the email and password in the form.
    ///
    /// Validation is minimal client-side (both fields non-empty); the server
    /// is the real gate and rejects the pair as a single
    /// ``SignInError/invalidCredentials``, which cannot distinguish a wrong
    /// password from an unknown address.
    func signInWithEmail() async {
        errorMessage = nil
        let email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !passwordInput.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await authService.signIn(email: email, password: passwordInput)
            passwordInput = ""
            onSignedIn()
        } catch SignInError.invalidCredentials {
            errorMessage = "Email or password is incorrect."
        } catch {
            errorMessage = "Couldn't sign in. Try again."
        }
    }

    /// Carries on without an account, abandoning any identity this device
    /// previously held. Signs in anonymously here rather than letting the
    /// cold-start sequence do it: ``AuthService/bootstrap()`` reports
    /// ``BootstrapOutcome/sessionLost`` for a device that has authenticated
    /// before, which is what routed the user to this screen, so relying on it
    /// would loop straight back here.
    func continueAnonymously() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await authService.continueAnonymously()
            onSignedIn()
        } catch {
            errorMessage = "Couldn't continue. Try again."
        }
    }

    private static func identityToken(from authorization: ASAuthorization) -> String? {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let data = credential.identityToken
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
