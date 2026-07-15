import MdMCore
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case capture
    case repository
    case window
    case system

    var id: String { rawValue }
}

private enum SettingsHelpMode {
    case inline
    case hover
}

private struct HoverHelpBadge: View {
    let text: String
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            if isHovering {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 280, alignment: .leading)
                    .offset(x: 18, y: -6)
                    .zIndex(1)
            }
        }
        .frame(width: 14, height: 14)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(text)
    }
}

struct SettingsView: View {
    @ObservedObject var model: MenuBarViewModel
    @ObservedObject var draftCoordinator: SettingsDraftCoordinator

    @State private var selectedSection: SettingsSection = .capture
    @State private var pendingSection: SettingsSection?
    @State private var showUnsavedSectionAlert = false

    @State private var monitoringEnabled = true
    @State private var notificationsEnabled = true
    @State private var allowMultipleLinks = false
    @State private var showDockIcon = true
    @State private var launchAtLogin = false
    @State private var pinnedWindowOpacity = AppSettings.defaultPinnedWindowOpacity
    @State private var pinnedWindowClickThrough = false
    @State private var autoMergeMacWindowsEnabled = false
    @State private var autoMergeMacWindowsBundleIDsText = ""
    @State private var logRetentionDaysText = String(AppSettings.defaultLogRetentionDays)
    @State private var previewMarkdownFontSize = 16.0
    @State private var previewCalendarScale = 1.15
    @State private var outputDirectoryPath = ""
    @State private var language: AppLanguage = .zhHans
    @State private var repositoryDomainsText = ""
    @State private var metadataFetchAllowedDomainsText = ""
    @State private var attachmentResourceDirectoryPath = AppSettings.defaultAttachmentResourceDirectoryPath
    @State private var dailyReferenceDirectoryPath = ""
    @State private var dailyReferenceSectionHeading = AppSettings.defaultDailyReferenceSectionHeading
    @State private var openSearchResultLinksDirectly = false
    @State private var cloneCommandTemplateText = ""
    @State private var cloneDirectoryPath = ""
    @State private var restAPIEnabled = false
    @State private var restAPIBindAddress = AppSettings.defaultRestAPIBindAddress
    @State private var restAPIPortText = String(AppSettings.defaultRestAPIPort)
    @State private var restAPIToken = AppSettings.defaultRestAPIToken
    @State private var experimentalSettingsTabsEnabled = false
    @State private var isInitialized = false

    private let settingsLabelColumnWidth: CGFloat = 210

