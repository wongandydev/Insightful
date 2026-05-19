import Foundation
@testable import Insightful

/// Test double for `HTTPClient`. Drives `APIClient` against canned responses
/// without going through `URLSession`/`URLProtocol`.
///
/// Why an actor: the mock holds mutable state (enqueued responses and captured
/// requests) that the test reads after awaiting `client.send`. Actor isolation
/// keeps both producer and consumer safe without locks.
actor MockHTTPClient: HTTPClient {
    private var enqueuedResults: [Result<(Data, HTTPURLResponse), Error>] = []
    private(set) var capturedRequests: [URLRequest] = []

    func enqueue(_ result: Result<(Data, HTTPURLResponse), Error>) {
        enqueuedResults.append(result)
    }

    /// Convenience for the common case: 2xx-ish status + JSON body.
    func enqueue(status: Int, headers: [String: String] = [:], body: Data = Data(), url: URL) {
        let response = HTTPURLResponse.stub(url: url, status: status, headers: headers)
        enqueuedResults.append(.success((body, response)))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        guard !enqueuedResults.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return try enqueuedResults.removeFirst().get()
    }
}

extension HTTPURLResponse {
    /// Test helper for building stubbed responses.
    static func stub(
        url: URL,
        status: Int,
        headers: [String: String] = [:]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}
