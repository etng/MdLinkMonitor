import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) -> Bool
}

struct LaunchAtLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
