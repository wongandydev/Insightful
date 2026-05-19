import Foundation

/// Shared JSON coders for backend traffic.
///
/// Backend payloads are camelCase except for `GoalContext`, which uses snake_case.
/// We handle that with explicit `CodingKeys` on `GoalContext` rather than a global
/// snake-case strategy — the rest of the API stays surprise-free.
///
/// Dates are exchanged as `YYYY-MM-DD` strings (see `IOS_CONTRACT.md` § 2). We do
/// not configure a `dateEncodingStrategy` because no DTO field has type `Date`;
/// encoding dates as `String` is intentional to avoid timezone drift.
enum JSONCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}

/// Formats a `Date` as the user's local calendar date (`YYYY-MM-DD`).
///
/// All endpoints that accept a date expect the user's **local** calendar date.
/// Do not override `timeZone` — `.current` is what makes per-day caching work
/// correctly on the server.
enum LocalCalendarDate {
    static func string(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
