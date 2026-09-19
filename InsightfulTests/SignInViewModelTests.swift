import AuthenticationServices
import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct SignInViewModelTests {

    @Test
    func signInWithEmailWhenSucceedsNotifiesParentAndClearsPassword() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programSignInEmail(.returns(session))
        var signedInCount = 0
        let viewModel = makeViewModel(backend: backend, onSignedIn: { signedInCount += 1 })
        viewModel.emailInput = " runner@example.com "
        viewModel.passwordInput = "hunter2hunter2"

        // When
        await viewModel.signInWithEmail()

        // Then
        let calls = await backend.signInEmailCalls
        #expect(calls.count == 1)
        #expect(calls.first?.email == "runner@example.com")
        #expect(signedInCount == 1)
        #expect(viewModel.passwordInput.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func signInWithEmailWhenCredentialsRejectedSurfacesErrorAndKeepsParentUnnotified() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programSignInEmail(.throws_(SignInError.invalidCredentials))
        var signedInCount = 0
        let viewModel = makeViewModel(backend: backend, onSignedIn: { signedInCount += 1 })
        viewModel.emailInput = "runner@example.com"
        viewModel.passwordInput = "wrong-password"

        // When
        await viewModel.signInWithEmail()

        // Then
        #expect(viewModel.errorMessage == "Email or password is incorrect.")
        #expect(signedInCount == 0)
        #expect(!viewModel.isWorking)
    }

    @Test
    func signInWithEmailWhenFieldsEmptyRejectsWithoutCallingBackend() async {
        // Given
        let backend = FakeAuthBackend()
        let viewModel = makeViewModel(backend: backend, onSignedIn: {})
        viewModel.emailInput = "   "
        viewModel.passwordInput = ""

        // When
        await viewModel.signInWithEmail()

        // Then
        #expect(await backend.signInEmailCalls.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func signInWithEmailWhenBackendThrowsSurfacesGenericError() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programSignInEmail(.throws_(FakeError.network))
        let viewModel = makeViewModel(backend: backend, onSignedIn: {})
        viewModel.emailInput = "runner@example.com"
        viewModel.passwordInput = "hunter2hunter2"

        // When
        await viewModel.signInWithEmail()

        // Then
        #expect(viewModel.errorMessage == "Couldn't sign in. Try again.")
    }

    @Test
    func appleRequestNonceMarksSignInInFlight() {
        // Given
        let viewModel = makeViewModel(backend: FakeAuthBackend(), onSignedIn: {})

        // When
        _ = viewModel.appleRequestNonce()

        // Then
        #expect(viewModel.isWorking)
    }

    @Test
    func handleAppleAuthorizationWhenCancelledStaysSilentAndEndsInFlight() async {
        // Given
        let viewModel = makeViewModel(backend: FakeAuthBackend(), onSignedIn: {})
        _ = viewModel.appleRequestNonce()

        // When
        await viewModel.handleAppleAuthorization(.failure(ASAuthorizationError(.canceled)))

        // Then
        #expect(!viewModel.isWorking)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func handleAppleAuthorizationWhenFailedSurfacesError() async {
        // Given
        let viewModel = makeViewModel(backend: FakeAuthBackend(), onSignedIn: {})
        _ = viewModel.appleRequestNonce()

        // When
        await viewModel.handleAppleAuthorization(.failure(ASAuthorizationError(.failed)))

        // Then
        #expect(viewModel.errorMessage == "Couldn't sign in with Apple. Try again.")
        #expect(!viewModel.isWorking)
    }

    @Test
    func continueAnonymouslySignsInAnonymouslyThenNotifiesParent() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programSignIn(.returns(session))
        var signedInCount = 0
        let viewModel = makeViewModel(backend: backend, onSignedIn: { signedInCount += 1 })

        // When
        await viewModel.continueAnonymously()

        // Then — the screen mints the identity itself; `bootstrap()` reports
        // `.sessionLost` on this device and would route straight back here.
        #expect(await backend.signInCalls == 1)
        #expect(signedInCount == 1)
        #expect(await backend.signInEmailCalls.isEmpty)
    }

    @Test("continueAnonymously surfaces an error and does not advance when sign-in fails")
    func continueAnonymouslyFailureKeepsUserOnScreen() async {
        // Given
        let backend = FakeAuthBackend()
        await backend.programSignIn(.throws_(FakeError.notProgrammed))
        var signedInCount = 0
        let viewModel = makeViewModel(backend: backend, onSignedIn: { signedInCount += 1 })

        // When
        await viewModel.continueAnonymously()

        // Then
        #expect(signedInCount == 0)
        #expect(viewModel.errorMessage == "Couldn't continue. Try again.")
        #expect(viewModel.isWorking == false)
    }

    // MARK: - Helpers

    private func makeViewModel(
        backend: FakeAuthBackend,
        onSignedIn: @escaping () -> Void
    ) -> SignInViewModel {
        SignInViewModel(
            authService: AuthService(backend: backend, userDefaults: ephemeralDefaults()),
            onSignedIn: onSignedIn
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
