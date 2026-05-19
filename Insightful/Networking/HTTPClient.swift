import Foundation

/// The HTTP boundary `APIClient` depends on.
///
/// Production uses `URLSession`; tests use an `actor MockHTTPClient`. Shimming
/// here means the test path doesn't go through URLProtocol callbacks (which
/// run on URLSession's internal queue and force lock-based test infra). The
/// mock is an actor we control, awaited naturally from async tests.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }
        return (data, http)
    }
}
