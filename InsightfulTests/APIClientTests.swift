import Foundation
import Testing
@testable import Insightful

@Suite
struct APIClientTests {
    let baseURL = URL(string: "https://api.test")!
    var url: URL { baseURL.appendingPathComponent("user") }

    // MARK: - Success path

    @Test
    func sendWhenStatus200ReturnsDecodedResponse() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 200, body: Data(#"{"userId":"abc-123"}"#.utf8), url: url)
        let client = makeClient(mock: mock)

        // When
        let response = try await client.send(Endpoints.syncUser())

        // Then
        #expect(response.userId == "abc-123")
    }

    // MARK: - Auth header injection

    @Test
    func sendWhenRequiresAuthAttachesBearerToken() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 200, body: Data(#"{"userId":"x"}"#.utf8), url: url)
        let client = makeClient(mock: mock, token: "the-jwt")

        // When
        _ = try await client.send(Endpoints.syncUser())

        // Then
        let captured = await mock.capturedRequests
        #expect(captured.first?.value(forHTTPHeaderField: "Authorization") == "Bearer the-jwt")
    }

    @Test
    func sendWhenAuthNotRequiredOmitsBearerToken() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 200, body: Data(#"{"status":"ok"}"#.utf8), url: url)
        let client = makeClient(mock: mock, token: "should-not-be-used")

        // When
        _ = try await client.send(Endpoints.health())

        // Then
        let captured = await mock.capturedRequests
        #expect(captured.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - Status code mapping

    @Test
    func sendWhenStatus400ThrowsBadRequestWithIssues() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = Data(#"{"error":"invalid","issues":["date is required"]}"#.utf8)
        await mock.enqueue(status: 400, headers: ["X-Request-Id": "req-1"], body: body, url: url)
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.badRequest(
            message: "invalid",
            issues: ["date is required"],
            requestId: "req-1"
        )) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenStatus403ThrowsForbidden() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 403, headers: ["X-Request-Id": "r"], url: url)
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.forbidden(requestId: "r")) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenStatus409ThrowsConflictWithMessage() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = Data(#"{"error":"thread already complete"}"#.utf8)
        await mock.enqueue(status: 409, body: body, url: url)
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.conflict(
            message: "thread already complete",
            requestId: nil
        )) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenStatus413ThrowsPayloadTooLarge() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 413, url: url)
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.payloadTooLarge(requestId: nil)) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenStatus429ThrowsRateLimitedWithRetryAfter() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 429,
            headers: ["Retry-After": "30", "X-Request-Id": "r-9"],
            url: url
        )
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.rateLimited(retryAfterSeconds: 30, requestId: "r-9")) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenStatus5xxThrowsServerError() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 503, url: url)
        let client = makeClient(mock: mock, token: "t")

        // When / Then
        await #expect(throws: APIError.server(status: 503, requestId: nil)) {
            _ = try await client.send(Endpoints.syncUser())
        }
    }

    @Test
    func sendWhenResponseUnparseableThrowsDecodingError() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 200, body: Data("not-json".utf8), url: url)
        let client = makeClient(mock: mock, token: "t")

        // When
        let error = await capturedError { try await client.send(Endpoints.syncUser()) }

        // Then
        if case .decoding = error {
            #expect(Bool(true))
        } else {
            Issue.record("expected APIError.decoding, got \(String(describing: error))")
        }
    }

    // MARK: - 401 refresh-and-retry
    //
    // We prove refresh happened *and* was used by rotating the token in the
    // refresh closure and checking the second request carried the new token.
    // No counter, no lock — the captured requests on the mock are enough.

    @Test
    func sendWhenStatus401RotatesTokenAndRetriesOnceWithRefreshedHeader() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 401, url: url)
        await mock.enqueue(status: 200, body: Data(#"{"userId":"x"}"#.utf8), url: url)
        let token = TokenSource(initial: "old")
        let client = APIClient(
            baseURL: baseURL,
            httpClient: mock,
            tokenProvider: { await token.current },
            refreshToken: { await token.rotate(to: "new") }
        )

        // When
        let response = try await client.send(Endpoints.syncUser())

        // Then
        let requests = await mock.capturedRequests
        #expect(response.userId == "x")
        #expect(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test
    func sendWhenStatus401AfterRefreshThrowsUnauthorizedAndStopsRetrying() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(status: 401, headers: ["X-Request-Id": "r"], url: url)
        await mock.enqueue(status: 401, headers: ["X-Request-Id": "r"], url: url)
        let client = makeClient(mock: mock, token: "t")

        // When
        let error = await capturedError { try await client.send(Endpoints.syncUser()) }

        // Then
        let requests = await mock.capturedRequests
        #expect(error == APIError.unauthorized(requestId: "r"))
        #expect(requests.count == 2, "should not retry more than once")
    }

    // MARK: - Helpers

    private func makeClient(mock: MockHTTPClient, token: String? = nil) -> APIClient {
        APIClient(
            baseURL: baseURL,
            httpClient: mock,
            tokenProvider: { token },
            refreshToken: {}
        )
    }

    /// Captures any thrown `APIError` from an async closure, returning `nil` if
    /// it didn't throw. Lets us split When (the call) from Then (the assert).
    private func capturedError(_ block: () async throws -> Void) async -> APIError? {
        do {
            try await block()
            return nil
        } catch let error as APIError {
            return error
        } catch {
            return nil
        }
    }
}

/// Test-only token holder. Actor isolation instead of a lock.
actor TokenSource {
    private(set) var current: String

    init(initial: String) {
        self.current = initial
    }

    func rotate(to value: String) {
        current = value
    }
}
