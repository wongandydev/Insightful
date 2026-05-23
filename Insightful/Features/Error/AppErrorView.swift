import SwiftUI

/// Shown when ``RootViewModel/start()`` fails. Renders copy + iconography
/// tailored to the ``AppError`` category; the retry button re-invokes
/// `start()` via the supplied closure.
struct AppErrorView: View {
    let error: AppError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var iconName: String {
        switch error {
        case .offline: return "wifi.slash"
        case .server: return "exclamationmark.icloud"
        case .rateLimited: return "clock.badge.exclamationmark"
        case .decoding: return "arrow.down.app"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch error {
        case .offline: return "You're offline"
        case .server: return "Server's having a moment"
        case .rateLimited: return "Slow down"
        case .decoding: return "Update the app"
        case .unknown: return "Something went wrong"
        }
    }

    private var message: String {
        switch error {
        case .offline:
            return "Check your connection and try again."
        case .server:
            return "Our backend hit a snag. Give it a few seconds and try again."
        case .rateLimited:
            return "Too many requests in a short window. Try again in a moment."
        case .decoding:
            return "We got a response we couldn't read. Update Insightful from the App Store and try again."
        case .unknown:
            return "We couldn't finish setting up. Try again, and if it keeps happening let us know."
        }
    }
}
