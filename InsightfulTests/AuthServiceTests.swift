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

    @Test
    func bootstrapWhenNoCachedSessionSignsInAnonymously() async throws {
        // Given
        let backend = FakeAuthBackend()
        await backend.programCurrentSession(.returnsNil)
        await backend.programSignIn(.returns(initialSession))
        let service = AuthService(backend: backend)

        // When
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)

        // When
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)

        // When
        let threw: Bool
        do {
            try await service.bootstrap()
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
        let service = AuthService(backend: backend)

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
        let service = AuthService(backend: backend)

        // When
        let error = await capturedError { try await service.bootstrap() }

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
        let service = AuthService(backend: backend)
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)
        try await service.bootstrap()

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
        let service = AuthService(backend: backend)

        // When / Then
        #expect(service.accessToken == nil)
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
