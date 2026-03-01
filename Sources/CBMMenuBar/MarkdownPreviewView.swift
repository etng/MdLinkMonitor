import AppKit
import CBMCore
import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let initialFilePath: String
    let outputDirectoryPath: String
    let language: AppLanguage

    @State private var files: [URL] = []
    @State private var selectedFilePath: String?
    @State private var content = ""
    @State private var copyFeedbackVisible = false

    @State private var showLogPanel = false
    @State private var todayLogContent = ""

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let markdownBottomAnchor = "markdown-bottom-anchor"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFilePath) {
                ForEach(files, id: \.path) { file in
                    Text(file.lastPathComponent)
                        .tag(file.path(percentEncoded: false))
                }
            }
            .navigationTitle(sidebarTitle)
        } detail: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedFilePath ?? initialFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(AppLocalizer.text(.copyMarkdown, language: language)) {
                        copyMarkdownRaw()
                    }
                    Button(AppLocalizer.text(.reload, language: language)) {
                        reloadFilesAndContent()
                    }
                }
                if copyFeedbackVisible {
                    Text(AppLocalizer.text(.copied, language: language))
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        if content.isEmpty {
                            Text(AppLocalizer.text(.emptyContent, language: language))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } else {
                            Markdown(content)
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

                    DisclosureGroup(AppLocalizer.text(.todayLogs, language: language), isExpanded: $showLogPanel) {
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
        .frame(minWidth: 920, minHeight: 620)
        .onAppear(perform: reloadFilesAndContent)
        .onChange(of: selectedFilePath) { _ in
            loadSelectedContent()
            loadTodayLog()
        }
        .onReceive(refreshTimer) { _ in
            refreshLivePanels()
        }
    }

    private var sidebarTitle: String {
        AppLocalizer.text(.historyFiles, language: language)
    }

    private var currentFilePath: String {
        selectedFilePath ?? initialFilePath
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

        if let selected = selectedFilePath, files.contains(where: { $0.path(percentEncoded: false) == selected }) {
            loadSelectedContent()
            loadTodayLog()
            return
        }

        if files.contains(where: { $0.path(percentEncoded: false) == initialFilePath }) {
            selectedFilePath = initialFilePath
        } else {
            selectedFilePath = files.first?.path(percentEncoded: false) ?? initialFilePath
        }

        loadSelectedContent()
        loadTodayLog()
    }

    private func loadSelectedContent() {
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
}
