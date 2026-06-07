import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct GoalSetupViewModelTests {

    // MARK: - start()

    @Test
    func startWhenSucceedsSeedsThreadAndFirstAssistantMessage() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            messages: [GoalMessage(role: .assistant, content: "What's your goal?")]
        )))
        let viewModel = makeViewModel(goalService: goalService)

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.threadId == "thread-1")
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.role == .assistant)
        #expect(viewModel.messages.first?.content == "What's your goal?")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func startWhenServerReturnsExistingTranscriptSeedsAllTurns() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-existing",
            status: .inProgress,
            messages: [
                GoalMessage(role: .assistant, content: "What's your goal?"),
                GoalMessage(role: .user, content: "Run a sub-3 marathon"),
                GoalMessage(role: .assistant, content: "When do you want to be ready by?"),
            ]
        )))
        let viewModel = makeViewModel(goalService: goalService)

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.threadId == "thread-existing")
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[0].role == .assistant)
        #expect(viewModel.messages[0].content == "What's your goal?")
        #expect(viewModel.messages[1].role == .user)
        #expect(viewModel.messages[1].content == "Run a sub-3 marathon")
        #expect(viewModel.messages[2].role == .assistant)
        #expect(viewModel.messages[2].content == "When do you want to be ready by?")
    }

    // MARK: - send()

    @Test
    func sendWhenSucceedsAppendsUserAndAssistantMessages() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            messages: [GoalMessage(role: .assistant, content: "What's your goal?")]
        )))
        await goalService.programSendMessage(.success(GoalMessageResponse(
            status: .inProgress,
            message: "Got it — when do you want to be ready by?",
            context: nil
        )))
        let viewModel = makeViewModel(goalService: goalService)
        await viewModel.start()
        viewModel.userInput = "Run a sub-3 marathon"

        // When
        await viewModel.send()

        // Then
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[1].role == .user)
        #expect(viewModel.messages[1].content == "Run a sub-3 marathon")
        #expect(viewModel.messages[2].role == .assistant)
        #expect(viewModel.messages[2].content == "Got it — when do you want to be ready by?")
        #expect(viewModel.userInput == "")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func sendWhenAgentReturnsGoalCompleteCallsOnComplete() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            messages: [GoalMessage(role: .assistant, content: "Opening question")]
        )))
        await goalService.programSendMessage(.success(GoalMessageResponse(
            status: .goalComplete,
            message: "Great, you're set.",
            context: nil
        )))
        var completedCount = 0
        let viewModel = makeViewModel(
            goalService: goalService,
            onComplete: { completedCount += 1 }
        )
        await viewModel.start()
        viewModel.userInput = "Done"

        // When
        await viewModel.send()

        // Then
        #expect(completedCount == 1)
    }

    @Test
    func sendWhenServiceThrowsSurfacesErrorMessage() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            messages: [GoalMessage(role: .assistant, content: "Opening question")]
        )))
        await goalService.programSendMessage(.failure(FakeError.network))
        let viewModel = makeViewModel(goalService: goalService)
        await viewModel.start()
        viewModel.userInput = "My reply"

        // When
        await viewModel.send()

        // Then
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.userInput == "My reply")
        #expect(viewModel.messages.count == 1)
    }

    @Test
    func sendWhenInputIsEmptyDoesNothing() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            messages: [GoalMessage(role: .assistant, content: "Opening question")]
        )))
        let viewModel = makeViewModel(goalService: goalService)
        await viewModel.start()
        viewModel.userInput = "   "

        // When
        await viewModel.send()

        // Then
        let sendCalls = await goalService.sendMessageCalls.count
        #expect(sendCalls == 0)
        #expect(viewModel.messages.count == 1)
    }

    // MARK: - Helpers

    private func makeViewModel(
        goalService: any GoalServicing,
        onComplete: @escaping @MainActor () -> Void = {}
    ) -> GoalSetupViewModel {
        GoalSetupViewModel(goalService: goalService, onComplete: onComplete)
    }
}
