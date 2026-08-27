import AuthenticationServices
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
    /// ``linkAccount()`` and refreshed after a successful
    /// ``completeAppleSignIn(idToken:)``, which attaches the Apple ID's email.
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
    /// Whether the daily reminder is on. Rendered by the Notifications
    /// toggle; mutate through ``setReminderEnabled(_:)`` so scheduling and
    /// persistence stay in sync.
    private(set) var reminderEnabled: Bool
    /// The reminder's fire time as a `Date` (only hour/minute matter).
    /// Mutate through ``setReminderTime(_:)``.
    private(set) var reminderTime: Date
    /// Set when the user flips the toggle on but iOS notification
    /// permission is denied — the toggle snaps back and this explains why.
    private(set) var notificationsDeniedMessage: String?
    /// Whether an Apple identity is attached to the current user. Hydrated by
    /// ``loadAppleIdentity()``.
    private(set) var appleLinked: Bool
    /// `true` while a Sign in with Apple exchange is in flight.
    private(set) var isLinkingApple: Bool
    /// Confirmation after a successful Apple link.
    private(set) var appleMessage: String?
    /// Error from the most recent Sign in with Apple attempt.
    private(set) var appleErrorMessage: String?

    private var nonces = AppleNonceStore()

    private let authService: AuthService
    private let notificationService: any NotificationScheduling
    private let onSignedOut: () -> Void
    private let onResetGoal: () -> Void

    init(
        authService: AuthService,
        notificationService: any NotificationScheduling,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.authService = authService
        self.notificationService = notificationService
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
        self.reminderEnabled = false
        self.reminderTime = Self.date(hour: 8, minute: 0)
        self.notificationsDeniedMessage = nil
        self.appleLinked = false
        self.isLinkingApple = false
        self.appleMessage = nil
        self.appleErrorMessage = nil
    }

    /// Hydrates ``linkedEmail`` from the auth backend. Attach to the view's
    /// `.task`.
    func loadLinkedEmail() async {
        linkedEmail = await authService.linkedEmail()
    }

    /// Hydrates ``appleLinked`` from the auth backend. Attach to the view's
    /// `.task`.
    func loadAppleIdentity() {
        appleLinked = authService.hasAppleIdentity()
    }

    /// Generates the nonce for a Sign in with Apple request, retains its raw
    /// half for the token exchange, and opens the in-flight window that
    /// ``handleAppleAuthorization(_:)`` closes.
    ///
    /// Marking the flow in flight here rather than on the exchange is what
    /// keeps a second tap from replacing the nonce the pending request will be
    /// verified against.
    ///
    /// - Returns: The hashed value to set on
    ///   `ASAuthorizationAppleIDRequest.nonce`.
    func appleRequestNonce() -> String {
        isLinkingApple = true
        return nonces.begin()
    }

    /// Unwraps the result of a Sign in with Apple request and hands its
    /// identity token to ``completeAppleSignIn(idToken:)``.
    ///
    /// Closes the in-flight window ``appleRequestNonce()`` opened and discards
    /// the nonce on every path, so a cancelled or failed attempt leaves no raw
    /// nonce resident for a later exchange to spend.
    func handleAppleAuthorization(_ result: Result<ASAuthorization, any Error>) async {
        defer {
            nonces.discard()
            isLinkingApple = false
        }
        appleErrorMessage = nil
        appleMessage = nil
        switch result {
        case .success(let authorization):
            guard let idToken = Self.identityToken(from: authorization) else {
                appleErrorMessage = "Apple didn't return a usable credential. Try again."
                return
            }
            await completeAppleSignIn(idToken: idToken)
        case .failure(let error):
            // A user-cancelled sheet is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                appleErrorMessage = "Couldn't connect your Apple ID. Try again."
            }
        }
    }

    /// Attaches `idToken` to the current user, consuming the nonce from the
    /// matching ``appleRequestNonce()`` call.
    ///
    /// An Apple ID that already owns an account cannot be attached to this
    /// one, and the two cannot be merged, so that case surfaces as an error
    /// and the current user is left as they were.
    ///
    /// The nonce is spent whether or not the exchange succeeds — a retry goes
    /// back through ``appleRequestNonce()`` for a fresh one.
    func completeAppleSignIn(idToken: String) async {
        appleErrorMessage = nil
        appleMessage = nil
        guard !authService.hasAppleIdentity() else {
            appleLinked = true
            return
        }
        guard let nonce = nonces.spend() else {
            appleErrorMessage = "Couldn't connect your Apple ID. Try again."
            return
        }
        do {
            try await authService.linkApple(idToken: idToken, nonce: nonce)
            appleLinked = true
            await loadLinkedEmail()
            appleMessage = "Apple ID connected. Your goal and history follow you to any device signed in to it."
        } catch IdentityLinkError.identityAlreadyInUse {
            appleErrorMessage = "This Apple ID is already connected to an Insightful account. Accounts can't be merged, so this device's goal and history can't move to it."
        } catch {
            appleErrorMessage = "Couldn't connect your Apple ID. Try again."
        }
    }

    private static func identityToken(from authorization: ASAuthorization) -> String? {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let data = credential.identityToken
        else { return nil }
        return String(data: data, encoding: .utf8)
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

    /// Hydrates the reminder controls from the persisted preference. Attach
    /// to the view's `.task`.
    func loadReminderPreference() async {
        let preference = await notificationService.dailyReminderPreference()
        reminderEnabled = preference.enabled
        reminderTime = Self.date(hour: preference.hour, minute: preference.minute)
    }

    /// Enables or disables the daily reminder. Enabling triggers the iOS
    /// permission prompt on first use; a denial snaps the toggle back off
    /// and sets ``notificationsDeniedMessage``.
    func setReminderEnabled(_ enabled: Bool) async {
        notificationsDeniedMessage = nil
        if enabled {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let granted = await notificationService.enableDailyReminder(
                hour: components.hour ?? 8,
                minute: components.minute ?? 0
            )
            reminderEnabled = granted
            if !granted {
                notificationsDeniedMessage = "Notifications are off for Insightful. Enable them in Settings to get a daily reminder."
            }
        } else {
            await notificationService.disableDailyReminder()
            reminderEnabled = false
        }
    }

    /// Updates the reminder's fire time and reschedules when it's enabled.
    func setReminderTime(_ time: Date) async {
        reminderTime = time
        guard reminderEnabled else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        _ = await notificationService.enableDailyReminder(
            hour: components.hour ?? 8,
            minute: components.minute ?? 0
        )
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// Signs the current anonymous user out and notifies the parent.
    ///
    /// On success the caller (RootView) re-runs the cold-start sequence,
    /// which signs in a fresh anonymous user and routes the app through goal
    /// setup again. On failure the user is left signed in and
    /// ``errorMessage`` is populated.
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
