import AppKit
import MdMCore
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var recentFiles: [URL] = []
    @Published private(set) var statusText: String
    @Published private(set) var latestReleaseTag: String = ""
    @Published private(set) var latestReleaseNotesMarkdown: String = ""
    @Published private(set) var isLoadingLatestReleaseNotes = false
    @Published private(set) var hasUpdateBadge = false
    @Published private(set) var isInstallingCommandLineTool = false
    @Published private(set) var isCommandLineToolInstalled = false
    @Published private(set) var isMainWindowPinned = false
    @Published var toastMessage: String?
    @Published var mainWindowPanel: MainWindowPanel = .preview
    @Published var showBackToCalendarInPreview = false
    @Published var mainWindowTargetFilePath: String = ""
    @Published var mainWindowNavigationToken = UUID()

    private let settingsStore: any SettingsStoring
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let appUpdater: any AppUpdaterManaging
    private let notifier: any UserNotifying
    private let windowPresenter: WindowPresenter
    private let defaults: UserDefaults

    private let memoryLogger: InMemoryLogger
    private let fileLogger: DailyFileLogger
    private let logger: CompositeLogger

    private let orchestrator: ClipboardCaptureOrchestrator
    private var monitor: ClipboardMonitor?
    private let captureProcessingQueue = DispatchQueue(label: "com.y10n.mdmonitor.capture", qos: .utility)
    private var toastHideWorkItem: DispatchWorkItem?
    private var autoUpdateWorkItem: DispatchWorkItem?

    private enum UpdateStateKeys {
        static let lastCheckAt = "mdmonitor.update.lastCheckAt"
        static let cachedLatestReleaseTag = "mdmonitor.update.cachedLatestReleaseTag"
        static let cachedLatestReleaseNotes = "mdmonitor.update.cachedLatestReleaseNotes"
        static let cachedLatestReleaseFetchedAt = "mdmonitor.update.cachedLatestReleaseFetchedAt"
    }

    private enum WindowStateKeys {
        static let mainWindowPinned = "mdmonitor.window.mainWindowPinned"
    }

    private static let autoUpdateInitialDelay: TimeInterval = 60
    private static let autoUpdateCheckInterval: TimeInterval = 60 * 60 * 12
    private static let minimumAutoUpdateRescheduleInterval: TimeInterval = 60
    private static let releaseNotesCacheTTL: TimeInterval = 60 * 60 * 24

    init(
        settingsStore: any SettingsStoring = UserDefaultsSettingsStore(),
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager(),
        appUpdater: any AppUpdaterManaging = SparkleUpdaterManager(),
        notifier: any UserNotifying = UserNotificationManager(),
        windowPresenter: WindowPresenter = WindowPresenter(),
        defaults: UserDefaults = .standard
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginManager = launchAtLoginManager
        self.appUpdater = appUpdater
        self.notifier = notifier
        self.windowPresenter = windowPresenter
        self.defaults = defaults

        let loaded = settingsStore.load()
        self.settings = loaded
        self.statusText = AppLocalizer.text(.statusIdle, language: loaded.language)
        self.isMainWindowPinned = defaults.object(forKey: WindowStateKeys.mainWindowPinned) as? Bool ?? false
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
        logEvent("MenuBarViewModel initialized, monitoring=\(loaded.monitoringEnabled), pinned=\(isMainWindowPinned)")
        refreshCommandLineToolInstallationState()
        reloadRecentFiles()
        restoreCachedReleaseNotes()
        scheduleAutoUpdateChecks()
    }

    func text(_ key: L10nKey) -> String {
        AppLocalizer.text(key, language: settings.language)
    }

    var repositoryDomainsText: String {
        settings.repositoryDomains.joined(separator: "\n")
    }

    var cloneCommandTemplateText: String {
        settings.cloneCommandTemplate
    }

    var commandLineInstallPath: String {
        CommandLineToolInstaller.installLinkPath
    }

    func refreshCommandLineToolInstallationState() {
        isCommandLineToolInstalled = CommandLineToolInstaller.isInstalled(linkPath: commandLineInstallPath)
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

    func updateCloneCommandTemplate(from text: String) {
        let normalized = AppSettings.normalizeCloneCommandTemplate(text)

        updateSettings { state in
            state.cloneCommandTemplate = normalized
        }

        let isFallback = text.trimmingCharacters(in: .whitespacesAndNewlines) != normalized
        let message: String
        if isFallback {
            message = local(
                "克隆命令模板无效，已恢复默认（需包含 {repo}）",
                "Invalid clone template, reverted to default (must include {repo})"
            )
        } else {
            message = local("克隆命令模板已更新", "Clone command template updated")
        }
        setStatus(message)
        logger.log(.info, "\(message): \(normalized)")
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

    func installCommandLineTool() {
        guard !isInstallingCommandLineTool else { return }
        if isCommandLineToolInstalled {
            return
        }
        logEvent("UI action installCommandLineTool")

        guard let executablePath = CommandLineToolInstaller.findBundledExecutablePath() else {
            let message = local(
                "未找到 mdm 可执行文件，请先使用 release 构建或安装正式应用",
                "Unable to find mdm executable. Build release artifacts or install the packaged app first."
            )
            setStatus(message)
            logger.log(.error, message)
            showToast(message)
            return
        }

        isInstallingCommandLineTool = true
        let linkPath = commandLineInstallPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CommandLineToolInstaller.install(
                executablePath: executablePath,
                linkPath: linkPath
            )

            DispatchQueue.main.async {
                guard let self else { return }
                self.isInstallingCommandLineTool = false
                self.refreshCommandLineToolInstallationState()

                switch result {
                case .installed(let path, let requiredAdmin):
                    let message = requiredAdmin
                        ? self.local("mdm 已安装（已完成管理员授权）", "mdm installed (administrator authorization completed)")
                        : self.local("mdm 已安装", "mdm installed")
                    self.setStatus(message)
                    self.logger.log(.info, "\(message): \(path)")
                    self.showToast(message)

                case .cancelled:
                    let message = self.local(
                        "安装 mdm 已取消",
                        "mdm installation canceled"
                    )
                    self.setStatus(message)
                    self.logger.log(.warning, message)
                    self.showToast(message)

                case .failed(let reason):
                    let message = self.local(
                        "安装 mdm 失败，请检查权限或路径",
                        "Failed to install mdm. Check permission and path."
                    )
                    self.setStatus(message)
                    self.logger.log(.error, "\(message): \(reason)")
                    self.showToast(message)
                }
            }
        }
    }

    func pickOutputDirectory(startingPath: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text(.chooseDirectory)
        panel.directoryURL = URL(filePath: NSString(string: startingPath).expandingTildeInPath)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url.path(percentEncoded: false)
    }

    func saveSettings(_ nextDraft: AppSettings) {
        let previous = settings
        var next = nextDraft

        if previous.launchAtLogin != next.launchAtLogin {
            if !launchAtLoginManager.setEnabled(next.launchAtLogin) {
                next.launchAtLogin = previous.launchAtLogin
                let warn = local(
                    "开机启动设置失败，已保留原设置",
                    "Failed to apply launch-at-login change, reverted to previous value"
                )
                logger.log(.warning, warn)
            }
        }

        settings = next
        settingsStore.save(next)
        monitor?.isEnabled = next.monitoringEnabled
        AppActivationPolicyManager.apply(showDockIcon: next.showDockIcon)

        if previous.outputDirectoryPath != next.outputDirectoryPath {
            fileLogger.baseDirectoryPath = next.outputDirectoryPath
            reloadRecentFiles()
        }
        if previous.pinnedWindowOpacity != next.pinnedWindowOpacity ||
            previous.pinnedWindowClickThrough != next.pinnedWindowClickThrough {
            applyMainWindowPinBehavior()
        }

        let message = local("配置已保存", "Settings saved")
        setStatus(message)
        logger.log(.info, message)
        showToast(message)
    }

    func openTodayFilePath() -> String {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        return store.todayFileURL().path(percentEncoded: false)
    }

    func openTodayMainWindow() {
        let path = openTodayFilePath()
        logEvent("UI action openTodayMainWindow path=\(path)")
        openMainWindow(filePath: path, panel: .preview)
    }

    func openMainWindowCalendar() {
        let path = openTodayFilePath()
        logEvent("UI action openMainWindowCalendar path=\(path)")
        openMainWindow(filePath: path, panel: .calendar)
    }

    func openMainWindow(filePath: String, panel: MainWindowPanel = .preview) {
        logEvent("UI action openMainWindow path=\(filePath), panel=\(panel)")
        mainWindowTargetFilePath = filePath
        mainWindowNavigationToken = UUID()
        mainWindowPanel = panel
        if panel != .preview {
            showBackToCalendarInPreview = false
        }
        windowPresenter.showMainWindow(initialFilePath: filePath, model: self)
        applyMainWindowPinBehavior()

        let message = local("已打开主窗口", "Main window opened")
        let withContext = message + ": \(filePath)"
        setStatus(message)
        logger.log(.info, withContext)
        logEvent("Main window context outputDirectory=\(settings.outputDirectoryPath)")
    }

    func openAbout() {
        logEvent("UI action openAbout")
        openMainWindow(filePath: openTodayFilePath(), panel: .help)

        let message = local("已打开帮助面板", "Help panel opened")
        setStatus(message)
        logger.log(.info, message)
    }

    func openSettings() {
        logEvent("UI action openSettings")
        openMainWindow(filePath: openTodayFilePath(), panel: .settings)

        let message = local("已打开设置面板", "Settings panel opened")
        setStatus(message)
        logger.log(.info, message)
    }

    func openUpdatesPanel() {
        logEvent("UI action openUpdatesPanel")
        openMainWindow(filePath: openTodayFilePath(), panel: .updates)
        loadLatestReleaseNotes(force: true)

        let message = local("已打开更新面板", "Updates panel opened")
        setStatus(message)
        logger.log(.info, message)
    }

    func reloadRecentFiles() {
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)
        recentFiles = (try? store.listRecentDailyFiles(limit: 30)) ?? []
    }

    func toggleMainWindowPinned() {
        setMainWindowPinned(!isMainWindowPinned)
    }

    func setMainWindowPinned(_ pinned: Bool) {
        guard isMainWindowPinned != pinned else { return }
        isMainWindowPinned = pinned
        defaults.set(pinned, forKey: WindowStateKeys.mainWindowPinned)
        applyMainWindowPinBehavior()

        let message = pinned ? local("主窗口已置顶", "Main window pinned") : local("主窗口已取消置顶", "Main window unpinned")
        setStatus(message)
        logger.log(.info, message)
        showToast(message)
    }

    func previewMainWindowPinBehavior(opacity: Double, clickThrough: Bool) {
        windowPresenter.previewMainWindowPinState(
            isPinned: isMainWindowPinned,
            pinnedOpacity: opacity,
            clickThroughWhenPinned: clickThrough
        )
    }

    func restoreMainWindowPinBehavior() {
        applyMainWindowPinBehavior()
    }

    @discardableResult
    func checkForUpdates(userInitiated: Bool = true) -> AppUpdateCheckResult {
        if userInitiated {
            logEvent("UI action checkForUpdates")
            NSApp.activate(ignoringOtherApps: true)
        }

        switch appUpdater.checkForUpdates() {
        case .requested:
            let now = Date()
            persistLastUpdateCheck(at: now)
            loadLatestReleaseNotes(force: true, silently: !userInitiated)
            let message = local("已发起更新检查", "Update check requested")
            if userInitiated {
                setStatus(message)
                logger.log(.info, message)
                notifyIfEnabled(message)
                showToast(message)
            } else {
                logger.log(.info, "Automatic update check requested")
            }
            return .requested
        case .skipped(let reason):
            if userInitiated {
                let message = local(
                    "检查更新暂不可用，请稍后重试",
                    "Update check is temporarily unavailable. Please try again."
                )
                setStatus(message)
                showToast(message)
                logger.log(.warning, "Update check skipped: \(reason)")
            } else {
                logger.log(.warning, "Automatic update check skipped: \(reason)")
            }
            return .skipped(reason: reason)
        }
    }

    func loadLatestReleaseNotes(force: Bool = false) {
        loadLatestReleaseNotes(force: force, silently: false)
    }

    private func scheduleAutoUpdateChecks() {
        logger.log(
            .info,
            "Schedule automatic update checks with initial delay \(Int(Self.autoUpdateInitialDelay))s and interval \(Int(Self.autoUpdateCheckInterval))s"
        )
        scheduleAutoUpdateTick(after: Self.autoUpdateInitialDelay)
    }

    private func scheduleAutoUpdateTick(after interval: TimeInterval) {
        autoUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.runAutomaticUpdateMaintenance()
            }
        }
        autoUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    private func runAutomaticUpdateMaintenance() {
        let now = Date()
        if shouldRunAutomaticUpdateCheck(now: now) {
            logger.log(.info, "Automatic update scan started")
            persistLastUpdateCheck(at: now)
            loadLatestReleaseNotes(force: true, silently: true)
            scheduleAutoUpdateTick(after: Self.autoUpdateCheckInterval)
        } else {
            let remaining = remainingUntilNextAutomaticUpdateCheck(now: now)
            logger.log(.info, "Skip automatic update check: next in \(Int(remaining))s")
            scheduleAutoUpdateTick(after: max(Self.minimumAutoUpdateRescheduleInterval, remaining))
        }
    }

    private func shouldRunAutomaticUpdateCheck(now: Date) -> Bool {
        guard let last = lastUpdateCheckAt() else { return true }
        return now.timeIntervalSince(last) >= Self.autoUpdateCheckInterval
    }

    private func remainingUntilNextAutomaticUpdateCheck(now: Date) -> TimeInterval {
        guard let last = lastUpdateCheckAt() else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(last))
        return max(0, Self.autoUpdateCheckInterval - elapsed)
    }

    private func lastUpdateCheckAt() -> Date? {
        guard defaults.object(forKey: UpdateStateKeys.lastCheckAt) != nil else {
            return nil
        }
        return Date(timeIntervalSince1970: defaults.double(forKey: UpdateStateKeys.lastCheckAt))
    }

    private func persistLastUpdateCheck(at date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: UpdateStateKeys.lastCheckAt)
    }

    private func restoreCachedReleaseNotes() {
        let tag = defaults.string(forKey: UpdateStateKeys.cachedLatestReleaseTag) ?? ""
        let notes = defaults.string(forKey: UpdateStateKeys.cachedLatestReleaseNotes) ?? ""
        latestReleaseTag = tag
        latestReleaseNotesMarkdown = notes
        updateAvailabilityBadge(from: tag)

        if !tag.isEmpty || !notes.isEmpty {
            logger.log(.info, "Loaded cached release notes (tag=\(tag.isEmpty ? "-" : tag))")
        }
    }

    private func persistReleaseNotesCache(tag: String, notes: String, fetchedAt: Date) {
        defaults.set(tag, forKey: UpdateStateKeys.cachedLatestReleaseTag)
        defaults.set(notes, forKey: UpdateStateKeys.cachedLatestReleaseNotes)
        defaults.set(fetchedAt.timeIntervalSince1970, forKey: UpdateStateKeys.cachedLatestReleaseFetchedAt)
    }

    private func hasFreshReleaseNotesCache() -> Bool {
        guard !latestReleaseNotesMarkdown.isEmpty else { return false }
        guard !latestReleaseTag.isEmpty else { return false }
        guard defaults.object(forKey: UpdateStateKeys.cachedLatestReleaseFetchedAt) != nil else { return false }

        let fetchedAt = Date(timeIntervalSince1970: defaults.double(forKey: UpdateStateKeys.cachedLatestReleaseFetchedAt))
        guard Date().timeIntervalSince(fetchedAt) < Self.releaseNotesCacheTTL else { return false }

        if let cached = parseSemVer(latestReleaseTag),
           let installed = parseSemVer(AppVersion.semVer),
           cached < installed {
            return false
        }
        return true
    }

    private func loadLatestReleaseNotes(force: Bool, silently: Bool) {
        if isLoadingLatestReleaseNotes {
            return
        }
        if !force && hasFreshReleaseNotesCache() {
            updateAvailabilityBadge(from: latestReleaseTag)
            return
        }

        isLoadingLatestReleaseNotes = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isLoadingLatestReleaseNotes = false }

            guard let url = URL(string: "https://api.github.com/repos/etng/MdLinkMonitor/releases/latest") else {
                if !silently {
                    self.latestReleaseNotesMarkdown = self.local("无法加载更新记录", "Failed to load release notes")
                }
                return
            }

            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("MdMonitor", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    throw NSError(domain: "mdmonitor.updates", code: http.statusCode)
                }

                let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
                let body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedBody = body.isEmpty
                    ? local("该版本暂无更新记录。", "No release notes available for this version.")
                    : body

                latestReleaseTag = payload.tagName
                latestReleaseNotesMarkdown = normalizedBody
                persistReleaseNotesCache(tag: payload.tagName, notes: normalizedBody, fetchedAt: Date())
                updateAvailabilityBadge(from: payload.tagName)
            } catch {
                logger.log(.warning, "Load release notes failed: \(error.localizedDescription)")
                if !silently, latestReleaseNotesMarkdown.isEmpty {
                    latestReleaseNotesMarkdown = local(
                        "更新记录加载失败，请稍后重试。",
                        "Failed to load release notes. Please try again later."
                    )
                }
            }
        }
    }

    private func updateAvailabilityBadge(from latestTag: String) {
        hasUpdateBadge = isNewerReleaseTag(latestTag, than: AppVersion.semVer)
    }

    private func isNewerReleaseTag(_ tag: String, than current: String) -> Bool {
        guard let latest = parseSemVer(tag), let installed = parseSemVer(current) else {
            return false
        }
        return latest > installed
    }

    private func parseSemVer(_ value: String) -> (Int, Int, Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let core = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first ?? Substring(normalized)
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            return nil
        }
        return (major, minor, patch)
    }

    private func handleClipboardText(_ text: String) {
        let settingsSnapshot = settings
        logger.log(.info, "Clipboard changed, length=\(text.count), allowMultiple=\(settingsSnapshot.allowMultipleLinks)")
        let extractedLinks = MarkdownLinkExtractor.extract(from: text)
        logger.log(.info, "Markdown links extracted=\(extractedLinks.count)")

        if extractedLinks.isEmpty {
            let hint = local("未识别到 Markdown 链接", "No markdown links detected")
            setStatus(hint)
            logger.log(.info, hint)
            return
        }

        if !settingsSnapshot.allowMultipleLinks && extractedLinks.count > 1 {
            let hint = local("检测到多链接，当前已忽略（可开启多链接模式）", "Multiple links ignored (enable multiple-link mode)")
            setStatus(hint)
            logger.log(.info, hint)
            return
        }

        let textSnapshot = text
        let outputDirectory = settingsSnapshot.outputDirectoryPath
        let allowMultiple = settingsSnapshot.allowMultipleLinks
        let repositoryDomains = Set(settingsSnapshot.repositoryDomains)
        let cloneCommandTemplate = settingsSnapshot.cloneCommandTemplate
        let cloneDirectoryPath = settingsSnapshot.cloneDirectoryPath
        let orchestrator = self.orchestrator

        captureProcessingQueue.async { [weak self] in
            let store = DailyMarkdownStore(baseDirectoryPath: outputDirectory)
            let result = orchestrator.process(
                clipboardText: textSnapshot,
                allowMultipleLinks: allowMultiple,
                repositoryDomains: repositoryDomains,
                cloneCommandTemplate: cloneCommandTemplate,
                cloneDirectoryPath: cloneDirectoryPath,
                store: store
            )
            let writtenPath = store.todayFileURL().path(percentEncoded: false)

            DispatchQueue.main.async {
                guard let self else { return }

                guard result.totalCandidates > 0 else {
                    let hint = self.local(
                        "已识别链接，但未命中已配置的仓库域名路径",
                        "Links detected but no configured repository domains matched"
                    )
                    self.setStatus(hint)
                    self.logger.log(.info, hint)
                    return
                }

                let summary = self.local(
                    "识别 \(result.totalCandidates) 个链接，写入 \(result.appendedCount)，克隆 \(result.clonedCount)，跳过 \(result.skippedCount)",
                    "Detected \(result.totalCandidates) links, appended \(result.appendedCount), cloned \(result.clonedCount), skipped \(result.skippedCount)"
                )

                self.setStatus(summary)
                self.logger.log(.info, summary)
                if result.appendedCount > 0 {
                    let writeMessage = self.local("已写入 markdown", "Markdown updated") + ": \(writtenPath)"
                    self.logger.log(.info, writeMessage)
                }
                self.reloadRecentFiles()

                if !result.errors.isEmpty {
                    let errorSummary = self.local("处理有失败，请查看当日日志", "Processing had failures, check daily log")
                    self.logger.log(.error, result.errors.joined(separator: " | "))
                    self.notifyIfEnabled(errorSummary)
                } else {
                    self.notifyIfEnabled(summary)
                }
            }
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

    func showToast(_ message: String, duration: TimeInterval = 1.8) {
        toastHideWorkItem?.cancel()
        toastMessage = message

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
        toastHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func notifyIfEnabled(_ message: String) {
        guard settings.notificationsEnabled else { return }
        notifier.notify(title: text(.appTitle), body: message)
    }

    private func applyMainWindowPinBehavior() {
        windowPresenter.updateMainWindowPinState(
            isPinned: isMainWindowPinned,
            pinnedOpacity: settings.pinnedWindowOpacity,
            clickThroughWhenPinned: settings.pinnedWindowClickThrough
        )
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        settings.language == .zhHans ? zhHans : en
    }

    private func logEvent(_ message: String) {
        guard Diagnostics.verboseEventLogging else { return }
        logger.log(.info, "[event] \(message)")
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
    }
}
