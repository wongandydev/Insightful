import Foundation

/// A single turn in the goal-setup conversation as rendered by
/// ``GoalSetupView``.
///
/// The view model owns an ordered array of these — one per user reply and
/// one per assistant response. `id` is generated locally because the backend
/// does not surface per-message identifiers, only the `threadId`.
struct ChatMessage: Identifiable, Equatable, Sendable {
    /// Who authored the message.
    enum Role: Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String

    init(id: UUID, role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
