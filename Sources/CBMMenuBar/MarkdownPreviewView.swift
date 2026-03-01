import AppKit
import CBMCore
import MarkdownUI
import SwiftUI

private enum PreviewPanel: CaseIterable {
    case preview
    case calendar
    case settings
    case updates
    case about

    var symbolName: String {
        switch self {
        case .preview: return "doc.text.image"
        case .calendar: return "calendar"
        case .settings: return "slider.horizontal.3"
        case .updates: return "arrow.triangle.2.circlepath"
        case .about: return "info.circle"
        }
    }
}

struct MarkdownPreviewView: View {
    let initialFilePath: String
    @ObservedObject var model: MenuBarViewModel

    @State private var files: [URL] = []
    @State private var filesByYMD: [String: URL] = [:]
    @State private var selectedDate = Date()
    @State private var selectedDateHasRecord = false

    @State private var selectedPanel: PreviewPanel = .preview
    @State private var hoveredPanel: PreviewPanel?
    @State private var isCalendarQuickExpanded = false

    @State private var selectedFilePath: String?
    @State private var content = ""
    @State private var copyFeedbackVisible = false

    @State private var showLogPanel = false
    @State private var todayLogContent = ""

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let markdownBottomAnchor = "markdown-bottom-anchor"

    var body: some View {
        HStack(spacing: 0) {
            leftSidebar
            Divider()
            rightPanel
        }
        .frame(minWidth: 980, minHeight: 680)
        .onAppear(perform: reloadFilesAndContent)
        .onChange(of: selectedDate) { _ in
            syncSelectedFileForSelectedDate()
        }
        .onChange(of: selectedFilePath) { _ in
            loadSelectedContent()
            loadTodayLog()
        }
        .onChange(of: model.settings.outputDirectoryPath) { _ in
            reloadFilesAndContent()
        }
        .onReceive(refreshTimer) { _ in
            refreshLivePanels()
        }
    }

    private var language: AppLanguage {
        model.settings.language
    }

    private var outputDirectoryPath: String {
        model.settings.outputDirectoryPath
    }

    private var markdownFontSize: Double {
        model.settings.previewMarkdownFontSize
    }

    private var calendarScale: Double {
        model.settings.previewCalendarScale
    }

    private var sidebarWidth: CGFloat {
        let base = 210 + (calendarScale - 1.0) * 120
        return CGFloat(max(190, min(280, base)))
    }

    private var currentFilePath: String? {
        selectedFilePath
    }

    private var todayFilePath: String {
        DailyMarkdownStore(baseDirectoryPath: outputDirectoryPath)
            .todayFileURL()
            .path(percentEncoded: false)
    }

    private var todayLogFilePath: String {
        let ymd = DailyMarkdownStore.ymdString(from: Date())
        let outputDir = NSString(string: outputDirectoryPath).expandingTildeInPath
        return URL(filePath: outputDir)
            .appendingPathComponent("logs_\(ymd).log")
            .path(percentEncoded: false)
    }

