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
