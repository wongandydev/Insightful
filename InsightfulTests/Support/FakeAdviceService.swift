import Foundation
@testable import Insightful

/// Scriptable ``AdviceServicing`` for view-model tests.
///
/// Each call is recorded with the arguments the system under test passed;
/// results are programmed per operation.
actor FakeAdviceService: AdviceServicing {
    private var startResult: Result<AdviceStartResponse, any Error & Sendable> = .failure(FakeError.notProgrammed)
    private var sendResult: Result<AdviceMessageResponse, any Error & Sendable> = .failure(FakeError.notProgrammed)

    private(set) var startCalls = 0
    private(set) var sendCalls: [(threadId: String, message: String, date: String, metrics: [String: MetricValue]?)] = []

    func programStart(_ result: Result<AdviceStartResponse, any Error & Sendable>) {
        startResult = result
    }

    func programSend(_ result: Result<AdviceMessageResponse, any Error & Sendable>) {
        sendResult = result
    }

    func start() async throws -> AdviceStartResponse {
        startCalls += 1
        return try startResult.get()
    }

    func sendMessage(threadId: String, message: String, date: String, metrics: [String: MetricValue]?) async throws -> AdviceMessageResponse {
        sendCalls.append((threadId: threadId, message: message, date: date, metrics: metrics))
        return try sendResult.get()
    }
}
