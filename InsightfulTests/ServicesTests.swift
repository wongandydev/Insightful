import Foundation
import Testing
@testable import Insightful

/// Each test verifies one behavior of a service. Coverage of *response*
/// decoding lives in `DTODecodingTests`; coverage of *endpoint building*
/// lives in `EndpointsTests`. These tests prove the service-to-endpoint
/// wiring.
@Suite
struct ServicesTests {
    let baseURL = URL(string: "https://api.test")!

    // MARK: - UserService

    @Test
    func userServiceSyncReturnsDecodedUserId() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"userId":"u-1"}"#.utf8),
            url: baseURL.appendingPathComponent("user")
        )
        let service = UserService(client: makeClient(mock: mock))

        // When
        let userId = try await service.sync()

        // Then
        #expect(userId == "u-1")
    }

    @Test
    func userServiceSyncHitsPostUser() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"userId":"u-1"}"#.utf8),
            url: baseURL.appendingPathComponent("user")
        )
        let service = UserService(client: makeClient(mock: mock))

        // When
        _ = try await service.sync()

        // Then
        let request = try #require(await mock.capturedRequests.first)
        #expect(request.url?.path == "/user")
        #expect(request.httpMethod == "POST")
    }

    // MARK: - GoalService

    @Test
    func goalServiceStartReturnsDecodedThreadId() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = #"{"threadId":"t-1","status":"in_progress","message":"hi"}"#
        await mock.enqueue(
            status: 200,
            body: Data(body.utf8),
            url: baseURL.appendingPathComponent("goal/start")
        )
        let service = GoalService(client: makeClient(mock: mock))

        // When
        let response = try await service.start(date: "2026-05-13")

        // Then
        #expect(response.threadId == "t-1")
        #expect(response.status == .inProgress)
    }

    @Test
    func goalServiceStartHitsPostGoalStartWithDate() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = #"{"threadId":"t-1","status":"in_progress","message":"hi"}"#
        await mock.enqueue(
            status: 200,
            body: Data(body.utf8),
            url: baseURL.appendingPathComponent("goal/start")
        )
        let service = GoalService(client: makeClient(mock: mock))

        // When
        _ = try await service.start(date: "2026-05-13")

        // Then
        let request = try #require(await mock.capturedRequests.first)
        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        #expect(request.url?.path == "/goal/start")
        #expect(request.httpMethod == "POST")
        #expect(json?["date"] as? String == "2026-05-13")
    }

    @Test
    func goalServiceSendMessageHitsPostGoalMessageWithAllFields() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = #"{"status":"in_progress","message":"ok","context":null}"#
        await mock.enqueue(
            status: 200,
            body: Data(body.utf8),
            url: baseURL.appendingPathComponent("goal/message")
        )
        let service = GoalService(client: makeClient(mock: mock))

        // When
        _ = try await service.sendMessage(threadId: "t-1", message: "hi", date: "2026-05-13")

        // Then
        let request = try #require(await mock.capturedRequests.first)
        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        #expect(request.url?.path == "/goal/message")
        #expect(request.httpMethod == "POST")
        #expect(json?["threadId"] as? String == "t-1")
        #expect(json?["message"] as? String == "hi")
        #expect(json?["date"] as? String == "2026-05-13")
    }

    @Test
    func goalServiceGetContextHitsGetGoalContext() async throws {
        // Given
        let mock = MockHTTPClient()
        await mock.enqueue(
            status: 200,
            body: Data(#"{"hasContext":false,"context":null}"#.utf8),
            url: baseURL.appendingPathComponent("goal/context")
        )
        let service = GoalService(client: makeClient(mock: mock))

        // When
        _ = try await service.getContext()

        // Then
        let request = try #require(await mock.capturedRequests.first)
        #expect(request.url?.path == "/goal/context")
        #expect(request.httpMethod == "GET")
    }

    // MARK: - InsightService

    @Test
    func insightServiceGenerateHitsPostInsightWithDateAndMetrics() async throws {
        // Given
        let mock = MockHTTPClient()
        let body = #"""
        {"cached":false,"insight":{"insightText":"ok","alerts":[],"chartsToShow":[],"recommendedActions":[]}}
        """#
        await mock.enqueue(
            status: 200,
            body: Data(body.utf8),
            url: baseURL.appendingPathComponent("insight")
        )
        let service = InsightService(client: makeClient(mock: mock))

        // When
        _ = try await service.generate(
            date: "2026-05-13",
            metrics: ["vo2Max": .scalar(48.2)]
        )

        // Then
        let request = try #require(await mock.capturedRequests.first)
        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        let metrics = try #require(json?["metrics"] as? [String: Any])
        #expect(request.url?.path == "/insight")
        #expect(request.httpMethod == "POST")
        #expect(json?["date"] as? String == "2026-05-13")
        #expect(metrics["vo2Max"] as? Double == 48.2)
    }

    // MARK: - Helpers

    private func makeClient(mock: MockHTTPClient) -> APIClient {
        APIClient(
            baseURL: baseURL,
            httpClient: mock,
            tokenProvider: { "t" },
            refreshToken: {}
        )
    }
}
