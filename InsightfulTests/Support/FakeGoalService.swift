import Foundation
@testable import Insightful

/// Scriptable ``GoalServicing`` for view-model tests.
///
/// Each operation can be programmed independently. Recorded calls expose
/// the arguments the system under test passed.
actor FakeGoalService: GoalServicing {
    private var startResult: Result<GoalStartResponse, any Error & Sendable> = .failure(FakeError.notProgrammed)
    private var sendMessageResult: Result<GoalMessageResponse, any Error & Sendable> = .failure(FakeError.notProgrammed)
    private var getContextResult: Result<GoalContextResponse, any Error & Sendable> = .failure(FakeError.notProgrammed)

    private(set) var startCalls: [String] = []
    private(set) var sendMessageCalls: [(threadId: String, message: String, date: String)] = []
    private(set) var getContextCalls = 0

    func programStart(_ result: Result<GoalStartResponse, any Error & Sendable>) {
        startResult = result
    }

    func programSendMessage(_ result: Result<GoalMessageResponse, any Error & Sendable>) {
        sendMessageResult = result
    }

    func programGetContext(_ result: Result<GoalContextResponse, any Error & Sendable>) {
        getContextResult = result
    }

    func start(date: String) async throws -> GoalStartResponse {
        startCalls.append(date)
        return try startResult.get()
    }

    func sendMessage(threadId: String, message: String, date: String) async throws -> GoalMessageResponse {
        sendMessageCalls.append((threadId: threadId, message: message, date: date))
        return try sendMessageResult.get()
    }

    func getContext() async throws -> GoalContextResponse {
        getContextCalls += 1
        return try getContextResult.get()
    }
}
