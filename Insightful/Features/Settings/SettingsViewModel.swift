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
    /// database — the agent treats a new `/goal/start` as a fresh thread.
    func resetGoal() {
        onResetGoal()
    }
}
