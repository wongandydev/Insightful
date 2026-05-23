import Foundation
import Observation

/// Drives the HealthKit permission screen.
///
/// One job: when the user taps the connect button, present the iOS
/// permission sheet via ``HealthKitServicing/requestAuthorization()`` and
/// then call `onFinished` regardless of grant outcome. iOS does not reveal
/// HealthKit read-permission state to apps — there is no way to tell "no
/// data" apart from "denied" — so the flow always advances after the sheet
/// resolves.
///
/// `@MainActor @Observable` because the view binds to ``isRequesting``.
@MainActor
@Observable
final class HealthKitPermissionViewModel {
    /// `true` while the system permission sheet is in flight. The view shows
    /// a spinner and disables the button on this.
    private(set) var isRequesting: Bool

    private let healthKitService: any HealthKitServicing
    private let onFinished: () -> Void

    init(healthKitService: any HealthKitServicing, onFinished: @escaping () -> Void) {
        self.healthKitService = healthKitService
        self.onFinished = onFinished
        self.isRequesting = false
    }

    /// Presents the iOS permission sheet and then signals completion.
    ///
    /// Any throw from ``HealthKitServicing/requestAuthorization()`` is
    /// intentionally swallowed: the flow advances either way because the
    /// app cannot distinguish "user denied" from "user granted but has no
    /// data yet". A subsequent missing-data state surfaces on the daily
    /// insight screen, not here.
    func requestAccess() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            // Intentionally swallowed — see doc comment.
        }
        onFinished()
    }
}
