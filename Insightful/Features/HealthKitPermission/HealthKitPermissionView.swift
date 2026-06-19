import SwiftUI

/// Explains why the app needs HealthKit access and triggers the iOS
/// permission sheet via ``HealthKitPermissionViewModel/requestAccess()``.
struct HealthKitPermissionView: View {
    @State private var viewModel: HealthKitPermissionViewModel

    /// Goal-specific rationale rendered in place of ``staticRationale`` when
    /// the agent supplied one. `nil` for goals set before the field existed.
    private let rationale: String?

    /// Fallback copy shown when ``rationale`` is `nil` or empty.
    private static let staticRationale = "We read sleep, recovery, heart rate, and workouts to ground today's insight in your actual data — nothing leaves your phone without your sign-in."

    init(
        healthKitService: any HealthKitServicing,
        rationale: String?,
        onFinished: @escaping () -> Void
    ) {
        self.rationale = rationale
        _viewModel = State(initialValue: HealthKitPermissionViewModel(
            healthKitService: healthKitService,
            onFinished: onFinished
        ))
    }

    /// The rationale to display: the agent's copy when non-empty, else the
    /// static fallback.
    private var displayRationale: String {
        guard let rationale, !rationale.isEmpty else { return Self.staticRationale }
        return rationale
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink)
            VStack(spacing: 12) {
                Text("Connect Apple Health")
                    .font(.title.bold())
                Text(displayRationale)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button {
                Task { await viewModel.requestAccess() }
            } label: {
                Group {
                    if viewModel.isRequesting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Connect Apple Health")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isRequesting)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
