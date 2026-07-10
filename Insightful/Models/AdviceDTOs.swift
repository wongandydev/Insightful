import Foundation

// MARK: - /advice/start

/// Which branch the server took when handling `/advice/start`. `resumed`
/// means prior coach turns exist and the transcript arrives pre-populated;
/// `created` returns just the hardcoded opener.
enum AdviceStartMode: String, Decodable, Equatable {
    case created
    case resumed
}

struct AdviceStartResponse: Decodable, Equatable {
    let threadId: String
    let mode: AdviceStartMode
    let messages: [GoalMessage]
}

// MARK: - /advice/message

struct AdviceMessageRequest: Encodable, Equatable {
    let threadId: String
    let message: String
    let date: String
    /// Recent HealthKit payload so the coach can ground answers in real
    /// data. `nil` (omitted on the wire) when the read failed or was empty.
    let metrics: [String: MetricValue]?
}

struct AdviceMessageResponse: Decodable, Equatable {
    let message: String
}
