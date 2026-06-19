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

/// Which branch the server took when handling `/goal/start`. iOS uses this
/// to decide UI cues — `resumed` triggers the "Picking up where you left off"
/// banner; `refined` already has the synthetic refinement prompt at the
/// bottom of the transcript; `created` shows nothing extra.
enum GoalStartMode: String, Decodable, Equatable {
    case created
    case resumed
    case refined
}

struct GoalStartResponse: Decodable, Equatable {
    let threadId: String
    let status: GoalStatus
    let mode: GoalStartMode
    let messages: [GoalMessage]
}

enum GoalMessageRole: String, Decodable, Equatable {
    case user
    case assistant
}

struct GoalMessage: Decodable, Equatable {
    let role: GoalMessageRole
    let content: String
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

// MARK: - GoalContext

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
    /// Agent-written, goal-specific explanation of why the app reads Apple
    /// Health, shown on ``HealthKitPermissionView``. Optional because goal
    /// contexts saved before this field existed lack it — the view falls back
    /// to its static copy when this is `nil`.
    let rationale: String?
}
