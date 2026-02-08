import Foundation
import ServiceManagement

protocol LaunchAtLoginApplying {
    func apply(enabled: Bool)
}

final class LaunchAtLoginService {
    func apply(enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep runtime resilient if login-item registration fails.
        }
    }
}

extension LaunchAtLoginService: LaunchAtLoginApplying {}
