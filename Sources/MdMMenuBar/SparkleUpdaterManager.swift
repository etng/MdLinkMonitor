import AppKit
import Foundation
import Sparkle

enum AppUpdateCheckResult {
    case requested
    case skipped(reason: String)
}

protocol AppUpdaterManaging {
    @MainActor
    func checkForUpdates() -> AppUpdateCheckResult
}

@MainActor
final class SparkleUpdaterManager: NSObject, AppUpdaterManaging {
    private let updaterController: SPUStandardUpdaterController
    private var updaterStarted = false

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        installSparkleWindowObservers()
    }

    func checkForUpdates() -> AppUpdateCheckResult {
        if !updaterStarted {
            do {
                try updaterController.updater.start()
                updaterStarted = true
            } catch {
                return .skipped(reason: error.localizedDescription)
            }
        }

        updaterController.updater.checkForUpdates()
        return .requested
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func installSparkleWindowObservers() {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(handleWindowStateChanged(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowStateChanged(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc
    private func handleWindowStateChanged(_ notification: Notification) {
        elevateSparkleWindowIfNeeded(from: notification)
    }

    private func elevateSparkleWindowIfNeeded(from notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard isSparkleWindow(window) else { return }

        window.level = .modalPanel
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    private func isSparkleWindow(_ window: NSWindow) -> Bool {
        let className = NSStringFromClass(type(of: window))
        if className.contains("SPU") || className.contains("Sparkle") {
            return true
        }

        let bundleID = Bundle(for: type(of: window)).bundleIdentifier ?? ""
        return bundleID.contains("sparkle-project")
    }
}
