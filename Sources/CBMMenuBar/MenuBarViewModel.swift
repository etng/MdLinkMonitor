import AppKit
import CBMCore
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var recentFiles: [URL] = []
    @Published private(set) var statusText: String

    private let settingsStore: any SettingsStoring
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let appUpdater: any AppUpdaterManaging
    private let logger = InMemoryLogger()
    private let orchestrator: ClipboardCaptureOrchestrator
    private var monitor: ClipboardMonitor?

    init(
        settingsStore: any SettingsStoring = UserDefaultsSettingsStore(),
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager(),
        appUpdater: any AppUpdaterManaging = SparkleUpdaterManager()
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginManager = launchAtLoginManager
        self.appUpdater = appUpdater

        let loaded = settingsStore.load()
        self.settings = loaded
        self.statusText = AppLocalizer.text(.statusIdle, language: loaded.language)

        let executor = GitC1CloneExecutor(logger: logger)
        self.orchestrator = ClipboardCaptureOrchestrator(cloneExecutor: executor, logger: logger)

        let monitor = ClipboardMonitor { [weak self] text in
            Task { @MainActor in
                self?.handleClipboardText(text)
            }
        }
        monitor.isEnabled = loaded.monitoringEnabled
        monitor.start()
        self.monitor = monitor

        reloadRecentFiles()
    }

    func text(_ key: L10nKey) -> String {
        AppLocalizer.text(key, language: settings.language)
    }

    func updateMonitoringEnabled(_ enabled: Bool) {
        settings.monitoringEnabled = enabled
        monitor?.isEnabled = enabled
        persist()
    }

    func updateAllowMultipleLinks(_ enabled: Bool) {
        settings.allowMultipleLinks = enabled
        persist()
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        if launchAtLoginManager.setEnabled(enabled) {
            settings.launchAtLogin = enabled
            persist()
        }
    }

    func updateLanguage(_ language: AppLanguage) {
        settings.language = language
        persist()
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text(.chooseDirectory)
        panel.directoryURL = URL(filePath: NSString(string: settings.outputDirectoryPath).expandingTildeInPath)

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectoryPath = url.path(percentEncoded: false)
            persist()
            reloadRecentFiles()
        }
    }

    func openTodayFilePath() -> String {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        return store.todayFileURL().path(percentEncoded: false)
    }

    func reloadRecentFiles() {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        recentFiles = (try? store.listRecentDailyFiles(limit: 30)) ?? []
    }

    func checkForUpdates() {
        appUpdater.checkForUpdates()
        logger.log(.info, "Update check requested")
    }

    private func handleClipboardText(_ text: String) {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        let result = orchestrator.process(
            clipboardText: text,
            allowMultipleLinks: settings.allowMultipleLinks,
            store: store
        )

        if result.totalCandidates == 0 {
            return
        }

        statusText = "+\(result.appendedCount) / clone \(result.clonedCount) / skip \(result.skippedCount)"
        reloadRecentFiles()
    }

    private func persist() {
        settingsStore.save(settings)
    }
}
