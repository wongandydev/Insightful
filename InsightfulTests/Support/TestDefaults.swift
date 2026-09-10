import Foundation

/// A `UserDefaults` suite unique to each call.
///
/// ``AuthService`` persists "has this device ever authenticated" across
/// sessions, so tests sharing `.standard` would leak that flag into each
/// other and make `bootstrap()`'s outcome depend on execution order.
func ephemeralDefaults(_ id: String = UUID().uuidString) -> UserDefaults {
    UserDefaults(suiteName: "test.\(id)")!
}
