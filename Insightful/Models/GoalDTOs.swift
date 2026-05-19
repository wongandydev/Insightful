import Foundation

// MARK: - Goal status

enum GoalStatus: String, Decodable {
    case inProgress = "in_progress"
    case goalComplete = "goal_complete"
}

// MARK: - /goal/start

struct GoalStartRequest: Encodable, Equatable {
    let date: String
}

struct GoalStartResponse: Decodable, Equatable {
    let threadId: String
    let status: GoalStatus
    let message: String
}

// MARK: - /goal/message

struct GoalMessageRequest: Encodable, Equatable {
    let threadId: String
    let message: String
    let date: String
}

struct GoalMessageResponse: Decodable, Equatable {
    let status: GoalStatus
    let message: String
    let context: GoalContext?
}

// MARK: - /goal/context

struct GoalContextResponse: Decodable, Equatable {
    let hasContext: Bool
    let context: GoalContext?
}

// MARK: - GoalContext (snake_case on the wire)

enum GoalType: String, Codable, Equatable {
    case enduranceEvent = "endurance_event"
    case weightLoss = "weight_loss"
    case sleepImprovement = "sleep_improvement"
    case generalFitness = "general_fitness"
    case strength
    case other
}

struct GoalContext: Decodable, Equatable {
    let goalType: GoalType
    let goalSummary: String
    let targetDate: String?
    let motivation: String
    let currentState: String
    let biggestConcern: String
    let lifestyle: String
    let previouslyTried: String?
    let injuriesOrLimitations: String?
    let priorityMetrics: [String]
    let sportsOrActivities: [String]
    let subGoals: [String]
}
