import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

/// Declarative description of an HTTP call. The `Response` phantom type makes
/// `APIClient.send` return the exact decoded type the endpoint promises.
struct APIRequest<Response: Decodable> {
    let method: HTTPMethod
    let path: String
    /// Pre-encoded JSON body. `nil` for `GET` or empty-body requests.
    let body: Data?
    /// When `true`, the client attaches `Authorization: Bearer <token>` and
    /// performs the 401-refresh-and-retry-once dance. Set `false` for `/health`.
    let requiresAuth: Bool

    init(method: HTTPMethod, path: String, body: Data?, requiresAuth: Bool) {
        self.method = method
        self.path = path
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

/// Convenience for building a request whose body is a `Codable` value.
extension APIRequest {
    static func json<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body,
        requiresAuth: Bool
    ) throws -> APIRequest<Response> {
        let data = try JSONCoding.encoder.encode(body)
        return APIRequest(method: method, path: path, body: data, requiresAuth: requiresAuth)
    }
}
