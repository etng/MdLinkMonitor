import AppKit
import CBMCore
import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let initialFilePath: String
    @ObservedObject var model: MenuBarViewModel

    @State private var files: [URL] = []
    @State private var filesByYMD: [String: URL] = [:]
    @State private var selectedDate = Date()
    @State private var selectedDateHasRecord = false

    @State private var selectedFilePath: String?
    @State private var content = ""
    @State private var copyFeedbackVisible = false

    @State private var showLogPanel = false
    @State private var todayLogContent = ""

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let markdownBottomAnchor = "markdown-bottom-anchor"

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalizer.text(.calendar, language: language))
                    .font(.headline)

                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .scaleEffect(calendarScale, anchor: .topLeading)
                .frame(height: 300 * calendarScale)
                .onChange(of: selectedDate) { _ in
                    syncSelectedFileForSelectedDate()
                }

                Button(AppLocalizer.text(.goToday, language: language)) {
                    selectedDate = Date()
                    syncSelectedFileForSelectedDate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text(
                    selectedDateHasRecord
                        ? (language == .zhHans ? "该日期有记录" : "Record available for selected date")
                        : AppLocalizer.text(.noFileForDate, language: language)
                )
                .font(.caption)
                .foregroundStyle(selectedDateHasRecord ? .green : .secondary)

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(sidebarTitle)
            .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth + 16, max: sidebarWidth + 80)
        } detail: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(model.text(.openSettings)) {
                        model.openSettings()
                    }
                    Button(model.text(.checkForUpdates)) {
                        model.checkForUpdates()
                    }
                    Button(model.text(.about)) {
                        model.openAbout()
                    }
                    Spacer()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                HStack {
                    Text(currentFilePath ?? AppLocalizer.text(.noFileForDate, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(AppLocalizer.text(.copyMarkdown, language: language)) {
                        copyMarkdownRaw()
                    }
                    .disabled(selectedFilePath == nil)
                    Button(AppLocalizer.text(.reload, language: language)) {
                        reloadFilesAndContent()
                    }
                }
                if copyFeedbackVisible {
                    Text(AppLocalizer.text(.copied, language: language))
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
                                    ? AppLocalizer.text(.noFileForDate, language: language)
                                    : AppLocalizer.text(.emptyContent, language: language)
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
                            Image(systemName: showLogPanel ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text(AppLocalizer.text(.todayLogs, language: language))
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showLogPanel {
                        ScrollView {
                            Text(todayLogContent.isEmpty ? "-" : todayLogContent)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 120, maxHeight: 180)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear(perform: reloadFilesAndContent)
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
        let base = 250.0 + (calendarScale - 1.0) * 220.0
        return CGFloat(max(300.0, min(460.0, base)))
    }

    private var sidebarTitle: String {
        AppLocalizer.text(.historyFiles, language: language)
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
        // Logs panel is mainly for today's preview diagnostics.
        guard currentFilePath == todayFilePath else {
            todayLogContent = ""
            return
        }

        let url = URL(filePath: todayLogFilePath)
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        todayLogContent = makeReverseChronologicalLog(raw)
    }

    private func refreshLivePanels() {
        if currentFilePath == todayFilePath {
            loadSelectedContent()
            loadTodayLog()
        }
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

        // Keep rendering lightweight while preserving latest diagnostics at top.
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

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
