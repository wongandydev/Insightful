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
    /// Ordered transcript of the conversation. A user turn is appended
    /// optimistically the moment ``send()`` begins so the bubble shows
    /// immediately; a failed send removes it and restores ``userInput`` for
    /// retry.
    private(set) var messages: [ChatMessage]
    /// Two-way bound to the text field. Cleared when ``send()`` enqueues the
    /// optimistic user bubble; restored to its prior value if the send fails
    /// so the user does not have to retype.
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

    /// Opens or resumes the goal-setup thread and seeds the transcript with
    /// every message the server returns.
    ///
    /// Safe to call multiple times — the second call no-ops once a
    /// ``threadId`` exists, so views can attach this to `.task` without
    /// worrying about re-entry on re-renders. The server's response is
    /// idempotent: a fresh thread returns just the opener; an in-progress
    /// thread returns the opener plus every persisted turn.
    func start() async {
        guard threadId == nil else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let response = try await goalService.start(date: LocalCalendarDate.string(from: Date()))
            threadId = response.threadId
            messages = response.messages.map { message in
                ChatMessage(id: UUID(), role: message.role.chatRole, content: message.content)
            }
        } catch {
            errorMessage = "We couldn't reach the server. Try again."
        }
    }

    /// Sends the current ``userInput`` to the agent.
    ///
    /// The user bubble is appended to ``messages`` and ``userInput`` is
    /// cleared before the network call so the composer feels responsive;
    /// the assistant's reply is appended when the round-trip succeeds.
    /// No-ops when the trimmed input is empty or when ``start()`` has not
    /// yet produced a ``threadId``. On failure the optimistic user bubble
    /// is removed and ``userInput`` is restored so the user can retry
    /// without retyping.
    func send() async {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let threadId else { return }

        let optimisticId = UUID()
        let preservedInput = userInput
        messages.append(ChatMessage(id: optimisticId, role: .user, content: trimmed))
        userInput = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let response = try await goalService.sendMessage(
                threadId: threadId,
                message: trimmed,
                date: LocalCalendarDate.string(from: Date())
            )
            messages.append(ChatMessage(id: UUID(), role: .assistant, content: response.message))
            if response.status == .goalComplete {
                onComplete()
            }
        } catch {
            messages.removeAll { $0.id == optimisticId }
            userInput = preservedInput
            errorMessage = "We couldn't reach the server. Try again."
        }
    }
}
