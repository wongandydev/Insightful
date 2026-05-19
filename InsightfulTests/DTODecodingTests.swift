import Foundation
import Testing
@testable import Insightful

@Suite
struct DTODecodingTests {

    // MARK: - GoalContext

    /// Golden fixture matching the `goal_complete` payload in `IOS_CONTRACT.md` § 3.
    @Test
    func goalContextWhenContractFixtureDecodesAllFields() throws {
        // Given
        let json = """
        {
          "goalType": "endurance_event",
          "goalSummary": "Marathon under 4 hours",
          "targetDate": "2026-10-15",
          "motivation": "personal milestone",
          "currentState": "running 25mi/wk",
          "biggestConcern": "injury history",
          "lifestyle": "desk job",
          "previouslyTried": "couch-to-5k",
          "injuriesOrLimitations": "left knee tendonitis",
          "priorityMetrics": ["heartRateVariabilitySDNN", "restingHeartRate"],
          "sportsOrActivities": ["running"],
          "subGoals": ["build base mileage", "stay injury free"]
        }
        """

        // When
        let context = try JSONCoding.decoder.decode(GoalContext.self, from: Data(json.utf8))

        // Then
        #expect(context.goalType == .enduranceEvent)
        #expect(context.goalSummary == "Marathon under 4 hours")
        #expect(context.targetDate == "2026-10-15")
        #expect(context.previouslyTried == "couch-to-5k")
        #expect(context.injuriesOrLimitations == "left knee tendonitis")
        #expect(context.priorityMetrics == ["heartRateVariabilitySDNN", "restingHeartRate"])
        #expect(context.sportsOrActivities == ["running"])
        #expect(context.subGoals.count == 2)
    }

    @Test
    func goalContextWhenOptionalsAreNullDecodesAsNil() throws {
        // Given
        let json = """
        {
          "goalType": "general_fitness",
          "goalSummary": "feel better",
          "targetDate": null,
          "motivation": "energy",
          "currentState": "sedentary",
          "biggestConcern": "consistency",
          "lifestyle": "remote",
          "previouslyTried": null,
          "injuriesOrLimitations": null,
          "priorityMetrics": [],
          "sportsOrActivities": [],
          "subGoals": []
        }
        """

        // When
        let context = try JSONCoding.decoder.decode(GoalContext.self, from: Data(json.utf8))

        // Then
        #expect(context.targetDate == nil)
        #expect(context.previouslyTried == nil)
        #expect(context.injuriesOrLimitations == nil)
    }

    // MARK: - GoalMessageResponse

    @Test
    func goalMessageResponseWhenInProgressDecodesWithoutContext() throws {
        // Given
        let json = """
        { "status": "in_progress", "message": "what's your target?", "context": null }
        """

        // When
        let response = try JSONCoding.decoder.decode(
            GoalMessageResponse.self,
            from: Data(json.utf8)
        )

        // Then
        #expect(response.status == .inProgress)
        #expect(response.message == "what's your target?")
        #expect(response.context == nil)
    }

    @Test
    func goalMessageResponseWhenGoalCompleteDecodesEmbeddedContext() throws {
        // Given
        let json = """
        {
          "status": "goal_complete",
          "message": "got it",
          "context": {
            "goalType": "weight_loss",
            "goalSummary": "lose 10lb",
            "targetDate": null,
            "motivation": "health",
            "currentState": "180lb",
            "biggestConcern": "plateau",
            "lifestyle": "active",
            "previouslyTried": null,
            "injuriesOrLimitations": null,
            "priorityMetrics": ["bodyMass"],
            "sportsOrActivities": ["walking"],
            "subGoals": []
          }
        }
        """

        // When
        let response = try JSONCoding.decoder.decode(
            GoalMessageResponse.self,
            from: Data(json.utf8)
        )

        // Then
        #expect(response.status == .goalComplete)
        #expect(response.context?.goalType == .weightLoss)
        #expect(response.context?.priorityMetrics == ["bodyMass"])
    }

    // MARK: - GoalContextResponse

    @Test
    func goalContextResponseWhenNoContextDecodesHasContextFalse() throws {
        // Given
        let json = #"{"hasContext":false,"context":null}"#

        // When
        let response = try JSONCoding.decoder.decode(
            GoalContextResponse.self,
            from: Data(json.utf8)
        )

        // Then
        #expect(response.hasContext == false)
        #expect(response.context == nil)
    }

    // MARK: - InsightResponse

    @Test
    func insightResponseWhenContractFixtureDecodesAllFields() throws {
        // Given
        let json = """
        {
          "cached": false,
          "insight": {
            "insightText": "Recovery is trending up.",
            "alerts": ["sleep dipped Tuesday"],
            "chartsToShow": ["heartRateVariabilitySDNN", "restingHeartRate"],
            "recommendedActions": ["aim for 7.5h tonight"]
          }
        }
        """

        // When
        let response = try JSONCoding.decoder.decode(
            InsightResponse.self,
            from: Data(json.utf8)
        )

        // Then
        #expect(response.cached == false)
        #expect(response.insight.insightText == "Recovery is trending up.")
        #expect(response.insight.chartsToShow == ["heartRateVariabilitySDNN", "restingHeartRate"])
        #expect(response.insight.recommendedActions == ["aim for 7.5h tonight"])
    }

    // MARK: - LocalCalendarDate

    @Test
    func localCalendarDateWhenGivenDateFormatsAsYYYYMMDD() {
        // Given
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 13
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When
        let formatted = LocalCalendarDate.string(from: date)

        // Then
        #expect(formatted == "2026-05-13")
    }
}
