import ServiceManagement
import os.log

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true on success. Failures are logged, not fatal — the app
    /// works fine without this, the user just has to launch it manually.
    @discardableResult
    static func toggle() -> Bool {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            return true
        } catch {
            os_log("LaunchAtLogin toggle failed: %{public}@", "\(error)")
            return false
        }
    }
}
