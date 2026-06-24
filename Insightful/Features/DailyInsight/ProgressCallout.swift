import SwiftUI

/// Renders the calendar-and-subgoal progress block that sits above today's
/// insight on the daily-insight sheet and on the Home tab.
///
/// Shows nothing when ``InsightProgress/daysUntilTarget`` is `nil` and
/// ``InsightProgress/subgoals`` is empty, so callers can drop it in without
/// guarding visibility themselves.
struct ProgressCallout: View {
    let progress: InsightProgress

    var body: some View {
        if progress.daysUntilTarget == nil && progress.subgoals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let days = progress.daysUntilTarget {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(Color.accentColor)
                        Text(daysHeadline(days: days))
                            .font(.subheadline.weight(.semibold))
                    }
                }
                ForEach(progress.subgoals, id: \.text) { subgoal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subgoal.text)
                                .font(.subheadline)
                            Text("Target: \(subgoal.target)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func daysHeadline(days: Int) -> String {
        switch days {
        case 0: return "Target day"
        case 1: return "1 day to target"
        default: return "\(days) days to target"
        }
    }
}
