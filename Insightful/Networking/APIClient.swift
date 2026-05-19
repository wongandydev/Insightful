import Foundation

/// The single chokepoint for all HTTP traffic to the backend.
///
/// Responsibilities:
/// - Build `URLRequest` from an `APIRequest`
/// - Attach `Authorization: Bearer <token>` when `requiresAuth = true`
/// - Decode the typed response, or map non-2xx → `APIError`
/// - On 401: call `refreshToken`, retry once. On the second 401, throw.
///
/// Auth is injected as closures so this type does not import `AuthService`,
/// which lets us build/test the network layer in isolation.
final class APIClient: Sendable {
    typealias TokenProvider = @Sendable () async throws -> String?
    typealias TokenRefresher = @Sendable () async throws -> Void

    private let baseURL: URL
    private let httpClient: HTTPClient
    private let tokenProvider: TokenProvider
    private let refreshToken: TokenRefresher

    init(
        baseURL: URL,
        httpClient: HTTPClient,
        tokenProvider: @escaping TokenProvider,
        refreshToken: @escaping TokenRefresher
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.tokenProvider = tokenProvider
        self.refreshToken = refreshToken
    }

    func send<T: Decodable>(_ request: APIRequest<T>) async throws -> T {
        try await perform(request, allowRefresh: true)
    }

    // MARK: - Internals

    private func perform<T: Decodable>(
        _ request: APIRequest<T>,
        allowRefresh: Bool
    ) async throws -> T {
        let urlRequest = try await buildURLRequest(from: request)

        let data: Data
        let http: HTTPURLResponse
        do {
            (data, http) = try await httpClient.send(urlRequest)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let requestId = http.value(forHTTPHeaderField: "X-Request-Id")

        switch http.statusCode {
        case 200..<300:
            return try decode(data, requestId: requestId)

        case 401 where allowRefresh && request.requiresAuth:
            try? await refreshToken()
            return try await perform(request, allowRefresh: false)

        case 401:
            throw APIError.unauthorized(requestId: requestId)

        case 400:
            let body = try? JSONCoding.decoder.decode(APIErrorBody.self, from: data)
            throw APIError.badRequest(
                message: body?.error ?? "Bad request",
                issues: body?.issues ?? [],
                requestId: requestId
            )

        case 403:
            throw APIError.forbidden(requestId: requestId)

        case 409:
            let body = try? JSONCoding.decoder.decode(APIErrorBody.self, from: data)
            throw APIError.conflict(message: body?.error ?? "Conflict", requestId: requestId)

        case 413:
            throw APIError.payloadTooLarge(requestId: requestId)

        case 429:
            throw APIError.rateLimited(
                retryAfterSeconds: parseRetryAfter(http),
                requestId: requestId
            )

        case 500...:
            throw APIError.server(status: http.statusCode, requestId: requestId)

        default:
            throw APIError.server(status: http.statusCode, requestId: requestId)
        }
    }

    private func buildURLRequest<T>(from request: APIRequest<T>) async throws -> URLRequest {
        guard let url = URL(string: request.path, relativeTo: baseURL) else {
            throw APIError.transport("Invalid URL: \(request.path)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if request.requiresAuth, let token = try await tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return urlRequest
    }

    private func decode<T: Decodable>(_ data: Data, requestId: String?) throws -> T {
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error), requestId: requestId)
        }
    }

    private func parseRetryAfter(_ response: HTTPURLResponse) -> Int? {
        if let raw = response.value(forHTTPHeaderField: "Retry-After"), let s = Int(raw) {
            return s
        }
        if let raw = response.value(forHTTPHeaderField: "RateLimit-Reset"), let s = Int(raw) {
            return s
        }
        return nil
    }
}
