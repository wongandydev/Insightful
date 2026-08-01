import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct CoachChatViewModelTests {

    @Test
    func startWhenSucceedsSeedsTranscriptAndThreadId() async {
        // Given
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(AdviceStartResponse(
            threadId: "t-1",
            mode: .created,
            messages: [GoalMessage(role: .assistant, content: "I'm your coach.")]
        )))
        let viewModel = makeViewModel(adviceService: adviceService)

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.threadId == "t-1")
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.role == .assistant)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func startWhenServiceThrowsSurfacesErrorMessage() async {
        // Given
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.failure(FakeError.network))
        let viewModel = makeViewModel(adviceService: adviceService)

        // When
        await viewModel.start()

        // Then
        #expect(viewModel.threadId == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func sendWhenSucceedsAppendsUserAndAssistantMessages() async {
        // Given
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(startResponse))
        await adviceService.programSend(.success(AdviceMessageResponse(message: "Ease off today.")))
        let viewModel = makeViewModel(adviceService: adviceService)
        await viewModel.start()
        viewModel.userInput = "Should I do intervals?"

        // When
        await viewModel.send()

        // Then
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[1].role == .user)
        #expect(viewModel.messages[1].content == "Should I do intervals?")
        #expect(viewModel.messages[2].role == .assistant)
        #expect(viewModel.messages[2].content == "Ease off today.")
        #expect(viewModel.userInput.isEmpty)
    }

    @Test
    func sendWhenFailsRemovesOptimisticBubbleAndRestoresInput() async {
        // Given
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(startResponse))
        await adviceService.programSend(.failure(FakeError.network))
        let viewModel = makeViewModel(adviceService: adviceService)
        await viewModel.start()
        viewModel.userInput = "Should I do intervals?"

        // When
        await viewModel.send()

        // Then
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.userInput == "Should I do intervals?")
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func sendWhenMetricsWereReadAttachesThemToTheRequest() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.success(["sleepHours": .series([7.5, 8.0])]))
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(startResponse))
        await adviceService.programSend(.success(AdviceMessageResponse(message: "ok")))
        let viewModel = makeViewModel(adviceService: adviceService, healthKit: healthKit)
        await viewModel.start()
        viewModel.userInput = "How's my recovery?"

        // When
        await viewModel.send()

        // Then
        let calls = await adviceService.sendCalls
        #expect(calls.first?.metrics == ["sleepHours": .series([7.5, 8.0])])
    }

    @Test
    func sendWhenMetricsReadFailedOmitsMetrics() async {
        // Given
        let healthKit = FakeHealthKitService()
        await healthKit.programReadDailyMetrics(.failure(FakeError.network))
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(startResponse))
        await adviceService.programSend(.success(AdviceMessageResponse(message: "ok")))
        let viewModel = makeViewModel(adviceService: adviceService, healthKit: healthKit)
        await viewModel.start()
        viewModel.userInput = "How's my recovery?"

        // When
        await viewModel.send()

        // Then
        let calls = await adviceService.sendCalls
        #expect(calls.first?.metrics == nil)
    }

    @Test
    func sendWhenInputIsEmptyDoesNothing() async {
        // Given
        let adviceService = FakeAdviceService()
        await adviceService.programStart(.success(startResponse))
        let viewModel = makeViewModel(adviceService: adviceService)
        await viewModel.start()
        viewModel.userInput = "   "

        // When
        await viewModel.send()

        // Then
        let calls = await adviceService.sendCalls
        #expect(calls.isEmpty)
        #expect(viewModel.messages.count == 1)
    }

    // MARK: - Helpers

    private var startResponse: AdviceStartResponse {
        AdviceStartResponse(
            threadId: "t-1",
            mode: .created,
            messages: [GoalMessage(role: .assistant, content: "I'm your coach.")]
        )
    }

    private func makeViewModel(
        adviceService: any AdviceServicing,
        healthKit: any HealthKitServicing = FakeHealthKitService()
    ) -> CoachChatViewModel {
        CoachChatViewModel(
            adviceService: adviceService,
            healthKitService: healthKit
        )
    }
}
