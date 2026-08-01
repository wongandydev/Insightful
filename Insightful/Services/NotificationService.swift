import Foundation
import UserNotifications

/// The user's daily-reminder configuration as persisted in `UserDefaults`.
struct DailyReminderPreference: Equatable, Sendable {
    let enabled: Bool
    /// Local-time hour (0–23) the reminder fires.
    let hour: Int
    /// Local-time minute (0–59) the reminder fires.
    let minute: Int
}

/// Local-notification scheduling for the daily insight reminder and
/// same-day alert follow-ups.
protocol NotificationScheduling: Sendable {
    /// The persisted reminder preference; defaults to disabled at 8:00.
    func dailyReminderPreference() async -> DailyReminderPreference

    /// Requests notification permission if needed, schedules the repeating
    /// daily reminder, and persists the preference.
    ///
    /// - Parameters:
    ///   - hour: Local-time hour (0–23) the reminder should fire.
    ///   - minute: Local-time minute (0–59) the reminder should fire.
    /// - Returns: `false` when the user denied notification permission — the
    ///   preference is left disabled and nothing is scheduled.
    func enableDailyReminder(hour: Int, minute: Int) async -> Bool

    /// Cancels the pending daily reminder and persists the disabled state.
    func disableDailyReminder() async

    /// Schedules a one-off follow-up for later today when an insight
    /// carried alerts, so the flag isn't forgotten the moment the app
    /// closes. No-ops after the follow-up hour or when permission is
    /// missing; rescheduling the same day replaces the previous follow-up.
    func scheduleAlertFollowUp(firstAlert: String) async
}

/// Production ``NotificationScheduling`` over `UNUserNotificationCenter`.
///
/// Owns its `UserDefaults` keys so notification concerns don't leak into
/// view models — callers only see ``DailyReminderPreference``.
actor NotificationService: NotificationScheduling {
    /// Fixed identifiers so re-scheduling replaces rather than stacks.
    private static let dailyReminderId = "daily-insight-reminder"
    private static let alertFollowUpId = "insight-alert-followup"
    /// Local hour the alert follow-up fires; loading an insight after this
    /// hour skips the follow-up (the day is nearly over).
    private static let alertFollowUpHour = 18

    private enum Keys {
        static let enabled = "dailyReminderEnabled"
        static let hour = "dailyReminderHour"
        static let minute = "dailyReminderMinute"
    }

    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults

    init(center: UNUserNotificationCenter, userDefaults: UserDefaults) {
        self.center = center
        self.userDefaults = userDefaults
    }

    func dailyReminderPreference() -> DailyReminderPreference {
        DailyReminderPreference(
            enabled: userDefaults.bool(forKey: Keys.enabled),
            hour: userDefaults.object(forKey: Keys.hour) as? Int ?? 8,
            minute: userDefaults.object(forKey: Keys.minute) as? Int ?? 0
        )
    }

    func enableDailyReminder(hour: Int, minute: Int) async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            userDefaults.set(false, forKey: Keys.enabled)
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Your daily insight is ready"
        content.body = "See what your body's data says about today's training."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyReminderId, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            userDefaults.set(false, forKey: Keys.enabled)
            return false
        }

        userDefaults.set(true, forKey: Keys.enabled)
        userDefaults.set(hour, forKey: Keys.hour)
        userDefaults.set(minute, forKey: Keys.minute)
        return true
    }

    func disableDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderId])
        userDefaults.set(false, forKey: Keys.enabled)
    }

    func scheduleAlertFollowUp(firstAlert: String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let now = Date()
        guard calendar.component(.hour, from: now) < Self.alertFollowUpHour else { return }

        let content = UNMutableNotificationContent()
        content.title = "Check in on today's alert"
        content.body = firstAlert
        content.sound = .default

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = Self.alertFollowUpHour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.alertFollowUpId, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
