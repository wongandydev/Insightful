import Foundation

struct UserSyncResponse: Decodable, Equatable {
    let userId: String
}

struct HealthCheckResponse: Decodable, Equatable {
    let status: String
}
