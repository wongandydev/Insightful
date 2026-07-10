import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct SettingsViewModelTests {

    @Test
    func signOutWhenSucceedsCallsOnSignedOut() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(session))
        await backend.programSignOut(.success(()))
        let authService = AuthService(backend: backend)
        try? await authService.bootstrap()
        var signedOutCount = 0
        let viewModel = SettingsViewModel(
            authService: authService,
            notificationService: FakeNotificationService(),
            onSignedOut: { signedOutCount += 1 },
            onResetGoal: {}
        )

        // When
        await viewModel.signOut()

        // Then
        let calls = await backend.signOutCalls
        #expect(calls == 1)
        #expect(signedOutCount == 1)
        #expect(authService.session == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func signOutWhenFailsSurfacesError() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(session))
        await backend.programSignOut(.failure(FakeError.network))
        let authService = AuthService(backend: backend)
        try? await authService.bootstrap()
        var signedOutCount = 0
        let viewModel = SettingsViewModel(
            authService: authService,
            notificationService: FakeNotificationService(),
            onSignedOut: { signedOutCount += 1 },
            onResetGoal: {}
        )

        // When
        await viewModel.signOut()

        // Then
        #expect(signedOutCount == 0)
        #expect(viewModel.errorMessage != nil)
        #expect(authService.session != nil)
    }

    @Test
    func resetGoalCallsOnResetGoal() async {
        // Given
        let backend = FakeAuthBackend()
        let authService = AuthService(backend: backend)
        var resetCount = 0
        let viewModel = SettingsViewModel(
            authService: authService,
            notificationService: FakeNotificationService(),
            onSignedOut: {},
            onResetGoal: { resetCount += 1 }
        )

        // When
        viewModel.resetGoal()

        // Then
        #expect(resetCount == 1)
    }

    // MARK: - Daily reminder

    @Test
    func setReminderEnabledWhenPermissionGrantedSchedulesAtCurrentTime() async {
        // Given
        let notifications = FakeNotificationService()
        await notifications.programEnableResult(true)
        let viewModel = makeViewModel(notifications: notifications)

        // When
        await viewModel.setReminderEnabled(true)

        // Then
        let calls = await notifications.enableCalls
        #expect(viewModel.reminderEnabled)
        #expect(calls.count == 1)
        #expect(viewModel.notificationsDeniedMessage == nil)
    }

    @Test
    func setReminderEnabledWhenPermissionDeniedSnapsToggleBackWithMessage() async {
        // Given
        let notifications = FakeNotificationService()
        await notifications.programEnableResult(false)
        let viewModel = makeViewModel(notifications: notifications)

        // When
        await viewModel.setReminderEnabled(true)

        // Then
        #expect(viewModel.reminderEnabled == false)
        #expect(viewModel.notificationsDeniedMessage != nil)
    }

    @Test
    func setReminderEnabledWhenTurnedOffCancelsSchedule() async {
        // Given
        let notifications = FakeNotificationService()
        await notifications.programEnableResult(true)
        let viewModel = makeViewModel(notifications: notifications)
        await viewModel.setReminderEnabled(true)

        // When
        await viewModel.setReminderEnabled(false)

        // Then
        let disableCalls = await notifications.disableCalls
        #expect(viewModel.reminderEnabled == false)
        #expect(disableCalls == 1)
    }

    @Test
    func loadReminderPreferenceHydratesFromPersistedState() async {
        // Given
        let notifications = FakeNotificationService()
        await notifications.programPreference(DailyReminderPreference(enabled: true, hour: 6, minute: 30))
        let viewModel = makeViewModel(notifications: notifications)

        // When
        await viewModel.loadReminderPreference()

        // Then
        let components = Calendar.current.dateComponents([.hour, .minute], from: viewModel.reminderTime)
        #expect(viewModel.reminderEnabled)
        #expect(components.hour == 6)
        #expect(components.minute == 30)
    }

    @Test
    func setReminderTimeWhenEnabledReschedulesWithNewTime() async {
        // Given
        let notifications = FakeNotificationService()
        await notifications.programEnableResult(true)
        let viewModel = makeViewModel(notifications: notifications)
        await viewModel.setReminderEnabled(true)
        let newTime = Calendar.current.date(bySettingHour: 21, minute: 15, second: 0, of: Date())!

        // When
        await viewModel.setReminderTime(newTime)

        // Then
        let calls = await notifications.enableCalls
        #expect(calls.count == 2)
        #expect(calls.last?.hour == 21)
        #expect(calls.last?.minute == 15)
    }

    // MARK: - Helpers

    private func makeViewModel(notifications: FakeNotificationService) -> SettingsViewModel {
        SettingsViewModel(
            authService: AuthService(backend: FakeAuthBackend()),
            notificationService: notifications,
            onSignedOut: {},
            onResetGoal: {}
        )
    }

    private var session: AuthSession {
        AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }
}