    var body: some View {
        VStack(spacing: 0) {
            if experimentalSettingsTabsEnabled {
                experimentalTabsBody
            } else {
                groupedFormBody
            }

            Divider()

            HStack(spacing: 10) {
                Text(isDirty ? local("有未保存更改", "Unsaved changes") : local("配置已同步", "All changes saved"))
                    .font(.caption)
                    .foregroundStyle(isDirty ? Color.orange : .secondary)

                Spacer()

                Button(local("恢复", "Discard")) {
                    discardDraft()
                }
                .buttonStyle(.bordered)
                .disabled(!isDirty)

                Button {
                    saveDraft()
                } label: {
                    Label(model.text(.saveSettings), systemImage: "externaldrive.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 620, minHeight: 620)
        .onAppear {
            syncFromModel()
            model.refreshCommandLineToolInstallationState()
            isInitialized = true
            applyPreviewPinStyle()
            draftCoordinator.saveChanges = { saveDraft() }
            draftCoordinator.discardChanges = { discardDraft() }
            draftCoordinator.hasUnsavedChanges = isDirty
        }
        .onChange(of: model.settings) { _ in
            syncFromModel()
            if isInitialized {
                applyPreviewPinStyle()
                draftCoordinator.hasUnsavedChanges = isDirty
            }
        }
        .onChange(of: pinnedWindowOpacity) { _ in
            guard isInitialized else { return }
            applyPreviewPinStyle()
        }
        .onChange(of: pinnedWindowClickThrough) { _ in
            guard isInitialized else { return }
            applyPreviewPinStyle()
        }
        .onChange(of: isDirty) { dirty in
            draftCoordinator.hasUnsavedChanges = dirty
        }
        .onDisappear {
            isInitialized = false
            draftCoordinator.hasUnsavedChanges = false
            draftCoordinator.saveChanges = nil
            draftCoordinator.discardChanges = nil
            model.restoreMainWindowPinBehavior()
        }
        .alert(local("检测到未保存更改", "Unsaved changes"), isPresented: $showUnsavedSectionAlert) {
            Button(local("保存并切换", "Save & Switch")) {
                saveDraft()
                applyPendingSectionChange()
            }
            Button(local("恢复并切换", "Discard & Switch"), role: .destructive) {
                discardDraft()
                applyPendingSectionChange()
            }
            Button(local("取消", "Cancel"), role: .cancel) {
                pendingSection = nil
            }
        } message: {
            Text(local("当前分组有未保存修改。", "Current section has unsaved changes."))
        }
    }

    private var experimentalTabsBody: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(
                get: { selectedSection },
                set: { attemptSwitchSection($0) }
            )) {
                ForEach(SettingsSection.allCases) { section in
                    Text(sectionTitle(section)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionFields(selectedSection, helpMode: .inline)
                }
                .padding(16)
            }
        }
    }

    private var groupedFormBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                groupedSection(.capture) {
                    sectionFields(.capture, helpMode: .hover)
                }
                groupedSection(.repository) {
                    sectionFields(.repository, helpMode: .hover)
                }
                groupedSection(.window) {
                    sectionFields(.window, helpMode: .hover)
                }
                groupedSection(.system) {
                    sectionFields(.system, helpMode: .hover)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func groupedSection<Content: View>(_ section: SettingsSection, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: sectionSymbol(section))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(sectionTitle(section))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionFields(_ section: SettingsSection, helpMode: SettingsHelpMode) -> some View {
        switch section {
        case .capture:
            toggleField(
                title: model.text(.enableMonitoring),
                help: local("控制是否监听剪贴板并处理链接。", "Control whether clipboard links are monitored and processed."),
                helpMode: helpMode,
                isOn: $monitoringEnabled
            )

            toggleField(
                title: model.text(.enableNotifications),
                help: local("启用后会在关键操作完成时发送系统通知。", "Show system notifications for key operation results."),
                helpMode: helpMode,
                isOn: $notificationsEnabled
            )

            toggleField(
                title: model.text(.allowMultipleLinks),
                help: local("关闭时只处理恰好一个 Markdown 链接的复制内容。", "When disabled, only clipboard content with exactly one markdown link is processed."),
                helpMode: helpMode,
                isOn: $allowMultipleLinks
            )

            toggleField(
                title: model.text(.launchAtLogin),
                help: local(
                    "系统登录后自动启动 MdMonitor。仅支持从 /Applications 或 ~/Applications 中已安装的 app 设置。",
                    "Start MdMonitor automatically after user login. Requires the app installed in /Applications or ~/Applications."
                ),
                helpMode: helpMode,
                isOn: $launchAtLogin
            )

            toggleField(
                title: local("搜索结果点击后直接打开链接", "Open Search Result Link Directly"),
                help: local(
                    "开启后，点击搜索结果会直接用默认浏览器打开对应链接；关闭时会先弹确认。",
                    "When enabled, clicking a search result opens its link in the default browser immediately. When disabled, MdMonitor asks for confirmation first."
                ),
                helpMode: helpMode,
                isOn: $openSearchResultLinksDirectly
            )

        case .repository:
            settingRow(
                title: model.text(.repositoryDomains),
                help: local("每行一个域名，例如 github.com、gitlab.com。", "One domain per line, for example github.com or gitlab.com."),
                helpMode: helpMode,
                topAligned: true
            ) {
                TextEditor(text: $repositoryDomainsText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    }
            }

            settingRow(
                title: local("纯 URL 元数据白名单", "Plain URL Metadata Allowlist"),
                help: local(
                    "每行一个域名。命中这些域名的单个纯 URL 时，会直接抓取页面标题和简介后写入 Markdown，例如 chromewebstore.google.com。",
                    "One domain per line. When the clipboard contains a single plain URL on these domains, MdMonitor fetches the page title and summary before writing markdown, for example chromewebstore.google.com."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                TextEditor(text: $metadataFetchAllowedDomainsText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    }
            }

            settingRow(
                title: model.text(.cloneCommandTemplate),
                help: local(
                    "命令中必须包含 {repo} 占位符，程序会替换为仓库地址。",
                    "Template must include {repo}; the app replaces it with the repository URL."
                ),
                helpMode: helpMode
            ) {
                TextField(model.text(.cloneCommandPlaceholder), text: $cloneCommandTemplateText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingRow(
                title: model.text(.cloneDirectory),
                help: local(
                    "仓库克隆时的默认工作目录（会自动创建）。",
                    "Default working directory for clone commands (created automatically)."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(cloneDirectoryPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(model.text(.chooseDirectory)) {
                        if let path = model.pickOutputDirectory(startingPath: cloneDirectoryPath) {
                            cloneDirectoryPath = path
                        }
                    }
                }
            }

            settingRow(
                title: local("附件资源目录", "Attachment Resource Directory"),
                help: local(
                    "首次使用时会读取 Obsidian 当前或最近打开的 Vault。这里用于递归匹配 {md5}_MD.{ext} 外部资源文件。",
                    "On first use, MdMonitor reads Obsidian's active or most recently opened vault. This directory is used to match external {md5}_MD.{ext} resource files."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(attachmentResourceDirectoryPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 8) {
                        Button(model.text(.chooseDirectory)) {
                            if let selectedDirectory = model.pickOutputDirectory(startingPath: attachmentResourceDirectoryPath) {
                                attachmentResourceDirectoryPath = selectedDirectory
                            }
                        }

                        Button {
                            readPreferredObsidianVault()
                        } label: {
                            Label(local("从 Obsidian 读取", "Read from Obsidian"), systemImage: "magnifyingglass")
                        }
                    }
                }
            }

            settingRow(
                title: local("Obsidian Daily 根目录", "Obsidian Daily Root Directory"),
                help: local(
                    "用于把 ~/Documents/cbm/links_YYYYMMDD.md 合并进 daily/YYMM/daily_YYMMDD.md。",
                    "Used to merge ~/Documents/cbm/links_YYYYMMDD.md into daily/YYMM/daily_YYMMDD.md."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dailyReferenceDirectoryPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(model.text(.chooseDirectory)) {
                        if let path = model.pickOutputDirectory(startingPath: dailyReferenceDirectoryPath) {
                            dailyReferenceDirectoryPath = path
                        }
                    }
                }
            }

            settingRow(
                title: local("Daily 参考链接锚点", "Daily Reference Section Heading"),
                help: local(
                    "只会改这个标题下面的链接段落，默认是 ## 参考链接。",
                    "Only the link section under this heading is rewritten. Default is ## 参考链接."
                ),
                helpMode: helpMode
            ) {
                TextField(AppSettings.defaultDailyReferenceSectionHeading, text: $dailyReferenceSectionHeading)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .window:
            toggleField(
                title: model.text(.showDockIcon),
                help: local("控制是否在 Dock 和 Cmd+Tab 中显示应用图标。", "Control Dock and Cmd+Tab icon visibility."),
                helpMode: helpMode,
                isOn: $showDockIcon
            )

            sliderField(
                title: model.text(.pinWindowOpacity),
                help: local(
                    "置顶时长期生效；在设置页可实时预览透明度。",
                    "Applied persistently when pinned; also previewed live while editing settings."
                ),
                helpMode: helpMode,
                valueText: "\(Int(pinnedWindowOpacity * 100))%",
                value: $pinnedWindowOpacity,
                range: 0.4...1.0,
                step: 0.05
            )

            toggleField(
                title: model.text(.pinWindowClickThrough),
                help: local(
                    "开启后，置顶窗口会让鼠标事件穿透到下层应用。",
                    "When enabled, pinned window lets mouse events pass through to underlying apps."
                ),
                helpMode: helpMode,
                isOn: $pinnedWindowClickThrough
            )

            toggleField(
                title: local("自动合并窗口", "Auto Merge Windows"),
                help: local(
                    "开启后监听目标应用窗口并尝试执行 Window -> Merge All Windows（需要辅助功能权限）。",
                    "When enabled, observe target apps and try Window -> Merge All Windows (requires Accessibility permission)."
                ),
                helpMode: helpMode,
                isOn: $autoMergeMacWindowsEnabled
            )

            settingRow(
                title: local("目标 bundleId（每行一个，可选）", "Target bundleIds (One Per Line, Optional)"),
                help: local(
                    "留空表示对所有应用生效；填写后仅对这些 bundleId 生效，例如 com.apple.Safari。",
                    "Leave empty to apply to all apps. Fill one bundleId per line to target only those apps, e.g. com.apple.Safari."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                TextEditor(text: $autoMergeMacWindowsBundleIDsText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            sliderField(
                title: model.text(.previewMarkdownFontSize),
                help: local("调整 Markdown 预览区字体大小。", "Adjust markdown preview font size."),
                helpMode: helpMode,
                valueText: "\(Int(previewMarkdownFontSize))",
                value: $previewMarkdownFontSize,
                range: 12...28,
                step: 1
            )

            sliderField(
                title: model.text(.previewCalendarScale),
                help: local("调整日历视图整体缩放。", "Adjust calendar view scale."),
                helpMode: helpMode,
                valueText: String(format: "%.2f", previewCalendarScale),
                value: $previewCalendarScale,
                range: 0.9...1.8,
                step: 0.05
            )

        case .system:
            toggleField(
                title: local("启用本地 REST API", "Enable Local REST API"),
                help: local(
                    "开启后提供 HTTP 接口用于提交 Markdown 链接与读取每日内容。",
                    "Expose HTTP endpoints for submitting markdown links and reading daily content."
                ),
                helpMode: helpMode,
                isOn: $restAPIEnabled
            )

            settingRow(
                title: local("REST 监听地址", "REST Bind Address"),
                help: local(
                    "默认 127.0.0.1，仅本机可访问。可按需改为 0.0.0.0 对局域网开放。",
                    "Default is 127.0.0.1 (local only). Change to 0.0.0.0 only when LAN access is required."
                ),
                helpMode: helpMode
            ) {
                TextField(AppSettings.defaultRestAPIBindAddress, text: $restAPIBindAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingRow(
                title: local("REST 端口", "REST Port"),
                help: local(
                    "端口范围 1-65535，默认 18731。",
                    "Port range is 1-65535, default is 18731."
                ),
                helpMode: helpMode
            ) {
                TextField("", text: $restAPIPortText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingRow(
                title: local("REST Token", "REST Token"),
                help: local(
                    "请求需带 Authorization: Bearer <token> 或 X-MDM-Token。可点击按钮随机生成。",
                    "Requests require Authorization: Bearer <token> or X-MDM-Token. Use Generate for a random token."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("", text: $restAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(local("随机生成 Token", "Generate Token")) {
                        restAPIToken = AppSettings.makeRandomRestAPIToken()
                    }
                    .buttonStyle(.bordered)
                }
            }

            settingRow(
                title: local("命令行工具", "Command Line Tool"),
                help: local(
                    "安装后可在终端使用 \(model.commandLineToolName) 命令。默认安装到 \(model.commandLineInstallPath)，且必须从 /Applications 或 ~/Applications 中已安装的 app 执行，必要时会请求管理员授权。",
                    "Install the \(model.commandLineToolName) command for terminal usage. It links to \(model.commandLineInstallPath), must be run from an installed app in /Applications or ~/Applications, and may request administrator authorization."
                ),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.commandLineInstallPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if model.isCommandLineToolInstalled {
                        Label(
                            local("\(model.commandLineToolName) 已安装", "\(model.commandLineToolName) installed"),
                            systemImage: "checkmark.seal.fill"
                        )
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            model.installCommandLineTool()
                        } label: {
                            Label(
                                model.isInstallingCommandLineTool
                                    ? local("正在安装 \(model.commandLineToolName)…", "Installing \(model.commandLineToolName)...")
                                    : local("安装 \(model.commandLineToolName) 命令", "Install \(model.commandLineToolName) Command"),
                                systemImage: model.isInstallingCommandLineTool ? "hourglass.circle" : "terminal"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isInstallingCommandLineTool)
                    }
                }
            }

            toggleField(
                title: local("启用实验设置界面", "Enable Experimental Settings UI"),
                help: local("开启后使用分组 Tab 的设置界面。关闭后使用单页分组表单。", "Use tabbed settings UI when enabled. Use single grouped form when disabled."),
                helpMode: helpMode,
                isOn: $experimentalSettingsTabsEnabled
            )

            settingRow(
                title: local("日志保留天数", "Log Retention Days"),
                help: local(
                    "只清理 logs_YYYYMMDD.log。填 0 表示不自动清理；填 7 表示只保留最近 7 天日志。",
                    "Only affects logs_YYYYMMDD.log. Use 0 to disable cleanup; use 7 to keep the most recent 7 days of logs."
                ),
                helpMode: helpMode
            ) {
                TextField("0", text: $logRetentionDaysText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingRow(
                title: model.text(.outputDirectory),
                help: local("用于保存每日 markdown 与日志文件。", "Directory for daily markdown and log files."),
                helpMode: helpMode,
                topAligned: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(outputDirectoryPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(model.text(.chooseDirectory)) {
                        if let path = model.pickOutputDirectory(startingPath: outputDirectoryPath) {
                            outputDirectoryPath = path
                        }
                    }
                }
            }

            settingRow(
                title: model.text(.language),
                help: local("切换界面语言，保存后立即生效。", "Switch application language. Takes effect right after save."),
                helpMode: helpMode
            ) {
                Picker("", selection: $language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var normalizedDraftSettings: AppSettings {
        let parsedDomains = AppSettings.parseDomains(from: repositoryDomainsText)
        let fallbackDomains = parsedDomains.isEmpty ? ["github.com", "gitlab.com"] : parsedDomains
        let metadataDomains = AppSettings.parseDomains(from: metadataFetchAllowedDomainsText)
        let parsedPort = Int(restAPIPortText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? AppSettings.defaultRestAPIPort
        let parsedLogRetentionDays = Int(logRetentionDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? AppSettings.defaultLogRetentionDays
        return AppSettings(
            monitoringEnabled: monitoringEnabled,
            notificationsEnabled: notificationsEnabled,
            allowMultipleLinks: allowMultipleLinks,
            showDockIcon: showDockIcon,
            previewMarkdownFontSize: previewMarkdownFontSize,
            previewCalendarScale: previewCalendarScale,
            launchAtLogin: launchAtLogin,
            outputDirectoryPath: outputDirectoryPath,
            repositoryDomains: fallbackDomains,
            metadataFetchAllowedDomains: metadataDomains,
            attachmentResourceDirectoryPath: attachmentResourceDirectoryPath,
            dailyReferenceDirectoryPath: dailyReferenceDirectoryPath,
            dailyReferenceSectionHeading: dailyReferenceSectionHeading,
            openSearchResultLinksDirectly: openSearchResultLinksDirectly,
            cloneCommandTemplate: cloneCommandTemplateText,
            cloneDirectoryPath: cloneDirectoryPath,
            pinnedWindowOpacity: pinnedWindowOpacity,
            pinnedWindowClickThrough: pinnedWindowClickThrough,
            autoMergeMacWindowsEnabled: autoMergeMacWindowsEnabled,
            autoMergeMacWindowsBundleIDs: AppSettings.parseBundleIDs(from: autoMergeMacWindowsBundleIDsText),
            logRetentionDays: parsedLogRetentionDays,
            restAPIEnabled: restAPIEnabled,
            restAPIBindAddress: restAPIBindAddress,
            restAPIPort: parsedPort,
            restAPIToken: restAPIToken,
            experimentalSettingsTabsEnabled: experimentalSettingsTabsEnabled,
            language: language
        )
    }

    private var isDirty: Bool {
        isInitialized && normalizedDraftSettings != model.settings
    }

    private func syncFromModel() {
        let current = model.settings
        monitoringEnabled = current.monitoringEnabled
        notificationsEnabled = current.notificationsEnabled
        allowMultipleLinks = current.allowMultipleLinks
        showDockIcon = current.showDockIcon
        launchAtLogin = current.launchAtLogin
        pinnedWindowOpacity = current.pinnedWindowOpacity
        pinnedWindowClickThrough = current.pinnedWindowClickThrough
        autoMergeMacWindowsEnabled = current.autoMergeMacWindowsEnabled
        autoMergeMacWindowsBundleIDsText = current.autoMergeMacWindowsBundleIDs.joined(separator: "\n")
        logRetentionDaysText = String(current.logRetentionDays)
        previewMarkdownFontSize = current.previewMarkdownFontSize
        previewCalendarScale = current.previewCalendarScale
        outputDirectoryPath = current.outputDirectoryPath
        language = current.language
        repositoryDomainsText = current.repositoryDomains.joined(separator: "\n")
        metadataFetchAllowedDomainsText = current.metadataFetchAllowedDomains.joined(separator: "\n")
        attachmentResourceDirectoryPath = current.attachmentResourceDirectoryPath
        dailyReferenceDirectoryPath = current.dailyReferenceDirectoryPath
        dailyReferenceSectionHeading = current.dailyReferenceSectionHeading
        openSearchResultLinksDirectly = current.openSearchResultLinksDirectly
        cloneCommandTemplateText = current.cloneCommandTemplate
        cloneDirectoryPath = current.cloneDirectoryPath
        restAPIEnabled = current.restAPIEnabled
        restAPIBindAddress = current.restAPIBindAddress
        restAPIPortText = String(current.restAPIPort)
        restAPIToken = current.restAPIToken
        experimentalSettingsTabsEnabled = current.experimentalSettingsTabsEnabled
    }

    private func saveDraft() {
        model.saveSettings(normalizedDraftSettings)
        syncFromModel()
        applyPreviewPinStyle()
    }

    private func discardDraft() {
        syncFromModel()
        applyPreviewPinStyle()
    }

    private func readPreferredObsidianVault() {
        guard let vault = model.preferredObsidianVault() else {
            model.showToast(local(
                "未检测到可用的 Obsidian Vault，请手动选择目录",
                "No available Obsidian vault was found. Choose the directories manually."
            ))
            return
        }

        attachmentResourceDirectoryPath = vault.attachmentResourceDirectoryPath
        dailyReferenceDirectoryPath = vault.dailyReferenceDirectoryPath
        model.showToast(local(
            "已读取 Obsidian Vault，保存后生效",
            "Obsidian vault detected. Save to apply."
        ))
    }

    private func applyPreviewPinStyle() {
        model.previewMainWindowPinBehavior(
            opacity: pinnedWindowOpacity,
            clickThrough: pinnedWindowClickThrough
        )
    }

    private func attemptSwitchSection(_ next: SettingsSection) {
        guard next != selectedSection else { return }
        guard isDirty else {
            selectedSection = next
            return
        }
        pendingSection = next
        showUnsavedSectionAlert = true
    }

    private func applyPendingSectionChange() {
        if let pendingSection {
            selectedSection = pendingSection
        }
        self.pendingSection = nil
    }

    private func sectionTitle(_ section: SettingsSection) -> String {
        switch section {
        case .capture: return local("采集", "Capture")
        case .repository: return local("仓库", "Repositories")
        case .window: return local("窗口", "Window")
        case .system: return local("系统", "System")
        }
    }

    private func sectionSymbol(_ section: SettingsSection) -> String {
        switch section {
        case .capture: return "doc.on.clipboard"
        case .repository: return "shippingbox"
        case .window: return "rectangle.3.group"
        case .system: return "gearshape.2"
        }
    }

    @ViewBuilder
    private func settingRow<Control: View>(
        title: String,
        help: String,
        helpMode: SettingsHelpMode,
        topAligned: Bool = false,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: topAligned ? .top : .center, spacing: 12) {
            settingLabel(title: title, help: help, helpMode: helpMode, topAligned: topAligned)
            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func settingLabel(
        title: String,
        help: String,
        helpMode: SettingsHelpMode,
        topAligned: Bool
    ) -> some View {
        switch helpMode {
        case .inline:
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: settingsLabelColumnWidth, alignment: topAligned ? .topLeading : .leading)

        case .hover:
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HoverHelpBadge(text: help)
            }
            .frame(width: settingsLabelColumnWidth, alignment: topAligned ? .topLeading : .leading)
        }
    }

    @ViewBuilder
    private func toggleField(
        title: String,
        help: String,
        helpMode: SettingsHelpMode,
        isOn: Binding<Bool>
    ) -> some View {
        settingRow(title: title, help: help, helpMode: helpMode) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
        }
    }

    @ViewBuilder
    private func sliderField(
        title: String,
        help: String,
        helpMode: SettingsHelpMode,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        settingRow(title: title, help: help, helpMode: helpMode) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        model.settings.language == .zhHans ? zhHans : en
    }
}
