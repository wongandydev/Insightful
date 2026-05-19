import SwiftUI

/// Stub for the HealthKit permission screen. Replaced by the real
/// explainer + system prompt trigger when the feature ships.
struct HealthKitPermissionView: View {
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect Apple Health").font(.title2.bold())
            Text("We'll read your sleep, recovery, heart rate, and workouts to deliver insights grounded in your actual data.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue", action: onFinished)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
