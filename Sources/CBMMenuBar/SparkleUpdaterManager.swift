import AppKit
import Foundation
import Sparkle

protocol AppUpdaterManaging {
    @MainActor
    func checkForUpdates()
}

@MainActor
final class SparkleUpdaterManager: NSObject, AppUpdaterManaging {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
