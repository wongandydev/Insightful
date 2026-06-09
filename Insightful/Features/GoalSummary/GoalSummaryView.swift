import SwiftUI

/// Read-only review of the agent's interpretation of the user's goal.
///
/// Used in two places:
///
/// 1. Immediately after a successful goal-setup conversation — both buttons
///    are visible. ``onContinue`` routes forward to the HealthKit prompt;
///    ``onEditGoal`` re-enters goal setup.
/// 2. From Settings as a "View / edit my goal" entry — ``onContinue`` is
///    `nil` so only the edit button shows; the user backs out with the
///    navigation chrome when they're satisfied.
///
/// No editing happens here — corrections always go back through the
/// conversational agent so the saved ``GoalContext`` and the displayed
/// fields stay in sync.
struct GoalSummaryView: View {
    let context: GoalContext
    let onContinue: (() -> Void)?
    let onEditGoal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    summarySection
                    if !context.motivation.isEmpty {
                        section(title: "Why it matters", body: context.motivation)
                    }
                    if let targetDate = context.targetDate, !targetDate.isEmpty {
                        section(title: "Target date", body: targetDate)
                    }
                    if !context.subGoals.isEmpty {
                        subGoalsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here's what we got")
                .font(.title.bold())
            Text("Confirm this is what you meant, or talk to the agent again to refine it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your goal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(context.goalSummary)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(body)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sub-goals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(context.subGoals, id: \.self) { subGoal in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        Text(subGoal)
                            .font(.body)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let onContinue {
                Button(action: onContinue) {
                    Text("Looks right — continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button(action: onEditGoal) {
                Text("Doesn't look right? Talk to it again")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(.bar)
    }
}
