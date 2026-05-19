import SwiftUI

@main
struct InsightfulApp: App {
    private let authService: AuthService
    private let userService: UserService
    private let goalService: GoalService
    private let insightService: InsightService
    private let healthKitService: HealthKitService
    private let userDefaults: UserDefaults

    init() {
        let deps = AppDependencies.live()
        authService = deps.authService
        userService = deps.userService
        goalService = deps.goalService
        insightService = deps.insightService
        healthKitService = deps.healthKitService
        userDefaults = deps.userDefaults
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                userService: userService,
                goalService: goalService,
                insightService: insightService,
                healthKitService: healthKitService,
                userDefaults: userDefaults
            )
        }
    }
}
