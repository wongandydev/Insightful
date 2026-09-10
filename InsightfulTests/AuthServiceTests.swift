import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct AuthServiceTests {

    let initialSession = AuthSession(
        accessToken: "access-1",
        refreshToken: "refresh-1",
        expiresAt: Date(timeIntervalSince1970: 1_900_000_000)
    )

    let refreshedSession = AuthSession(
        accessToken: "access-2",
        refreshToken: "refresh-2",
        expiresAt: Date(timeIntervalSince1970: 1_900_003_600)
    )

    // MARK: - Bootstrap

    @Test("bootstrap reports .ready on a device that has never authenticated")
    func bootstrapOnFirstLaunchReportsReady() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        let outcome = try await service.bootstrap()

        // Then
        #expect(outcome == .ready)
    }

    @Test("bootstrap offers sign-in rather than a replacement identity when a known device loses its session")
    func bootstrapWhenKnownDeviceLosesSessionReportsSessionLost() async throws {
        // Given — a first launch that created an anonymous identity.
        let defaults = ephemeralDefaults()
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        _ = try await AuthService(backend: backend, userDefaults: defaults).bootstrap()

        // When — the server terminated that session, so the SDK reports none.
        let relaunched = AuthService(backend: backend, userDefaults: defaults)
        let outcome = try await relaunched.bootstrap()

        // Then — no second identity is minted; the first one's data stays reachable.
        #expect(outcome == .sessionLost)
        #expect(await backend.signInCalls == 1)
        #expect(relaunched.session == nil)
        #expect(relaunched.isReady == false)
    }

    @Test("continueAnonymously mints a new identity after a lost session")
    func continueAnonymouslyAfterSessionLossSignsIn() async throws {
        // Given
        let defaults = ephemeralDefaults()
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        _ = try await AuthService(backend: backend, userDefaults: defaults).bootstrap()
        let relaunched = AuthService(backend: backend, userDefaults: defaults)
        #expect(try await relaunched.bootstrap() == .sessionLost)

        // When
        try await relaunched.continueAnonymously()

        // Then
        #expect(relaunched.session == initialSession)
        #expect(relaunched.isReady)
        #expect(await backend.signInCalls == 2)
    }

    @Test("signing out leaves the device known, so the next launch offers sign-in")
    func bootstrapAfterSignOutReportsSessionLost() async throws {
        // Given
        let defaults = ephemeralDefaults()
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        let service = AuthService(backend: backend, userDefaults: defaults)
        _ = try await service.bootstrap()
        try await service.signOut()

        // When
        let outcome = try await AuthService(backend: backend, userDefaults: defaults).bootstrap()

        // Then
        #expect(outcome == .sessionLost)
    }

    @Test
    func bootstrapWhenNoCachedSessionSignsInAnonymously() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        _ = try await service.bootstrap()

        // Then
        #expect(service.session == initialSession)
        #expect(service.accessToken == "access-1")
        #expect(service.isReady)
        #expect(await backend.signInCalls == 1)
    }

    @Test
    func bootstrapWhenCachedSessionRestoresWithoutSigningIn() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        _ = try await service.bootstrap()

        // Then
        #expect(service.session == initialSession)
        #expect(service.isReady)
        #expect(await backend.signInCalls == 0)
    }

    @Test
    func bootstrapWhenSessionRestoreThrowsDoesNotCreateNewAnonymousUser() async throws {
        // Given — a throwing restore (e.g. failed network refresh of an
        // expired token) must NOT be treated as "no session": signing in
        // anonymously would overwrite the Keychain and orphan the user's data
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.throws_(FakeError.network))
        await backend.programSignIn(.returns(initialSession))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        let threw: Bool
        do {
            _ = try await service.bootstrap()
            threw = false
        } catch {
            threw = true
        }

        // Then
        #expect(threw)
        #expect(await backend.signInCalls == 0)
        #expect(service.session == nil)
        #expect(service.isReady == false)
    }

    @Test
    func linkEmailForwardsCredentialsToBackend() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programLinkEmail(.success(()))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        try await service.linkEmail(email: "a@b.com", password: "hunter22")

        // Then
        let calls = await backend.linkEmailCalls
        #expect(calls.count == 1)
        #expect(calls.first?.email == "a@b.com")
        #expect(calls.first?.password == "hunter22")
    }

    @Test
    func bootstrapWhenSignInThrowsLeavesServiceNotReady() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.throws_(FakeError.network))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When
        let error = await capturedError { _ = try await service.bootstrap() }

        // Then
        #expect(error == FakeError.network)
        #expect(service.session == nil)
        #expect(service.isReady == false)
    }

    // MARK: - Refresh

    @Test
    func refreshWhenSucceedsReplacesSession() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        await backend.programRefresh(.returns(refreshedSession))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())
        _ = try await service.bootstrap()

        // When
        try await service.refresh()

        // Then
        #expect(service.session == refreshedSession)
        #expect(service.accessToken == "access-2")
    }

    @Test
    func refreshWhenBackendThrowsKeepsPriorSession() async throws {
        // Decision (b): a transient refresh failure must not blow away the
        // cached session — APIClient will surface .unauthorized to the view
        // for the user to retry.

        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        await backend.programRefresh(.throws_(FakeError.network))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())
        _ = try await service.bootstrap()

        // When
        let error = await capturedError { try await service.refresh() }

        // Then
        #expect(error == FakeError.network)
        #expect(service.session == initialSession, "prior session should remain intact")
    }

    // MARK: - signOut

    @Test
    func signOutWhenSucceedsClearsSession() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        await backend.programSignOut(.success(()))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())
        _ = try await service.bootstrap()

        // When
        try await service.signOut()

        // Then
        #expect(service.session == nil)
        #expect(service.isReady == false)
        #expect(await backend.signOutCalls == 1)
    }

    @Test
    func signOutWhenBackendThrowsKeepsSession() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        await backend.programSignOut(.failure(FakeError.network))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())
        _ = try await service.bootstrap()

        // When
        let error = await capturedError { try await service.signOut() }

        // Then
        #expect(error == FakeError.network)
        #expect(service.session == initialSession, "session should remain on backend failure")
    }

    // MARK: - accessToken

    @Test
    func accessTokenWhenNoSessionReturnsNil() {
        // Given
        let backend = FakeAuthBackend()
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())

        // When / Then
        #expect(service.accessToken == nil)
    }

    // MARK: - Sign in with Apple

    @Test
    func linkAppleWhenIdentityAlreadyInUsePropagatesIdentityLinkError() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returns(initialSession))
        await backend.programLinkApple(.failure(IdentityLinkError.identityAlreadyInUse))
        let service = AuthService(backend: backend, userDefaults: ephemeralDefaults())
        _ = try await service.bootstrap()

        // When
        var captured: IdentityLinkError?
        do {
            try await service.linkApple(idToken: "id-token", nonce: "raw-nonce")
        } catch let error as IdentityLinkError {
            captured = error
        }

        // Then
        #expect(captured == .identityAlreadyInUse)
        #expect(service.session == initialSession)
    }

    // MARK: - Helpers

    private func capturedError(_ block: () async throws -> Void) async -> FakeError? {
        do {
            try await block()
            return nil
        } catch let error as FakeError {
            return error
        } catch {
            return nil
        }
    }
}
