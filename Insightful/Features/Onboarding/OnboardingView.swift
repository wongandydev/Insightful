import SwiftUI

/// One-time explainer shown before the first goal-setup conversation.
///
/// Frames what the app does and what the next three steps are so the user
/// isn't dropped into a chat with no context. Static content, single
/// continue action — no view model. ``RootViewModel/onboardingFinished()``
/// records the ``PreferenceKeys/hasSeenOnboarding`` flag.
struct OnboardingView: View {
    /// Invoked when the user taps continue. The parent routes to goal setup.
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 12) {
                Text("Welcome to Insightful")
                    .font(.title.bold())
                Text("Turn the health data your devices already collect into a plan you can act on.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            VStack(alignment: .leading, spacing: 16) {
                OnboardingStep(
                    number: 1,
                    symbol: "bubble.left.and.bubble.right",
                    text: "First, we'll chat to set your goal — a race, a weight target, better sleep."
                )
                OnboardingStep(
                    number: 2,
                    symbol: "heart.text.square",
                    text: "Then you'll connect Apple Health so insights are grounded in your real data."
                )
                OnboardingStep(
                    number: 3,
                    symbol: "sparkles",
                    text: "Every day you'll get an insight on your progress and what to do next."
                )
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text("Set my goal")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

/// One numbered row in the onboarding flow list.
private struct OnboardingStep: View {
    let number: Int
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }
}