    private var leftSidebar: some View {
        VStack(alignment: .center, spacing: 12) {
            VStack(spacing: 10) {
                ForEach(PreviewPanel.allCases, id: \.self) { panel in
                    navButton(for: panel)
                }
            }
            .padding(.top, 14)

            Text(panelTitle(hoveredPanel ?? selectedPanel))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Divider()
                .padding(.horizontal, 8)

            DisclosureGroup(isExpanded: $isCalendarQuickExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        selectedPanel = .calendar
                    } label: {
                        Label(local("打开大日历", "Open Full Calendar"), systemImage: "calendar.badge.clock")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedDate = Date()
                        syncSelectedFileForSelectedDate()
                        selectedPanel = .calendar
                    } label: {
                        Label(model.text(.goToday), systemImage: "scope")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } label: {
                Label(model.text(.calendar), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(local("最近日期", "Recent Dates"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if files.isEmpty {
                    Text(model.text(.noRecentFiles))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(files.prefix(7)), id: \.path) { file in
                        Button(shortDateLabel(for: file)) {
                            openFileInPreview(file)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(minWidth: sidebarWidth, idealWidth: sidebarWidth, maxWidth: sidebarWidth, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var rightPanel: some View {
        Group {
            switch selectedPanel {
            case .preview:
                previewPanel
            case .calendar:
                calendarPanel
            case .settings:
                SettingsView(model: model)
            case .updates:
                updatesPanel
            case .about:
                AboutView(language: language)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(model.text(.previewTitle), systemImage: "doc.richtext")
                    .font(.headline)

                Spacer()

                iconActionButton(
                    systemName: "arrow.clockwise",
                    title: model.text(.reload),
                    action: reloadFilesAndContent
                )

                iconActionButton(
                    systemName: "doc.on.doc",
                    title: model.text(.copyMarkdown),
                    action: copyMarkdownRaw
                )
                .disabled(selectedFilePath == nil)
            }

            Text(currentFilePath ?? model.text(.noFileForDate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if copyFeedbackVisible {
                Text(model.text(.copied))
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Text(model.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    if content.isEmpty {
                        Text(
                            selectedFilePath == nil
                                ? model.text(.noFileForDate)
                                : model.text(.emptyContent)
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    } else {
                        Markdown(content)
                            .font(.system(size: markdownFontSize))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(markdownBottomAnchor)
                }
                .onChange(of: content) { _ in
                    guard currentFilePath == todayFilePath else { return }
                    scrollMarkdownToBottom(proxy: proxy, animated: false)
                }
                .onAppear {
                    guard currentFilePath == todayFilePath else { return }
                    scrollMarkdownToBottom(proxy: proxy, animated: false)
                }
            }

            if currentFilePath == todayFilePath {
                Divider()

                Button {
                    showLogPanel.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showLogPanel ? "chevron.down.circle.fill" : "chevron.right.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.text(.todayLogs))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showLogPanel {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(todayLogContent.isEmpty ? "-" : todayLogContent)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("today-log-top")
                        }
                        .frame(minHeight: 120, maxHeight: 200)
                        .onChange(of: todayLogContent) { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("today-log-top", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.text(.calendar), systemImage: "calendar")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    selectedDate = Date()
                    syncSelectedFileForSelectedDate()
                } label: {
                    Label(model.text(.goToday), systemImage: "scope")
                }
                .buttonStyle(.bordered)
            }

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .scaleEffect(max(1.1, calendarScale + 0.2), anchor: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.vertical, 8)

            Text(
                selectedDateHasRecord
                    ? local("该日期有记录", "Record available for selected date")
                    : model.text(.noFileForDate)
            )
            .font(.subheadline)
            .foregroundStyle(selectedDateHasRecord ? .green : .secondary)

            if selectedDateHasRecord {
                Button {
                    selectedPanel = .preview
                } label: {
                    Label(local("在预览中打开所选日期", "Open Selected Date in Preview"), systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(22)
    }

    private var updatesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.text(.checkForUpdates), systemImage: "sparkles")
                .font(.title3.weight(.semibold))

            Text(local(
                "通过 Sparkle 2 检查可用版本。若检查失败会静默处理并写入当日日志。",
                "Check for updates via Sparkle 2. Failures are handled silently and written to the daily log."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)

            Button {
                model.checkForUpdates()
            } label: {
                Label(model.text(.checkForUpdates), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text(model.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
    }

    private func navButton(for panel: PreviewPanel) -> some View {
        let isActive = panel == selectedPanel

        return Button {
            selectedPanel = panel
        } label: {
            Image(systemName: panel.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(panelTitle(panel))
        .onHover { hovering in
            hoveredPanel = hovering ? panel : nil
        }
    }

    private func iconActionButton(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 26)
        }
        .buttonStyle(.bordered)
        .help(title)
    }

    private func panelTitle(_ panel: PreviewPanel) -> String {
        switch panel {
        case .preview: return model.text(.previewTitle)
        case .calendar: return model.text(.calendar)
        case .settings: return model.text(.settingsTitle)
        case .updates: return model.text(.checkForUpdates)
        case .about: return model.text(.about)
        }
    }

    private func shortDateLabel(for file: URL) -> String {
        guard let date = dateFromFileURL(file) else {
            return file.lastPathComponent
        }

        let formatter = DateFormatter()
        formatter.locale = language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func openFileInPreview(_ file: URL) {
        guard let date = dateFromFileURL(file) else { return }
        selectedDate = date
        syncSelectedFileForSelectedDate()
        selectedPanel = .preview
    }

    private func reloadFilesAndContent() {
        let store = DailyMarkdownStore(baseDirectoryPath: outputDirectoryPath)
        files = (try? store.listRecentDailyFiles(limit: nil)) ?? []
        filesByYMD = makeFileMapByYMD(files)

        if let selectedPath = selectedFilePath,
           let selectedDateFromPath = dateFromFilePath(selectedPath),
           filesByYMD[DailyMarkdownStore.ymdString(from: selectedDateFromPath)] != nil {
            selectedDate = selectedDateFromPath
            syncSelectedFileForSelectedDate()
            return
        }

        if let initialDate = dateFromFilePath(initialFilePath),
           filesByYMD[DailyMarkdownStore.ymdString(from: initialDate)] != nil {
            selectedDate = initialDate
            syncSelectedFileForSelectedDate()
            return
        }

        if let first = files.first,
           let firstDate = dateFromFileURL(first) {
            selectedDate = firstDate
            syncSelectedFileForSelectedDate()
            return
        }

        selectedDate = Date()
        selectedDateHasRecord = false
        selectedFilePath = nil
        content = ""
        todayLogContent = ""
    }

    private func syncSelectedFileForSelectedDate() {
        let key = DailyMarkdownStore.ymdString(from: selectedDate)
        guard let file = filesByYMD[key] else {
            selectedDateHasRecord = false
            selectedFilePath = nil
            content = ""
            loadTodayLog()
            return
        }

        selectedDateHasRecord = true
        let nextPath = file.path(percentEncoded: false)
        if selectedFilePath != nextPath {
            selectedFilePath = nextPath
        } else {
            loadSelectedContent()
            loadTodayLog()
        }
    }

    private func loadSelectedContent() {
        guard let currentFilePath else {
            content = ""
            return
        }

        let url = URL(filePath: currentFilePath)
        let newContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if newContent != content {
            content = newContent
        }
    }

    private func loadTodayLog() {
        guard currentFilePath == todayFilePath else {
            todayLogContent = ""
            return
        }

        let url = URL(filePath: todayLogFilePath)
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        todayLogContent = makeReverseChronologicalLog(raw)
    }

    private func refreshLivePanels() {
        refreshFileIndexIfNeeded()

        if currentFilePath == todayFilePath {
            loadSelectedContent()
            loadTodayLog()
        }
    }

    private func refreshFileIndexIfNeeded() {
        let store = DailyMarkdownStore(baseDirectoryPath: outputDirectoryPath)
        let latestFiles = (try? store.listRecentDailyFiles(limit: nil)) ?? []

        let oldPaths = files.map { $0.path(percentEncoded: false) }
        let newPaths = latestFiles.map { $0.path(percentEncoded: false) }
        guard oldPaths != newPaths else { return }

        files = latestFiles
        filesByYMD = makeFileMapByYMD(latestFiles)
        syncSelectedFileForSelectedDate()
    }

    private func copyMarkdownRaw() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        copyFeedbackVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copyFeedbackVisible = false
        }
    }

    private func makeReverseChronologicalLog(_ raw: String) -> String {
        let lines = raw.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return "" }

        return lines.suffix(400).reversed().joined(separator: "\n")
    }

    private func scrollMarkdownToBottom(proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(markdownBottomAnchor, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(markdownBottomAnchor, anchor: .bottom)
            }
        }
    }

    private func makeFileMapByYMD(_ files: [URL]) -> [String: URL] {
        var mapping: [String: URL] = [:]
        for file in files {
            guard let ymd = ymdFromFileURL(file) else { continue }
            mapping[ymd] = file
        }
        return mapping
    }

    private func dateFromFilePath(_ path: String) -> Date? {
        dateFromFileURL(URL(filePath: path))
    }

    private func dateFromFileURL(_ file: URL) -> Date? {
        guard let ymd = ymdFromFileURL(file) else { return nil }
        return Self.ymdParser.date(from: ymd)
    }

    private func ymdFromFileURL(_ file: URL) -> String? {
        let name = file.lastPathComponent
        guard name.hasPrefix("links_"), name.hasSuffix(".md") else {
            return nil
        }

        let start = name.index(name.startIndex, offsetBy: 6)
        let end = name.index(name.endIndex, offsetBy: -3)
        let ymd = String(name[start..<end])
        guard ymd.count == 8 else { return nil }
        return ymd
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        language == .zhHans ? zhHans : en
    }

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
