import AppKit

@MainActor
enum AppActivationPolicyManager {
    static func apply(showDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        _ = NSApp.setActivationPolicy(policy)
    }
}
