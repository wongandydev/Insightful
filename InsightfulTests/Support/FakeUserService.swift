import Foundation
@testable import Insightful

/// Scriptable ``UserServicing`` for view-model tests.
///
/// Default behavior is `sync()` returning `"u-1"`. Call ``program(_:)`` to
/// override with a specific result (success or failure). Inspect
/// ``syncCalls`` from the Then block of a test.
actor FakeUserService: UserServicing {
    private(set) var syncCalls = 0
    private var result: Result<String, any Error & Sendable> = .success("u-1")

    /// Overrides the next (and subsequent) `sync()` results until programmed
    /// again.
    func program(_ result: Result<String, any Error & Sendable>) {
        self.result = result
    }

    func sync() async throws -> String {
        syncCalls += 1
        return try result.get()
    }
}
