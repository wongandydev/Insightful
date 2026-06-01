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
            onSignedOut: {},
            onResetGoal: { resetCount += 1 }
        )

        // When
        viewModel.resetGoal()

        // Then
        #expect(resetCount == 1)
    }

    // MARK: - Helpers

    private var session: AuthSession {
        AuthSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }
}
