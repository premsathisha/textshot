import Testing
@testable import TextShotSettings

private final class MockScreenCaptureAuthorizationAPI: ScreenCaptureAuthorizationAPI {
    var preflightResponses: [Bool]
    var requestResponse: Bool
    private(set) var requestCount = 0

    init(preflightResponses: [Bool], requestResponse: Bool) {
        self.preflightResponses = preflightResponses
        self.requestResponse = requestResponse
    }

    func preflight() -> Bool {
        guard !preflightResponses.isEmpty else {
            return false
        }
        if preflightResponses.count == 1 {
            return preflightResponses[0]
        }
        return preflightResponses.removeFirst()
    }

    func request() -> Bool {
        requestCount += 1
        return requestResponse
    }
}

@Test
func screenCapturePermissionPreflightTrueDoesNotRequest() {
    let api = MockScreenCaptureAuthorizationAPI(preflightResponses: [true, true], requestResponse: false)
    let service = ScreenCapturePermissionService(authorizationAPI: api)

    #expect(service.preflightAuthorized())
    #expect(service.requestIfNeededOncePerLaunch())
    #expect(api.requestCount == 0)
}

@Test
func screenCapturePermissionFirstRequestReturnsDenied() {
    let api = MockScreenCaptureAuthorizationAPI(preflightResponses: [false], requestResponse: false)
    let service = ScreenCapturePermissionService(authorizationAPI: api)

    #expect(service.requestIfNeededOncePerLaunch() == false)
    #expect(api.requestCount == 1)
}

@Test
func screenCapturePermissionOnlyRequestsOncePerLaunch() {
    let api = MockScreenCaptureAuthorizationAPI(preflightResponses: [false, false, false], requestResponse: false)
    let service = ScreenCapturePermissionService(authorizationAPI: api)

    #expect(service.requestIfNeededOncePerLaunch() == false)
    #expect(service.requestIfNeededOncePerLaunch() == false)
    #expect(api.requestCount == 1)
}
