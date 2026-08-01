import Foundation
import Observation

/// Backs the settings sheet. Owns the sign-out and goal-reset actions and
/// surfaces in-flight / error state to the view.
///
/// `@MainActor @Observable` because the view binds to ``isSigningOut`` and
/// ``errorMessage``.
@MainActor
@Observable
final class SettingsViewModel {
    /// `true` while ``signOut()`` is in flight. The view disables both
    /// action buttons on this.
    private(set) var isSigningOut: Bool
    /// User-facing error string from the most recent failed ``signOut()``.
    /// Reset to `nil` at the start of every attempt.
    private(set) var errorMessage: String?
    /// The email attached to the current user, or `nil` while anonymous.
    /// Hydrated by ``loadLinkedEmail()``; set optimistically on a successful
    /// ``linkAccount()``.
    private(set) var linkedEmail: String?
    /// Two-way bound to the create-account email field.
    var linkEmailInput: String
    /// Two-way bound to the create-account password field.
    var linkPasswordInput: String
    /// `true` while ``linkAccount()`` is in flight.
    private(set) var isLinking: Bool
    /// Success confirmation after ``linkAccount()``; prompts the user to
    /// check their inbox since the project may require email confirmation.
    private(set) var linkMessage: String?
    /// Validation or server error from the most recent ``linkAccount()``.
    private(set) var linkErrorMessage: String?

    private let authService: AuthService
    private let onSignedOut: () -> Void
    private let onResetGoal: () -> Void

    init(
        authService: AuthService,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.authService = authService
        self.onSignedOut = onSignedOut
        self.onResetGoal = onResetGoal
        self.isSigningOut = false
        self.errorMessage = nil
        self.linkedEmail = nil
        self.linkEmailInput = ""
        self.linkPasswordInput = ""
        self.isLinking = false
        self.linkMessage = nil
        self.linkErrorMessage = nil
    }

    /// Hydrates ``linkedEmail`` from the auth backend. Attach to the view's
    /// `.task`.
    func loadLinkedEmail() async {
        linkedEmail = await authService.linkedEmail()
    }

    /// Converts the anonymous user to an email + password account,
    /// preserving the user id and all saved data.
    ///
    /// Validation is minimal client-side (shaped email, 8+ character
    /// password); the server is the real gate and its failure surfaces as
    /// ``linkErrorMessage``.
    func linkAccount() async {
        linkErrorMessage = nil
        linkMessage = nil
        let email = linkEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else {
            linkErrorMessage = "Enter a valid email address."
            return
        }
        guard linkPasswordInput.count >= 8 else {
            linkErrorMessage = "Password must be at least 8 characters."
            return
        }
        isLinking = true
        defer { isLinking = false }
        do {
            try await authService.linkEmail(email: email, password: linkPasswordInput)
            linkedEmail = email
            linkPasswordInput = ""
            linkMessage = "Account saved. If a confirmation email arrives, tap the link to finish."
        } catch {
            linkErrorMessage = "Couldn't create the account. Try again."
        }
    }

    /// Signs the current anonymous user out and notifies the parent.
    ///
    /// On success the caller (RootView) is expected to re-run the cold-start
    /// sequence, which will sign in a fresh anonymous user and route the
    /// app through goal setup again. On failure the user is left signed
    /// in and ``errorMessage`` is populated.
    func signOut() async {
        isSigningOut = true
        errorMessage = nil
        defer { isSigningOut = false }
        do {
            try await authService.signOut()
            onSignedOut()
        } catch {
            errorMessage = "Sign out failed. Try again."
        }
    }

    /// Triggers a re-route to the goal-setup screen without touching the
    /// current session. The existing goal context row stays in the
    /// database; `/goal/start` reopens the most recent completed thread so
    /// the agent picks up in refinement mode rather than from scratch.
    func resetGoal() {
        onResetGoal()
    }
}
