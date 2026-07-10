import Foundation
@testable import Insightful

/// Scriptable ``NotificationScheduling`` for view-model tests.
actor FakeNotificationService: NotificationScheduling {
    private var preference = DailyReminderPreference(enabled: false, hour: 8, minute: 0)
    private var enableResult = true

    private(set) var enableCalls: [(hour: Int, minute: Int)] = []
    private(set) var disableCalls = 0
    private(set) var alertFollowUps: [String] = []

    func programPreference(_ preference: DailyReminderPreference) {
        self.preference = preference
    }

    func programEnableResult(_ granted: Bool) {
        enableResult = granted
    }

    func dailyReminderPreference() -> DailyReminderPreference {
        preference
    }

    func enableDailyReminder(hour: Int, minute: Int) -> Bool {
        enableCalls.append((hour: hour, minute: minute))
        return enableResult
    }

    func disableDailyReminder() {
        disableCalls += 1
    }

    func scheduleAlertFollowUp(firstAlert: String) {
        alertFollowUps.append(firstAlert)
    }
}
