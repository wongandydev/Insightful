import Foundation

/// A single HealthKit metric value: either a scalar or up to 31 daily samples.
/// Server accepts both shapes; we keep both representable on the client.
enum MetricValue: Encodable, Equatable {
    case scalar(Double)
    case series([Double])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .scalar(let v): try container.encode(v)
        case .series(let v): try container.encode(v)
        }
    }
}

struct InsightRequest: Encodable, Equatable {
    let date: String
    let metrics: [String: MetricValue]
}

struct InsightResponse: Decodable, Equatable {
    let cached: Bool
    let insight: Insight
}

struct Insight: Decodable, Equatable {
    let insightText: String
    let alerts: [String]
    let chartsToShow: [String]
    let recommendedActions: [String]
    let progress: InsightProgress?
}

/// Deterministic progress facts computed server-side from the goal context.
///
/// Cached on the same `(userId, date)` lifecycle as the rest of the insight —
/// regenerated when the insight is refreshed, not on every screen open.
struct InsightProgress: Decodable, Equatable {
    /// Calendar days from today to ``GoalContext/targetDate``. `nil` when the
    /// goal has no target date.
    let daysUntilTarget: Int?
    /// Only subgoals whose strings contained a parseable numeric target. May
    /// be empty when no subgoal parses cleanly — the view shows the days
    /// callout regardless.
    let subgoals: [InsightSubgoalProgress]
}

/// A single subgoal with a parsed target (e.g. text "Sub-3 marathon",
/// target "3h"). The current value is not yet computed — surfacing pace
/// requires mapping subgoals to specific metrics, which is out of scope
/// for this iteration.
struct InsightSubgoalProgress: Decodable, Equatable {
    let text: String
    let target: String
}
