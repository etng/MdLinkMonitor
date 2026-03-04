import CBMCore
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case capture
    case repository
    case window
    case system

    var id: String { rawValue }
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
    @State private var previewMarkdownFontSize = 16.0
    @State private var previewCalendarScale = 1.15
    @State private var outputDirectoryPath = ""
    @State private var language: AppLanguage = .zhHans
    @State private var repositoryDomainsText = ""
    @State private var cloneCommandTemplateText = ""
    @State private var cloneDirectoryPath = ""
    @State private var isInitialized = false

    var body: some View {
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
                VStack(alignment: .leading, spacing: 18) {
                    sectionContent
                }
                .padding(16)
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

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .capture:
            toggleField(
                title: model.text(.enableMonitoring),
                help: local("控制是否监听剪贴板并处理链接。", "Control whether clipboard links are monitored and processed."),
                isOn: $monitoringEnabled
            )

            toggleField(
                title: model.text(.enableNotifications),
                help: local("启用后会在关键操作完成时发送系统通知。", "Show system notifications for key operation results."),
                isOn: $notificationsEnabled
            )

            toggleField(
                title: model.text(.allowMultipleLinks),
                help: local("关闭时只处理恰好一个 Markdown 链接的复制内容。", "When disabled, only clipboard content with exactly one markdown link is processed."),
                isOn: $allowMultipleLinks
            )

            toggleField(
                title: model.text(.launchAtLogin),
                help: local("系统登录后自动启动 MdMonitor。", "Start MdMonitor automatically after user login."),
                isOn: $launchAtLogin
            )

        case .repository:
            VStack(alignment: .leading, spacing: 8) {
                fieldHeader(
                    title: model.text(.repositoryDomains),
                    help: local("每行一个域名，例如 github.com、gitlab.com。", "One domain per line, for example github.com or gitlab.com.")
                )
                TextEditor(text: $repositoryDomainsText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader(
                    title: model.text(.cloneCommandTemplate),
                    help: local(
                        "命令中必须包含 {repo} 占位符，程序会替换为仓库地址。",
                        "Template must include {repo}; the app replaces it with the repository URL."
                    )
                )
                TextField(model.text(.cloneCommandPlaceholder), text: $cloneCommandTemplateText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader(
                    title: model.text(.cloneDirectory),
                    help: local(
                        "仓库克隆时的默认工作目录（会自动创建）。",
                        "Default working directory for clone commands (created automatically)."
                    )
                )
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

        case .window:
            toggleField(
                title: model.text(.showDockIcon),
                help: local("控制是否在 Dock 和 Cmd+Tab 中显示应用图标。", "Control Dock and Cmd+Tab icon visibility."),
                isOn: $showDockIcon
            )

            sliderField(
                title: model.text(.pinWindowOpacity),
                help: local(
                    "置顶时长期生效；在设置页可实时预览透明度。",
                    "Applied persistently when pinned; also previewed live while editing settings."
                ),
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
                isOn: $pinnedWindowClickThrough
            )

            sliderField(
                title: model.text(.previewMarkdownFontSize),
                help: local("调整 Markdown 预览区字体大小。", "Adjust markdown preview font size."),
                valueText: "\(Int(previewMarkdownFontSize))",
                value: $previewMarkdownFontSize,
                range: 12...28,
                step: 1
            )

            sliderField(
                title: model.text(.previewCalendarScale),
                help: local("调整日历视图整体缩放。", "Adjust calendar view scale."),
                valueText: String(format: "%.2f", previewCalendarScale),
                value: $previewCalendarScale,
                range: 0.9...1.8,
                step: 0.05
            )

        case .system:
            VStack(alignment: .leading, spacing: 8) {
                fieldHeader(
                    title: model.text(.outputDirectory),
                    help: local("用于保存每日 markdown 与日志文件。", "Directory for daily markdown and log files.")
                )
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

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader(
                    title: model.text(.language),
                    help: local("切换界面语言，保存后立即生效。", "Switch application language. Takes effect right after save.")
                )
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
            cloneCommandTemplate: cloneCommandTemplateText,
            cloneDirectoryPath: cloneDirectoryPath,
            pinnedWindowOpacity: pinnedWindowOpacity,
            pinnedWindowClickThrough: pinnedWindowClickThrough,
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
        previewMarkdownFontSize = current.previewMarkdownFontSize
        previewCalendarScale = current.previewCalendarScale
        outputDirectoryPath = current.outputDirectoryPath
        language = current.language
        repositoryDomainsText = current.repositoryDomains.joined(separator: "\n")
        cloneCommandTemplateText = current.cloneCommandTemplate
        cloneDirectoryPath = current.cloneDirectoryPath
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

    @ViewBuilder
    private func toggleField(title: String, help: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldHeader(title: title, help: help)
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
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldHeader(title: title, help: help)
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func fieldHeader(title: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        model.settings.language == .zhHans ? zhHans : en
    }
}
