import CBMCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MenuBarViewModel

    @State private var monitoringEnabled = true
    @State private var notificationsEnabled = true
    @State private var allowMultipleLinks = false
    @State private var showDockIcon = true
    @State private var launchAtLogin = false
    @State private var previewMarkdownFontSize = 16.0
    @State private var previewCalendarScale = 1.15
    @State private var outputDirectoryPath = ""
    @State private var language: AppLanguage = .zhHans
    @State private var repositoryDomainsText = ""
    @State private var cloneCommandTemplateText = ""
    @State private var isInitialized = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                    title: model.text(.showDockIcon),
                    help: local("控制是否在 Dock 和 Cmd+Tab 中显示应用图标。", "Control Dock and Cmd+Tab icon visibility."),
                    isOn: $showDockIcon
                )

                toggleField(
                    title: model.text(.launchAtLogin),
                    help: local("系统登录后自动启动 MdMonitor。", "Start MdMonitor automatically after user login."),
                    isOn: $launchAtLogin
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

                VStack(alignment: .leading, spacing: 8) {
                    fieldHeader(
                        title: model.text(.repositoryDomains),
                        help: local("每行一个域名，例如 github.com、gitlab.com。", "One domain per line, for example github.com or gitlab.com.")
                    )
                    TextEditor(text: $repositoryDomainsText)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(minHeight: 120)
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

                if isDirty {
                    HStack {
                        Spacer()
                        Button(model.text(.saveSettings)) {
                            model.saveSettings(normalizedDraftSettings)
                            syncFromModel()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 620, minHeight: 620)
        .onAppear {
            syncFromModel()
            isInitialized = true
        }
        .onChange(of: model.settings) { _ in
            syncFromModel()
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
        previewMarkdownFontSize = current.previewMarkdownFontSize
        previewCalendarScale = current.previewCalendarScale
        outputDirectoryPath = current.outputDirectoryPath
        language = current.language
        repositoryDomainsText = current.repositoryDomains.joined(separator: "\n")
        cloneCommandTemplateText = current.cloneCommandTemplate
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
                    .frame(minWidth: 48, alignment: .trailing)
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
