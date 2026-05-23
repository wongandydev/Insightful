import Foundation
import Observation

/// Drives the goal-setup conversation in ``GoalSetupView``.
///
/// The conversation begins with a single ``GoalServicing/start(date:)`` call
/// that returns a thread identifier and the agent's opening question. Each
/// subsequent user reply is sent through
/// ``GoalServicing/sendMessage(threadId:message:date:)`` until the agent
/// returns ``GoalStatus/goalComplete``, at which point the view model calls
/// `onComplete` so the router can transition away.
///
/// `@MainActor @Observable` because the view reads ``messages``, ``userInput``,
/// ``isSending``, and ``errorMessage`` directly.
@MainActor
@Observable
final class GoalSetupViewModel {
    /// Ordered transcript shown by ``GoalSetupView``. A user turn is only
    /// appended once its send round-trip succeeds — failed sends leave the
    /// transcript untouched and preserve ``userInput`` for retry.
    private(set) var messages: [ChatMessage]
    /// Two-way bound to the text field. Cleared only after ``send()``
    /// succeeds; a failed send leaves the text in place so the user does not
    /// have to retype.
    var userInput: String
    /// `true` while a `/goal/start` or `/goal/message` request is in flight.
    /// The view disables the send button on this.
    private(set) var isSending: Bool
    /// User-facing error string. Reset to `nil` at the start of every
    /// network call so a previous failure does not stick around after a
    /// successful retry.
    private(set) var errorMessage: String?
    /// Thread identifier returned by ``GoalServicing/start(date:)``. `nil`
    /// before ``start()`` has succeeded; required for ``send()`` to do
    /// anything.
    private(set) var threadId: String?

    private let goalService: any GoalServicing
    private let onComplete: () -> Void

    init(goalService: any GoalServicing, onComplete: @escaping () -> Void) {
        self.goalService = goalService
        self.onComplete = onComplete
        self.messages = []
        self.userInput = ""
        self.isSending = false
        self.errorMessage = nil
        self.threadId = nil
    }

    /// Opens the goal-setup thread and appends the agent's first message.
    ///
    /// Safe to call multiple times — the second call no-ops once a
    /// ``threadId`` exists, so views can attach this to `.task` without
    /// worrying about re-entry on re-renders.
    ///
    /// If the agent immediately reports ``GoalStatus/goalComplete`` (because
    /// the user already had context that the server resurfaced), `onComplete`
    /// fires after the opening message is seeded.
    func start() async {
        guard threadId == nil else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let response = try await goalService.start(date: LocalCalendarDate.string(from: Date()))
            threadId = response.threadId
            messages.append(ChatMessage(id: UUID(), role: .assistant, content: response.message))
            if response.status == .goalComplete {
                onComplete()
            }
        } catch {
            errorMessage = "We couldn't reach the server. Try again."
        }
    }

    /// Sends the current ``userInput`` to the agent and appends both the user
    /// turn and the agent's reply.
    ///
    /// No-ops when the trimmed input is empty or when ``start()`` has not
    /// yet produced a ``threadId``. On a successful round-trip the user
    /// message and the assistant's reply are both appended to ``messages``
    /// and ``userInput`` is cleared. On failure ``userInput`` is left in
    /// place so the user can retry without retyping.
    func send() async {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let threadId else { return }

        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let response = try await goalService.sendMessage(
                threadId: threadId,
                message: trimmed,
                date: LocalCalendarDate.string(from: Date())
            )
            messages.append(ChatMessage(id: UUID(), role: .user, content: trimmed))
            messages.append(ChatMessage(id: UUID(), role: .assistant, content: response.message))
            userInput = ""
            if response.status == .goalComplete {
                onComplete()
            }
        } catch {
            errorMessage = "We couldn't reach the server. Try again."
        }
    }
}
