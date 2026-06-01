import Foundation
import OSLog

/// Centralized OSLog wrapper for the network layer.
///
/// Every request, response, and failure for traffic that flows through
/// ``APIClient`` is emitted via this type so log lines share a consistent
/// template — `→` outbound, `←` inbound, `✕` failed. The uniform shape makes
/// the Network category in Console.app scannable, and gives ops a single
/// glyph to grep on when triaging a failure.
///
/// Bodies are previewed (not fully logged) on non-2xx responses so a server
/// error message is visible inline without bloating the log with payloads.
struct NetworkLogger {
    private static let bodyPreviewLimit = 512

    private let logger: Logger

    /// Creates a logger bound to the given OSLog subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS bundle identifier used by Console.app to
    ///     group log streams.
    ///   - category: Sub-channel within the subsystem; filter on this in
    ///     Console.app to see only network traffic.
    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    /// Logs the start of a request. Called once per send, before any
    /// retry-on-401 attempts (each retry logs again so retries are visible).
    func logRequest(method: HTTPMethod, path: String, requiresAuth: Bool) {
        logger.info("→ \(method.rawValue, privacy: .public) \(path, privacy: .public) auth=\(requiresAuth, privacy: .public)")
    }

    /// Logs a received HTTP response. Logs at `.info` for 2xx and `.error`
    /// for any other status, attaching a truncated body preview so the
    /// server's error message is visible without persisting the full payload.
    func logResponse(
        method: HTTPMethod,
        path: String,
        status: Int,
        requestId: String?,
        body: Data
    ) {
        if (200..<300).contains(status) {
            logger.info("← \(method.rawValue, privacy: .public) \(path, privacy: .public) status=\(status, privacy: .public) requestId=\(requestId ?? "nil", privacy: .public)")
        } else {
            let preview = bodyPreview(body)
            logger.error("← \(method.rawValue, privacy: .public) \(path, privacy: .public) status=\(status, privacy: .public) requestId=\(requestId ?? "nil", privacy: .public) bodyPreview=\(preview, privacy: .public)")
        }
    }

    /// Logs a URLSession-level failure — the request never produced an HTTP
    /// response (offline, DNS, TLS, timeout, etc.).
    func logTransportFailure(method: HTTPMethod, path: String, error: Error) {
        logger.error("✕ \(method.rawValue, privacy: .public) \(path, privacy: .public) transport=\(String(describing: error), privacy: .public)")
    }

    /// Logs a JSON decode failure on an otherwise-successful 2xx response.
    /// This almost always indicates contract drift between client and server.
    func logDecodingFailure(
        method: HTTPMethod,
        path: String,
        requestId: String?,
        error: Error
    ) {
        logger.error("✕ \(method.rawValue, privacy: .public) \(path, privacy: .public) decoding=\(String(describing: error), privacy: .public) requestId=\(requestId ?? "nil", privacy: .public)")
    }

    private func bodyPreview(_ data: Data) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let slice = data.prefix(Self.bodyPreviewLimit)
        return String(data: slice, encoding: .utf8) ?? "<non-utf8 \(data.count)B>"
    }
}
