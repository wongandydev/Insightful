import Foundation
import Testing
@testable import Insightful

@MainActor
@Suite
struct HealthKitPermissionViewModelTests {

    @Test
    func requestAccessCallsServiceAndThenFinished() async {
        // Given
        let service = FakeHealthKitService()
        await service.programRequestAuthorization(.success(()))
        var finishedCount = 0
        let viewModel = HealthKitPermissionViewModel(
            healthKitService: service,
            onFinished: { finishedCount += 1 }
        )

        // When
        await viewModel.requestAccess()

        // Then
        let calls = await service.requestAuthorizationCalls
        #expect(calls == 1)
        #expect(finishedCount == 1)
        #expect(viewModel.isRequesting == false)
    }

    @Test
    func requestAccessWhenServiceThrowsStillCallsFinished() async {
        // Given
        let service = FakeHealthKitService()
        await service.programRequestAuthorization(.failure(FakeError.network))
        var finishedCount = 0
        let viewModel = HealthKitPermissionViewModel(
            healthKitService: service,
            onFinished: { finishedCount += 1 }
        )

        // When
        await viewModel.requestAccess()

        // Then
        #expect(finishedCount == 1)
        #expect(viewModel.isRequesting == false)
    }
}
