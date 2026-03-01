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
    private let notifier: any UserNotifying
    private let windowPresenter: WindowPresenter

    private let memoryLogger: InMemoryLogger
    private let fileLogger: DailyFileLogger
    private let logger: CompositeLogger

    private let orchestrator: ClipboardCaptureOrchestrator
    private var monitor: ClipboardMonitor?

    init(
        settingsStore: any SettingsStoring = UserDefaultsSettingsStore(),
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager(),
        appUpdater: any AppUpdaterManaging = SparkleUpdaterManager(),
        notifier: any UserNotifying = UserNotificationManager(),
        windowPresenter: WindowPresenter = WindowPresenter()
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginManager = launchAtLoginManager
        self.appUpdater = appUpdater
        self.notifier = notifier
        self.windowPresenter = windowPresenter

        let loaded = settingsStore.load()
        self.settings = loaded
        self.statusText = AppLocalizer.text(.statusIdle, language: loaded.language)
        AppActivationPolicyManager.apply(showDockIcon: loaded.showDockIcon)

        let memoryLogger = InMemoryLogger()
        let fileLogger = DailyFileLogger(baseDirectoryPath: loaded.outputDirectoryPath)
        self.memoryLogger = memoryLogger
        self.fileLogger = fileLogger
        self.logger = CompositeLogger(loggers: [memoryLogger, fileLogger])

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

        logger.log(.info, "App started")
        logEvent("MenuBarViewModel initialized, monitoring=\(loaded.monitoringEnabled)")
        reloadRecentFiles()
    }

    func text(_ key: L10nKey) -> String {
        AppLocalizer.text(key, language: settings.language)
    }

    var repositoryDomainsText: String {
        settings.repositoryDomains.joined(separator: "\n")
    }

    var todayMenuDateText: String {
        let formatter = DateFormatter()
        formatter.locale = settings.language == .zhHans ? Locale(identifier: "zh_Hans_CN") : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    func updateMonitoringEnabled(_ enabled: Bool) {
        logEvent("UI toggle monitoring -> \(enabled)")
        updateSettings { state in
            state.monitoringEnabled = enabled
        }

        monitor?.isEnabled = enabled
        let message = enabled ? local("监控已启用", "Monitoring enabled") : local("监控已关闭", "Monitoring disabled")
        setStatus(message)
        logger.log(.info, message)
        notifyIfEnabled(message)
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        logEvent("UI toggle notifications -> \(enabled)")
        updateSettings { state in
            state.notificationsEnabled = enabled
        }

        let message = enabled ? local("系统通知已启用", "System notifications enabled") : local("系统通知已关闭", "System notifications disabled")
        setStatus(message)
        logger.log(.info, message)
    }

    func updateAllowMultipleLinks(_ enabled: Bool) {
        logEvent("UI toggle allowMultipleLinks -> \(enabled)")
        updateSettings { state in
            state.allowMultipleLinks = enabled
        }

        let message = enabled ? local("多链接模式已启用", "Multiple-link mode enabled") : local("多链接模式已关闭", "Multiple-link mode disabled")
        setStatus(message)
        logger.log(.info, message)
        notifyIfEnabled(message)
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        logEvent("UI toggle launchAtLogin -> \(enabled)")
        NSApp.activate(ignoringOtherApps: true)

        if launchAtLoginManager.setEnabled(enabled) {
            updateSettings { state in
                state.launchAtLogin = enabled
            }
            let message = enabled ? local("开机启动已启用", "Launch at login enabled") : local("开机启动已关闭", "Launch at login disabled")
            setStatus(message)
            logger.log(.info, message)
            notifyIfEnabled(message)
        } else {
            let message = local("开机启动设置失败（开发环境可能受限）", "Failed to update launch-at-login setting")
            setStatus(message)
            logger.log(.error, message)
            notifyIfEnabled(message)
        }
    }

    func updateShowDockIcon(_ enabled: Bool) {
        logEvent("UI toggle showDockIcon -> \(enabled)")
        updateSettings { state in
            state.showDockIcon = enabled
        }

        AppActivationPolicyManager.apply(showDockIcon: enabled)
        let message = enabled ? local("Dock 图标已显示", "Dock icon enabled") : local("Dock 图标已隐藏", "Dock icon hidden")
        setStatus(message)
        logger.log(.info, message)
    }

    func updatePreviewMarkdownFontSize(_ size: Double) {
        let normalized = max(12, min(size, 28))
        updateSettings { state in
            state.previewMarkdownFontSize = normalized
        }
    }

    func updatePreviewCalendarScale(_ scale: Double) {
        let normalized = max(0.9, min(scale, 1.8))
        updateSettings { state in
            state.previewCalendarScale = normalized
        }
    }

    func updateLanguage(_ language: AppLanguage) {
        logEvent("UI change language -> \(language.rawValue)")
        updateSettings { state in
            state.language = language
        }
        let message = local("语言已切换", "Language updated")
        setStatus(message)
        logger.log(.info, message)
    }

    func updateRepositoryDomains(from text: String) {
        let domains = AppSettings.parseDomains(from: text)
        let fallback = domains.isEmpty ? ["github.com", "gitlab.com"] : domains

        updateSettings { state in
            state.repositoryDomains = fallback
        }
        let message = local("仓库域名配置已更新", "Repository domains updated") + ": \(fallback.joined(separator: ", "))"
        setStatus(message)
        logger.log(.info, message)
    }

    func chooseOutputDirectory() {
        logEvent("UI action chooseOutputDirectory")
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text(.chooseDirectory)
        panel.directoryURL = URL(filePath: NSString(string: settings.outputDirectoryPath).expandingTildeInPath)

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path(percentEncoded: false)
            updateSettings { state in
                state.outputDirectoryPath = path
            }
            fileLogger.baseDirectoryPath = path

            reloadRecentFiles()
            let message = local("输出目录已更新", "Output directory updated") + ": \(path)"
            setStatus(message)
            logger.log(.info, message)
            notifyIfEnabled(message)
        } else {
            let message = local("已取消目录选择", "Directory selection canceled")
            setStatus(message)
            logger.log(.info, message)
        }
    }

    func openTodayFilePath() -> String {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        return store.todayFileURL().path(percentEncoded: false)
    }

    func openTodayPreview() {
        let path = openTodayFilePath()
        logEvent("UI action openTodayPreview path=\(path)")
        openPreview(filePath: path)
    }

    func openPreview(filePath: String) {
        logEvent("UI action openPreview path=\(filePath)")
        windowPresenter.showPreview(
            initialFilePath: filePath,
            outputDirectoryPath: settings.outputDirectoryPath,
            language: settings.language,
            markdownFontSize: settings.previewMarkdownFontSize,
            calendarScale: settings.previewCalendarScale
        )

        let message = local("已打开预览窗口", "Preview window opened")
        let withContext = message + ": \(filePath)"
        setStatus(message)
        logger.log(.info, withContext)
        logEvent("Preview context outputDirectory=\(settings.outputDirectoryPath)")
    }

    func openAbout() {
        logEvent("UI action openAbout")
        windowPresenter.showAbout(language: settings.language)

        let message = local("已打开关于窗口", "About window opened")
        setStatus(message)
        logger.log(.info, message)
    }

    func openSettings() {
        logEvent("UI action openSettings")
        windowPresenter.showSettings(model: self, language: settings.language)

        let message = local("已打开设置窗口", "Settings window opened")
        setStatus(message)
        logger.log(.info, message)
    }

    func reloadRecentFiles() {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        recentFiles = (try? store.listRecentDailyFiles(limit: 30)) ?? []
    }

    func checkForUpdates() {
        logEvent("UI action checkForUpdates")
        NSApp.activate(ignoringOtherApps: true)
        switch appUpdater.checkForUpdates() {
        case .requested:
            let message = local("已发起更新检查", "Update check requested")
            setStatus(message)
            logger.log(.info, message)
            notifyIfEnabled(message)
        case .skipped(let reason):
            logger.log(.warning, "Update check skipped silently: \(reason)")
        }
    }

    private func handleClipboardText(_ text: String) {
        logger.log(.info, "Clipboard changed, length=\(text.count), allowMultiple=\(settings.allowMultipleLinks)")

        let extractedLinks = MarkdownLinkExtractor.extract(from: text)
        logger.log(.info, "Markdown links extracted=\(extractedLinks.count)")

        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        let result = orchestrator.process(
            clipboardText: text,
            allowMultipleLinks: settings.allowMultipleLinks,
            repositoryDomains: Set(settings.repositoryDomains),
            store: store
        )

        guard result.totalCandidates > 0 else {
            let hint: String
            if extractedLinks.isEmpty {
                hint = local("未识别到 Markdown 链接", "No markdown links detected")
            } else if !settings.allowMultipleLinks && extractedLinks.count > 1 {
                hint = local("检测到多链接，当前已忽略（可开启多链接模式）", "Multiple links ignored (enable multiple-link mode)")
            } else {
                hint = local("已识别链接，但未命中已配置的仓库域名路径", "Links detected but no configured repository domains matched")
            }
            setStatus(hint)
            logger.log(.info, hint)
            return
        }

        let summary = local(
            "识别 \(result.totalCandidates) 个链接，写入 \(result.appendedCount)，克隆 \(result.clonedCount)，跳过 \(result.skippedCount)",
            "Detected \(result.totalCandidates) links, appended \(result.appendedCount), cloned \(result.clonedCount), skipped \(result.skippedCount)"
        )

        setStatus(summary)
        logger.log(.info, summary)
        if result.appendedCount > 0 {
            let writeMessage = local("已写入 markdown", "Markdown updated") + ": \(store.todayFileURL().path(percentEncoded: false))"
            logger.log(.info, writeMessage)
        }
        reloadRecentFiles()

        if !result.errors.isEmpty {
            let errorSummary = local("处理有失败，请查看当日日志", "Processing had failures, check daily log")
            logger.log(.error, result.errors.joined(separator: " | "))
            notifyIfEnabled(errorSummary)
        } else {
            notifyIfEnabled(summary)
        }
    }

    private func updateSettings(_ mutation: (inout AppSettings) -> Void) {
        var next = settings
        mutation(&next)
        settings = next
        settingsStore.save(next)
    }

    private func setStatus(_ message: String) {
        statusText = message
    }

    private func notifyIfEnabled(_ message: String) {
        guard settings.notificationsEnabled else { return }
        notifier.notify(title: text(.appTitle), body: message)
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        settings.language == .zhHans ? zhHans : en
    }

    private func logEvent(_ message: String) {
        guard Diagnostics.verboseEventLogging else { return }
        logger.log(.info, "[event] \(message)")
    }
}
