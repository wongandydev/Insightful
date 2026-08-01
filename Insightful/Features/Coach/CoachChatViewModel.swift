import Foundation
import Observation

/// Drives the coaching conversation in ``CoachChatView``.
///
/// The conversation begins with ``AdviceServicing/start()`` returning the
/// thread and any prior turns; each user reply goes through
/// ``AdviceServicing/sendMessage(threadId:message:date:metrics:)``. Unlike
/// goal setup there is no completion state — the coach thread lives
/// indefinitely.
///
/// `@MainActor @Observable` because the view reads ``messages``,
/// ``userInput``, ``isSending``, and ``errorMessage`` directly.
@MainActor
@Observable
final class CoachChatViewModel {
    /// Window over which HealthKit is sampled for the metrics attached to
    /// each coach message, matching the daily insight's window.
    static let metricsTrailingDays = 7

    /// Ordered transcript. A user turn is appended optimistically when
    /// ``send()`` begins; a failed send removes it and restores
    /// ``userInput``.
    private(set) var messages: [ChatMessage]
    /// Two-way bound to the composer. Restored on send failure so the user
    /// does not retype.
    var userInput: String
    /// `true` while `/advice/start` or `/advice/message` is in flight.
    private(set) var isSending: Bool
    /// User-facing error string; cleared at the start of each call.
    private(set) var errorMessage: String?
    /// Thread identifier from ``start()``; required before ``send()`` works.
    private(set) var threadId: String?

    private let adviceService: any AdviceServicing
    private let healthKitService: any HealthKitServicing
    /// Cached HealthKit payload attached to every send this session. Read
    /// once in ``start()`` — best-effort: a failed read means the coach
    /// answers without data grounding rather than the chat breaking.
    private var metricsPayload: [String: MetricValue]?

    init(
        adviceService: any AdviceServicing,
        healthKitService: any HealthKitServicing
    ) {
        self.adviceService = adviceService
        self.healthKitService = healthKitService
        self.messages = []
        self.userInput = ""
        self.isSending = false
        self.errorMessage = nil
        self.threadId = nil
        self.metricsPayload = nil
    }

    /// Opens or resumes the coach thread and seeds the transcript.
    ///
    /// Safe to call repeatedly — no-ops once a ``threadId`` exists, so the
    /// view can attach it to `.task`. Also snapshots the trailing HealthKit
    /// window for grounding subsequent sends.
    func start() async {
        guard threadId == nil else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let response = try await adviceService.start()
            threadId = response.threadId
            messages = response.messages.map { message in
                ChatMessage(id: UUID(), role: message.role.chatRole, content: message.content)
            }
        } catch {
            errorMessage = "We couldn't reach your coach. Try again."
            return
        }
        let metrics = try? await healthKitService.readDailyMetrics(
            over: Self.metricsTrailingDays,
            metrics: HealthKitMetric.allCases
        )
        metricsPayload = (metrics?.isEmpty == false) ? metrics : nil
    }

    /// Sends the current ``userInput`` to the coach.
    ///
    /// Same optimistic-bubble contract as goal setup: the user bubble
    /// appears and the composer clears before the round-trip; on failure
    /// the bubble is removed and the input restored.
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
            let response = try await adviceService.sendMessage(
                threadId: threadId,
                message: trimmed,
                date: LocalCalendarDate.string(from: Date()),
                metrics: metricsPayload
            )
            messages.append(ChatMessage(id: UUID(), role: .assistant, content: response.message))
        } catch {
            messages.removeAll { $0.id == optimisticId }
            userInput = preservedInput
            errorMessage = "We couldn't reach your coach. Try again."
        }
    }
}
