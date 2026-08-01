import Foundation
@testable import Insightful

/// Scriptable auth backend for `AuthServiceTests`. Each operation can be
/// programmed independently to succeed with a given session or throw.
actor FakeAuthBackend: AuthBackend {
    enum Scenario: Sendable {
        case returns(AuthSession)
        case returnsNil
        case throws_(any Error & Sendable)
    }

    private var currentSessionResult: Scenario = .returnsNil
    private var signInResult: Scenario = .throws_(FakeError.notProgrammed)
    private var refreshResult: Scenario = .throws_(FakeError.notProgrammed)
    private var signOutResult: Result<Void, any Error & Sendable> = .success(())
    private var linkEmailResult: Result<Void, any Error & Sendable> = .success(())
    private var currentUserEmailResult: String? = nil

    private(set) var currentSessionCalls = 0
    private(set) var signInCalls = 0
    private(set) var refreshCalls = 0
    private(set) var signOutCalls = 0
    private(set) var linkEmailCalls: [(email: String, password: String)] = []

    func programCurrentSession(_ scenario: Scenario) { currentSessionResult = scenario }
    func programSignIn(_ scenario: Scenario) { signInResult = scenario }
    func programRefresh(_ scenario: Scenario) { refreshResult = scenario }
    func programSignOut(_ result: Result<Void, any Error & Sendable>) { signOutResult = result }
    func programLinkEmail(_ result: Result<Void, any Error & Sendable>) { linkEmailResult = result }
    func programCurrentUserEmail(_ email: String?) { currentUserEmailResult = email }

    func currentSession() async throws -> AuthSession? {
        currentSessionCalls += 1
        return try unwrapOptional(currentSessionResult)
    }

    func signInAnonymously() async throws -> AuthSession {
        signInCalls += 1
        return try unwrapRequired(signInResult)
    }

    func refreshSession() async throws -> AuthSession {
        refreshCalls += 1
        return try unwrapRequired(refreshResult)
    }

    func signOut() async throws {
        signOutCalls += 1
        try signOutResult.get()
    }

    func linkEmail(email: String, password: String) async throws {
        linkEmailCalls.append((email: email, password: password))
        try linkEmailResult.get()
    }

    func currentUserEmail() async -> String? {
        currentUserEmailResult
    }

    private func unwrapOptional(_ scenario: Scenario) throws -> AuthSession? {
        switch scenario {
        case .returns(let session): return session
        case .returnsNil: return nil
        case .throws_(let error): throw error
        }
    }

    private func unwrapRequired(_ scenario: Scenario) throws -> AuthSession {
        switch scenario {
        case .returns(let session): return session
        case .returnsNil: throw FakeError.notProgrammed
        case .throws_(let error): throw error
        }
    }
}

enum FakeError: Error, Equatable {
    case notProgrammed
    case network
}
