import Foundation
import Testing
@testable import Insightful

@Suite
struct EndpointsTests {

    @Test
    func healthWhenBuiltIsGetWithoutAuth() {
        // Given / When
        let endpoint = Endpoints.health()

        // Then
        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/health")
        #expect(endpoint.requiresAuth == false)
        #expect(endpoint.body == nil)
    }

    @Test
    func syncUserWhenBuiltIsPostWithEmptyBody() {
        // Given / When
        let endpoint = Endpoints.syncUser()

        // Then
        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/user")
        #expect(endpoint.requiresAuth == true)
        #expect(endpoint.body == nil)
    }

    @Test
    func startGoalWhenBuiltEncodesDateInBody() throws {
        // Given / When
        let endpoint = try Endpoints.startGoal(date: "2026-05-13")
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        // Then
        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/goal/start")
        #expect(endpoint.requiresAuth == true)
        #expect(json?["date"] as? String == "2026-05-13")
    }

    @Test
    func sendGoalMessageWhenBuiltEncodesThreadIdMessageAndDate() throws {
        // Given / When
        let endpoint = try Endpoints.sendGoalMessage(
            threadId: "t-1",
            message: "hi",
            date: "2026-05-13"
        )
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        // Then
        #expect(endpoint.path == "/goal/message")
        #expect(json?["threadId"] as? String == "t-1")
        #expect(json?["message"] as? String == "hi")
        #expect(json?["date"] as? String == "2026-05-13")
    }

    @Test
    func getGoalContextWhenBuiltIsGetRequiringAuth() {
        // Given / When
        let endpoint = Endpoints.getGoalContext()

        // Then
        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/goal/context")
        #expect(endpoint.requiresAuth == true)
        #expect(endpoint.body == nil)
    }

    @Test
    func startAdviceWhenBuiltIsPostWithNoBodyRequiringAuth() {
        // Given / When
        let endpoint = Endpoints.startAdvice()

        // Then
        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/advice/start")
        #expect(endpoint.requiresAuth == true)
        #expect(endpoint.body == nil)
    }

    @Test
    func sendAdviceMessageWhenMetricsNilOmitsMetricsKey() throws {
        // Given / When
        let endpoint = try Endpoints.sendAdviceMessage(
            threadId: "t-1",
            message: "How's my recovery?",
            date: "2026-07-10",
            metrics: nil
        )
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        // Then
        #expect(endpoint.path == "/advice/message")
        #expect(json?["threadId"] as? String == "t-1")
        #expect(json?["message"] as? String == "How's my recovery?")
        #expect(json?["date"] as? String == "2026-07-10")
        #expect(json?["metrics"] == nil)
    }

    @Test
    func sendAdviceMessageWhenMetricsPresentSerializesThem() throws {
        // Given / When
        let endpoint = try Endpoints.sendAdviceMessage(
            threadId: "t-1",
            message: "hi",
            date: "2026-07-10",
            metrics: ["heartRateVariabilitySDNN": .series([52, 48, 61])]
        )
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let metrics = try #require(json?["metrics"] as? [String: Any])

        // Then
        #expect(metrics["heartRateVariabilitySDNN"] as? [Double] == [52, 48, 61])
    }

    @Test
    func generateInsightWhenMixedMetricsSerializesScalarAndSeries() throws {
        // Given / When
        let endpoint = try Endpoints.generateInsight(
            date: "2026-05-13",
            metrics: [
                "vo2Max": .scalar(48.2),
                "heartRateVariabilitySDNN": .series([52, 48, 61])
            ],
            force: false
        )
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let metrics = try #require(json?["metrics"] as? [String: Any])

        // Then
        #expect(endpoint.path == "/insight")
        #expect(json?["date"] as? String == "2026-05-13")
        #expect(metrics["vo2Max"] as? Double == 48.2)
        #expect(metrics["heartRateVariabilitySDNN"] as? [Double] == [52, 48, 61])
    }

    @Test
    func generateInsightWhenForcedAppendsForceQuery() throws {
        // Given / When
        let endpoint = try Endpoints.generateInsight(
            date: "2026-05-13",
            metrics: ["vo2Max": .scalar(48.2)],
            force: true
        )

        // Then
        #expect(endpoint.path == "/insight?force=true")
    }
}
