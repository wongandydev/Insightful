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
    func generateInsightWhenMixedMetricsSerializesScalarAndSeries() throws {
        // Given / When
        let endpoint = try Endpoints.generateInsight(
            date: "2026-05-13",
            metrics: [
                "vo2Max": .scalar(48.2),
                "heartRateVariabilitySDNN": .series([52, 48, 61])
            ],
            workouts: [],
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
        #expect(json?["workouts"] == nil)
    }

    @Test
    func generateInsightWhenForcedAppendsForceQuery() throws {
        // Given / When
        let endpoint = try Endpoints.generateInsight(
            date: "2026-05-13",
            metrics: ["vo2Max": .scalar(48.2)],
            workouts: [],
            force: true
        )

        // Then
        #expect(endpoint.path == "/insight?force=true")
    }

    @Test
    func generateInsightWhenWorkoutsPresentSerializesSessionFields() throws {
        // Given / When
        let endpoint = try Endpoints.generateInsight(
            date: "2026-05-13",
            metrics: ["vo2Max": .scalar(48.2)],
            workouts: [
                WorkoutSummary(
                    activityType: "running",
                    date: "2026-05-12",
                    durationMinutes: 62.5,
                    distanceKm: 12.1,
                    energyKcal: 640,
                    averageHeartRate: nil
                )
            ],
            force: false
        )
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let workouts = try #require(json?["workouts"] as? [[String: Any]])

        // Then
        #expect(workouts.count == 1)
        #expect(workouts.first?["activityType"] as? String == "running")
        #expect(workouts.first?["date"] as? String == "2026-05-12")
        #expect(workouts.first?["durationMinutes"] as? Double == 62.5)
        #expect(workouts.first?["distanceKm"] as? Double == 12.1)
        #expect(workouts.first?["energyKcal"] as? Double == 640)
        #expect(workouts.first?["averageHeartRate"] == nil)
    }
}
