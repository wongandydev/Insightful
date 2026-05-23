import SwiftUI

/// Explains why the app needs HealthKit access and triggers the iOS
/// permission sheet via ``HealthKitPermissionViewModel/requestAccess()``.
struct HealthKitPermissionView: View {
    @State private var viewModel: HealthKitPermissionViewModel

    init(healthKitService: any HealthKitServicing, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: HealthKitPermissionViewModel(
            healthKitService: healthKitService,
            onFinished: onFinished
        ))
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
                Text("We read sleep, recovery, heart rate, and workouts to ground today's insight in your actual data — nothing leaves your phone without your sign-in.")
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
