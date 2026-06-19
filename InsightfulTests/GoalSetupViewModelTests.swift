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
            mode: .created,
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
        #expect(viewModel.wasResumed == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func startWhenModeIsResumedFlagsWasResumed() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-existing",
            status: .inProgress,
            mode: .resumed,
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
        #expect(viewModel.wasResumed)
    }

    @Test
    func startWhenModeIsRefinedDoesNotFlagWasResumed() async {
        // Given — refine mode appends the synthetic refinement opener at the
        // bottom; the resumed banner would be redundant noise on top of it.
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-reopened",
            status: .inProgress,
            mode: .refined,
            messages: [
                GoalMessage(role: .assistant, content: "What's your goal?"),
                GoalMessage(role: .user, content: "Run a sub-3 marathon"),
                GoalMessage(role: .assistant, content: "Welcome back. What would you like to refine about your goal?"),
            ]
        )))
        let viewModel = makeViewModel(goalService: goalService)

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.wasResumed == false)
    }

    // MARK: - send()

    @Test
    func sendWhenSucceedsAppendsUserAndAssistantMessages() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            mode: .created,
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
    func sendWhenAgentReturnsGoalCompleteWithContextHandsContextToOnComplete() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            mode: .created,
            messages: [GoalMessage(role: .assistant, content: "Opening question")]
        )))
        let context = makeGoalContext(summary: "Run a sub-3 marathon")
        await goalService.programSendMessage(.success(GoalMessageResponse(
            status: .goalComplete,
            message: "Great, you're set.",
            context: context
        )))
        var receivedContexts: [GoalContext] = []
        let viewModel = makeViewModel(
            goalService: goalService,
            onComplete: { receivedContexts.append($0) }
        )
        await viewModel.start()
        viewModel.userInput = "Done"

        // When
        await viewModel.send()

        // Then
        #expect(receivedContexts == [context])
        #expect(viewModel.isFinalizing)
    }

    @Test
    func sendWhenAgentReturnsGoalCompleteWithoutContextDoesNotCallOnComplete() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            mode: .created,
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
            onComplete: { _ in completedCount += 1 }
        )
        await viewModel.start()
        viewModel.userInput = "Done"

        // When
        await viewModel.send()

        // Then
        #expect(completedCount == 0)
        #expect(viewModel.isFinalizing == false)
    }

    @Test
    func sendWhenServiceThrowsSurfacesErrorMessage() async {
        // Given
        let goalService = FakeGoalService()
        await goalService.programStart(.success(GoalStartResponse(
            threadId: "thread-1",
            status: .inProgress,
            mode: .created,
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
            mode: .created,
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
        onComplete: @escaping @MainActor (GoalContext) -> Void = { _ in }
    ) -> GoalSetupViewModel {
        GoalSetupViewModel(
            goalService: goalService,
            finalizingDelay: .zero,
            onComplete: onComplete
        )
    }

    private func makeGoalContext(summary: String) -> GoalContext {
        GoalContext(
            goalType: .enduranceEvent,
            goalSummary: summary,
            targetDate: "2026-12-01",
            motivation: "first race",
            currentState: "training 6h/wk",
            biggestConcern: "swim",
            lifestyle: "office job",
            previouslyTried: nil,
            injuriesOrLimitations: nil,
            priorityMetrics: ["restingHeartRate", "sleepHours"],
            sportsOrActivities: ["running"],
            subGoals: ["long run 30km", "weekly volume 60km"],
            rationale: "We'll track your resting heart rate and sleep to gauge how your training is landing."
        )
    }
}
