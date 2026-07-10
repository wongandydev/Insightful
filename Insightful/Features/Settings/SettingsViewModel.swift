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
        self.reminderEnabled = false
        self.reminderTime = Self.date(hour: 8, minute: 0)
        self.notificationsDeniedMessage = nil
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
