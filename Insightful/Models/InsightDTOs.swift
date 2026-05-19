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
}
