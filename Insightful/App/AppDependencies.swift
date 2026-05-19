import Foundation
import HealthKit

/// Composition root. Built once in ``InsightfulApp/init()`` and immediately
/// decomposed into individual service references on the app instance — the
/// struct itself does not survive `init`.
///
/// Each feature view receives only the services it actually uses, not this
/// whole container, so the dependency graph stays explicit and folders below
/// `Features/` could later be cut into their own SPM packages without
/// touching ``AppDependencies``.
@MainActor
struct AppDependencies {
    let authService: AuthService
    let apiClient: APIClient
    let userService: UserService
    let goalService: GoalService
    let insightService: InsightService
    let healthKitService: HealthKitService
    let userDefaults: UserDefaults

    /// Production wiring. The `tokenProvider` and `refreshToken` closures
    /// bridge ``APIClient`` back to ``AuthService`` without either type
    /// importing the other.
    static func live() -> AppDependencies {
        let authBackend = SupabaseAuthBackend(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey)
        let authService = AuthService(backend: authBackend)
        let apiClient = APIClient(
            baseURL: APIConfig.baseURL,
            httpClient: URLSession.shared,
            tokenProvider: { [weak authService] in await authService?.accessToken },
            refreshToken: { [weak authService] in
                guard let authService else { return }
                try await authService.refresh()
            }
        )
        let healthKitReader = HealthKitStoreReader(store: HKHealthStore())
        let healthKitService = HealthKitService(reader: healthKitReader)
        return AppDependencies(
            authService: authService,
            apiClient: apiClient,
            userService: UserService(client: apiClient),
            goalService: GoalService(client: apiClient),
            insightService: InsightService(client: apiClient),
            healthKitService: healthKitService,
            userDefaults: .standard
        )
    }
}
