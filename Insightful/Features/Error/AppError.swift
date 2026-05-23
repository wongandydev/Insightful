import Foundation

/// User-facing categories for cold-start failures rendered by ``AppErrorView``.
///
/// The categories are deliberately coarse: each one corresponds to a single
/// piece of copy + iconography the user sees. ``AppError/from(_:)`` collapses
/// the richer ``APIError`` taxonomy down to these buckets and treats anything
/// it does not recognise (including non-``APIError`` throws from the Supabase
/// SDK) as ``AppError/unknown``.
enum AppError: Equatable {
    /// `URLSession` failed before reaching the server — no connectivity,
    /// DNS, or TLS issue. Maps from ``APIError/transport(_:)``.
    case offline

    /// Backend returned 5xx. Maps from ``APIError/server(status:requestId:)``.
    case server

    /// Backend returned 429. Maps from
    /// ``APIError/rateLimited(retryAfterSeconds:requestId:)``.
    case rateLimited

    /// Server returned 2xx but the body did not decode into our DTOs —
    /// contract drift, almost always meaning the iOS app is out of date.
    /// Maps from ``APIError/decoding(_:requestId:)``.
    case decoding

    /// Anything else — unexpected auth state, untyped errors from Supabase,
    /// etc.
    case unknown

    /// Bucketises an arbitrary throw into a user-facing ``AppError``.
    static func from(_ error: Error) -> AppError {
        guard let apiError = error as? APIError else { return .unknown }
        switch apiError {
        case .transport: return .offline
        case .server: return .server
        case .rateLimited: return .rateLimited
        case .decoding: return .decoding
        case .badRequest, .unauthorized, .forbidden, .conflict, .payloadTooLarge:
            return .unknown
        }
    }
}
