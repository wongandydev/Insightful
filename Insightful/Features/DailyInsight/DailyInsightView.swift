import SwiftUI

/// Stub for the daily insight screen. Real implementation reads HealthKit
/// and calls ``InsightService/generate(date:metrics:)``.
struct DailyInsightView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Daily Insight").font(.title2.bold())
            Text("Today's insight, charts, and recommended actions go here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
