import SwiftUI

/// Stub for the goal-setup conversation flow. Real implementation lands as
/// part of the goal-setup feature work — for now this exists so
/// ``RootViewModel``'s routing can be exercised end-to-end.
struct GoalSetupView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Goal Setup").font(.title2.bold())
            Text("Conversational goal-setup flow goes here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Pretend goal is complete", action: onComplete)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
