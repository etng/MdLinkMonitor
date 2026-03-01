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

        guard updaterController.updater.canCheckForUpdates else {
            return .skipped(reason: "updater not ready to check updates")
        }

        updaterController.updater.checkForUpdates()
        return .requested
    }
}
