import Foundation
import Observation

/// Drives the Home tab's presentation state.
///
/// v1 holds only the two sheet-presentation flags Home owns: the daily-insight
/// launcher sheet and the Settings sheet. Phase 2 expands this with the loaded
/// metrics, the "today's insight" tile state, and the progress-to-goal
/// callout data described in the Home entry in `TODO.md`.
@MainActor
@Observable
final class HomeViewModel {
    /// Whether the daily-insight sheet is currently presented.
    var isShowingInsight: Bool
    /// Whether the Settings sheet is currently presented.
    var isShowingSettings: Bool

    init() {
        self.isShowingInsight = false
        self.isShowingSettings = false
    }
}
