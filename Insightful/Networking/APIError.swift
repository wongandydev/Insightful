import Foundation

/// Typed errors returned from `APIClient`. Every case carries the server's
/// `X-Request-Id` (when present) so issues can be correlated with backend logs.
enum APIError: Error, Equatable {
    /// 400 — validation error. `issues` is the server's per-field detail array.
    case badRequest(message: String, issues: [String], requestId: String?)
    /// 401 — JWT missing/invalid. Thrown only after a refresh-and-retry has also failed.
    case unauthorized(requestId: String?)
    /// 403 — accessing a resource owned by a different user.
    case forbidden(requestId: String?)
    /// 409 — conflict (e.g. goal thread already complete).
    case conflict(message: String, requestId: String?)
    /// 413 — payload exceeded server limit (currently 50KB for /insight).
    case payloadTooLarge(requestId: String?)
    /// 429 — rate limited. `retryAfterSeconds` parsed from the `Retry-After` or
    /// `RateLimit-Reset` header when present.
    case rateLimited(retryAfterSeconds: Int?, requestId: String?)
    /// Any 5xx status from the backend.
    case server(status: Int, requestId: String?)
    /// JSON decoding failed. Almost always a contract drift — log loudly.
    case decoding(String, requestId: String?)
    /// URLSession failed before we got a response (offline, timeout, TLS, etc).
    case transport(String)

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case let (.badRequest(lm, li, lr), .badRequest(rm, ri, rr)):
            return lm == rm && li == ri && lr == rr
        case let (.unauthorized(l), .unauthorized(r)):
            return l == r
        case let (.forbidden(l), .forbidden(r)):
            return l == r
        case let (.conflict(lm, lr), .conflict(rm, rr)):
            return lm == rm && lr == rr
        case let (.payloadTooLarge(l), .payloadTooLarge(r)):
            return l == r
        case let (.rateLimited(ls, lr), .rateLimited(rs, rr)):
            return ls == rs && lr == rr
        case let (.server(ls, lr), .server(rs, rr)):
            return ls == rs && lr == rr
        case let (.decoding(lm, lr), .decoding(rm, rr)):
            return lm == rm && lr == rr
        case let (.transport(l), .transport(r)):
            return l == r
        default:
            return false
        }
    }
}

/// Wire shape of a backend error body: `{ "error": "...", "issues": [...] }`.
struct APIErrorBody: Decodable {
    let error: String
    let issues: [String]?
}
