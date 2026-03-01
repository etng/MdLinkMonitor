import AppKit
import CBMCore
import MarkdownUI
import SwiftUI

struct MainWindowView: View {
    let initialFilePath: String
    @ObservedObject var model: MenuBarViewModel

    @State private var files: [URL] = []
    @State private var filesByYMD: [String: URL] = [:]
    @State private var selectedDate = Date()

    @State private var selectedFilePath: String?
    @State private var content = ""

    @State private var showLogPanel = false
    @State private var todayLogContent = ""

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let markdownBottomAnchor = "markdown-bottom-anchor"
    private let sidebarWidth: CGFloat = 72

    var body: some View {
        HStack(spacing: 0) {
            leftSidebar
            Divider()
            rightPanel
        }
        .frame(minWidth: 980, minHeight: 700)
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
        .onChange(of: model.mainWindowNavigationToken) { _ in
            applyNavigationRequest()
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

    private var selectedPanel: MainWindowPanel {
        model.mainWindowPanel
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
        VStack(spacing: 12) {
            ForEach(MainWindowPanel.allCases, id: \.self) { panel in
                navButton(for: panel)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .frame(minWidth: sidebarWidth, idealWidth: sidebarWidth, maxWidth: sidebarWidth, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
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
            case .help:
                AboutView(language: language)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    if model.showBackToCalendarInPreview {
                        iconActionButton(
                            systemName: "arrow.uturn.backward",
                            title: model.text(.backToCalendar)
                        ) {
                            model.mainWindowPanel = .calendar
                        }
                    }

                    iconActionButton(
                        systemName: "scope",
                        title: model.text(.goToday),
                        action: goToToday
                    )
                }

                Spacer()

                HStack(spacing: 8) {
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
            }
            .overlay(alignment: .center) {
                Text(currentPreviewDateText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

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
        VStack(alignment: .leading, spacing: 10) {
            CalendarBoardView(
                selectedDate: $selectedDate,
                language: language,
                recordYMDs: Set(filesByYMD.keys),
                scale: calendarScale
            ) { date in
                selectedDate = date
                syncSelectedFileForSelectedDate()
                model.showBackToCalendarInPreview = true
                model.mainWindowPanel = .preview
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button {
                    goToToday()
                } label: {
                    Label(model.text(.goToday), systemImage: "scope")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding(18)
    }

    private var updatesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.text(.checkForUpdates), systemImage: "sparkles")
                .font(.title3.weight(.semibold))

            Text(local(
                "通过 Sparkle 2 检查可用版本。版本号遵循 SemVer，若检查失败会静默处理并写入当日日志。",
                "Check for updates via Sparkle 2. Versions follow SemVer. Failures are handled silently and written to the daily log."
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

            Text("\(model.text(.currentVersion)): \(AppVersion.displayVersion)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
    }

    private func navButton(for panel: MainWindowPanel) -> some View {
        let isActive = panel == selectedPanel

        return Button {
            if panel == .preview {
                model.showBackToCalendarInPreview = false
            }
            model.mainWindowPanel = panel
        } label: {
            Image(systemName: panel.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(panelTitle(panel))
    }

    private func panelTitle(_ panel: MainWindowPanel) -> String {
        switch panel {
        case .preview: return model.text(.previewTitle)
        case .calendar: return model.text(.calendar)
        case .settings: return model.text(.settingsTitle)
        case .updates: return model.text(.checkForUpdates)
        case .help: return model.text(.about)
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

    private func goToToday() {
        selectedDate = Date()
        syncSelectedFileForSelectedDate()
    }

    private var currentPreviewDateText: String {
        let date = dateFromFilePath(currentFilePath ?? "") ?? selectedDate
        let formatter = DateFormatter()
        formatter.locale = language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
        selectedFilePath = nil
        content = ""
        todayLogContent = ""

        applyNavigationRequest()
    }

    private func applyNavigationRequest() {
        let targetPath = model.mainWindowTargetFilePath
        guard !targetPath.isEmpty else { return }

        if let date = dateFromFilePath(targetPath) {
            selectedDate = date
            syncSelectedFileForSelectedDate()
            return
        }

        selectedDate = Date()
        syncSelectedFileForSelectedDate()
    }

    private func syncSelectedFileForSelectedDate() {
        let key = DailyMarkdownStore.ymdString(from: selectedDate)
        guard let file = filesByYMD[key] else {
            selectedFilePath = nil
            content = ""
            loadTodayLog()
            return
        }

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

private struct CalendarBoardView: View {
    @Binding var selectedDate: Date
    let language: AppLanguage
    let recordYMDs: Set<String>
    let scale: Double
    let onDoubleSelect: (Date) -> Void

    @State private var displayedMonth: Date
    private let calendar = Calendar.autoupdatingCurrent

    init(
        selectedDate: Binding<Date>,
        language: AppLanguage,
        recordYMDs: Set<String>,
        scale: Double,
        onDoubleSelect: @escaping (Date) -> Void
    ) {
        _selectedDate = selectedDate
        self.language = language
        self.recordYMDs = recordYMDs
        self.scale = scale
        self.onDoubleSelect = onDoubleSelect
        _displayedMonth = State(initialValue: Self.startOfMonth(for: selectedDate.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help(local("上个月", "Previous Month"))

                Spacer()

                Text(monthTitle)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help(local("下个月", "Next Month"))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear
                            .frame(minHeight: cellHeight)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: selectedDate) { newDate in
            let targetMonth = Self.startOfMonth(for: newDate)
            guard !calendar.isDate(targetMonth, equalTo: displayedMonth, toGranularity: .month) else { return }
            displayedMonth = targetMonth
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = language == .zhHans ? "yyyy年M月" : "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthCells: [Date?] {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                cells.append(date)
            }
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return cells
    }

    private var cellHeight: CGFloat {
        CGFloat(max(58.0, min(92.0, 66.0 * scale)))
    }

    private func dayCell(_ date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasRecord = recordYMDs.contains(DailyMarkdownStore.ymdString(from: date))

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor(isToday: isToday, isSelected: isSelected))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor(isToday: isToday, isSelected: isSelected), lineWidth: isSelected ? 2.2 : 1)
                )

            if hasRecord {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.green)
                    .padding(6)
            }

            VStack {
                Text("\(day)")
                    .font(.system(size: max(14, 17 * scale), weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.orange : Color.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, hasRecord ? 4 : 0)
        }
        .frame(minHeight: cellHeight)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            selectedDate = date
        }
        .onTapGesture(count: 2) {
            selectedDate = date
            onDoubleSelect(date)
        }
        .help(dayTooltip(for: date, hasRecord: hasRecord, isToday: isToday))
    }

    private func backgroundColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.22)
        }
        if isToday {
            return Color.orange.opacity(0.18)
        }
        return Color(NSColor.textBackgroundColor)
    }

    private func borderColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        if isToday {
            return .orange
        }
        return Color.secondary.opacity(0.2)
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = Self.startOfMonth(for: newMonth)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func dayTooltip(for date: Date, hasRecord: Bool, isToday: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        let title = formatter.string(from: date)
        if hasRecord {
            return local("\(title)（有记录，双击打开预览）", "\(title) (Has records, double-click to open preview)")
        }
        if isToday {
            return local("\(title)（今天）", "\(title) (Today)")
        }
        return title
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        language == .zhHans ? zhHans : en
    }
}
