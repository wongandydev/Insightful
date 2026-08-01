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

    // MARK: - Account linking

    @Test
    func linkAccountWhenSucceedsSetsLinkedEmailAndClearsPassword() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programLinkEmail(.success(()))
        let viewModel = makeViewModel(backend: backend)
        viewModel.linkEmailInput = "a@b.com"
        viewModel.linkPasswordInput = "hunter22"

        // When
        await viewModel.linkAccount()

        // Then
        #expect(viewModel.linkedEmail == "a@b.com")
        #expect(viewModel.linkPasswordInput.isEmpty)
        #expect(viewModel.linkMessage != nil)
        #expect(viewModel.linkErrorMessage == nil)
    }

    @Test
    func linkAccountWhenBackendThrowsSurfacesErrorAndKeepsInputs() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programLinkEmail(.failure(FakeError.network))
        let viewModel = makeViewModel(backend: backend)
        viewModel.linkEmailInput = "a@b.com"
        viewModel.linkPasswordInput = "hunter22"

        // When
        await viewModel.linkAccount()

        // Then
        #expect(viewModel.linkedEmail == nil)
        #expect(viewModel.linkErrorMessage != nil)
        #expect(viewModel.linkEmailInput == "a@b.com")
        #expect(viewModel.linkPasswordInput == "hunter22")
    }

    @Test
    func linkAccountWhenEmailMalformedRejectsWithoutCallingBackend() async {
        // Given
        let backend = FakeAuthBackend()
        let viewModel = makeViewModel(backend: backend)
        viewModel.linkEmailInput = "not-an-email"
        viewModel.linkPasswordInput = "hunter22"

        // When
        await viewModel.linkAccount()

        // Then
        let calls = await backend.linkEmailCalls
        #expect(calls.isEmpty)
        #expect(viewModel.linkErrorMessage != nil)
    }

    @Test
    func linkAccountWhenPasswordTooShortRejectsWithoutCallingBackend() async {
        // Given
        let backend = FakeAuthBackend()
        let viewModel = makeViewModel(backend: backend)
        viewModel.linkEmailInput = "a@b.com"
        viewModel.linkPasswordInput = "short"

        // When
        await viewModel.linkAccount()

        // Then
        let calls = await backend.linkEmailCalls
        #expect(calls.isEmpty)
        #expect(viewModel.linkErrorMessage != nil)
    }

    @Test
    func loadLinkedEmailHydratesFromBackend() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentUserEmail("me@example.com")
        let viewModel = makeViewModel(backend: backend)

        // When
        await viewModel.loadLinkedEmail()

        // Then
        #expect(viewModel.linkedEmail == "me@example.com")
    }

    // MARK: - Helpers

    private func makeViewModel(backend: FakeAuthBackend) -> SettingsViewModel {
        SettingsViewModel(
            authService: AuthService(backend: backend),
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
