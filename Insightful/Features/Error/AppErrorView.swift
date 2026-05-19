import SwiftUI

/// Shown when the cold-start sequence in ``RootViewModel/start()`` fails.
/// The retry button re-invokes `start()` via the supplied closure.
struct AppErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
