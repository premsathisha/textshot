import CoreGraphics
import Foundation

protocol ScreenCapturePermissionChecking {
    func preflightAuthorized() -> Bool
    func requestIfNeededOncePerLaunch() -> Bool
}

protocol ScreenCaptureAuthorizationAPI {
    func preflight() -> Bool
    func request() -> Bool
}

struct SystemScreenCaptureAuthorizationAPI: ScreenCaptureAuthorizationAPI {
    func preflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

final class ScreenCapturePermissionService: ScreenCapturePermissionChecking {
    private let authorizationAPI: ScreenCaptureAuthorizationAPI
    private var didRequestThisLaunch = false

    init(authorizationAPI: ScreenCaptureAuthorizationAPI = SystemScreenCaptureAuthorizationAPI()) {
        self.authorizationAPI = authorizationAPI
    }

    func preflightAuthorized() -> Bool {
        authorizationAPI.preflight()
    }

    func requestIfNeededOncePerLaunch() -> Bool {
        if authorizationAPI.preflight() {
            return true
        }

        guard !didRequestThisLaunch else {
            return false
        }

        didRequestThisLaunch = true
        return authorizationAPI.request()
    }
}
