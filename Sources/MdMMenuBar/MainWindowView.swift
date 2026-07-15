import AppKit
import MdMCore
import MarkdownUI
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers

private enum PreviewContentMode: String, CaseIterable, Identifiable {
    case rendered
    case split
    case source

    var id: String { rawValue }
}

private enum PreviewHeaderLayout {
    case wide
    case medium
    case compact
}

struct MainWindowView: View {
    let initialFilePath: String
    @ObservedObject var model: MenuBarViewModel

    @AppStorage("cbm.mainWindow.previewContentMode")
    private var previewContentModeRaw = PreviewContentMode.rendered.rawValue

    @State private var files: [URL] = []
    @State private var filesByYMD: [String: URL] = [:]
    @State private var selectedDate = Date()

    @State private var selectedFilePath: String?
    @State private var content = ""
    @State private var isLoadingContent = false
    @State private var latestLoadRequestID: Int = 0
    @State private var lastLoadedSnapshot: LoadedFileSnapshot?

    @State private var showLogPanel = true
    @State private var todayLogContent = ""
    @StateObject private var settingsDraftCoordinator = SettingsDraftCoordinator()
    @State private var pendingPanelSwitch: MainWindowPanel?
    @State private var showUnsavedSettingsAlert = false
    @State private var suppressPanelGuard = false
    @State private var lastObservedPanel: MainWindowPanel = .preview
    @State private var searchQuery = ""
    @State private var searchResults: [DailyLinkSearchResult] = []
    @State private var searchIndex = DailyLinkSearchIndex()
    @State private var isBuildingSearchIndex = false
    @State private var latestSearchIndexRequestID: Int = 0
    @State private var isSearchResultsPresented = false
    @State private var highlightedSearchResultID: String?
    @State private var selectedSearchResult: DailyLinkSearchResult?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var attachments: [StoredAttachment] = []
    @State private var selectedAttachmentID: String?
    @State private var attachmentResourceMatches: [String] = []
    @State private var pendingDeleteAttachment: StoredAttachment?
    @State private var showDeleteAttachmentAlert = false
    @State private var pendingSearchResultOpen: DailyLinkSearchResult?
    @State private var showSearchResultOpenAlert = false

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let markdownBottomAnchor = "markdown-bottom-anchor"
    private let sidebarWidth: CGFloat = 72
    private let previewSplitMinimumWidth: CGFloat = 960
    private let previewModeRailWidth: CGFloat = 60
    private let renderedPreviewReadingMinWidth: CGFloat = 760
    private let renderedPreviewReadingMaxWidth: CGFloat = 1120
    private let sourcePreviewReadingMinWidth: CGFloat = 780
    private let sourcePreviewReadingMaxWidth: CGFloat = 1180

    private struct LoadedFileSnapshot: Equatable {
        let path: String
        let modifiedAt: Date
        let size: UInt64
    }

    var body: some View {
        rootBody
    }

    private var rootBody: some View {
        configuredBody
    }

    private var configuredBody: some View {
        stackBody
            .frame(minWidth: 980, minHeight: 700)
            .animation(.easeOut(duration: 0.18), value: model.toastMessage)
            .onAppear {
                lastObservedPanel = model.mainWindowPanel
                reloadFilesAndContent()
                loadAttachments()
            }
            .onChange(of: selectedDate) { _ in
                syncSelectedFileForSelectedDate()
            }
            .onChange(of: selectedFilePath) { _ in
                loadSelectedContent()
                loadTodayLog()
            }
            .onChange(of: selectedAttachmentID) { _ in
                loadAttachmentResourceMatches()
            }
            .onChange(of: model.settings.outputDirectoryPath) { _ in
                reloadFilesAndContent()
                loadAttachments()
            }
            .onChange(of: model.settings.attachmentResourceDirectoryPath) { _ in
                loadAttachmentResourceMatches()
            }
            .onChange(of: searchQuery) { _ in
                updateSearchResults()
            }
            .onChange(of: isSearchFieldFocused) { focused in
                if focused && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isSearchResultsPresented = true
                }
            }
            .onReceive(refreshTimer) { _ in
                refreshLivePanels()
            }
            .onChange(of: model.mainWindowNavigationToken) { _ in
                applyNavigationRequest()
            }
            .onChange(of: model.mainWindowPanel) { panel in
                handleMainWindowPanelChange(panel)
            }
            .alert(local("检测到未保存更改", "Unsaved changes"), isPresented: $showUnsavedSettingsAlert) {
                Button(local("保存并继续", "Save & Continue")) {
                    settingsDraftCoordinator.save()
                    continuePendingPanelSwitch()
                }
                Button(local("恢复并继续", "Discard & Continue"), role: .destructive) {
                    settingsDraftCoordinator.discard()
                    continuePendingPanelSwitch()
                }
                Button(local("取消", "Cancel"), role: .cancel) {
                    pendingPanelSwitch = nil
                }
            } message: {
                Text(local("设置里有未保存内容，是否先保存？", "Settings contain unsaved changes. Save before leaving?"))
            }
            .alert(
                local("删除附件", "Delete Attachment"),
                isPresented: $showDeleteAttachmentAlert,
                presenting: pendingDeleteAttachment
            ) { attachment in
                Button(local("删除并加入黑名单", "Delete and Blacklist"), role: .destructive) {
                    performAttachmentDeletion(attachment, removeExternalResources: false)
                }

                if !attachmentResourceMatches.isEmpty {
                    Button(local("同时删除外部文件并加入黑名单", "Delete External Files Too"), role: .destructive) {
                        performAttachmentDeletion(attachment, removeExternalResources: true)
                    }
                }

                Button(local("取消", "Cancel"), role: .cancel) {
                    pendingDeleteAttachment = nil
                }
            } message: { attachment in
                deleteAttachmentAlertMessage(attachment)
            }
            .alert(
                local("打开链接", "Open Link"),
                isPresented: $showSearchResultOpenAlert,
                presenting: pendingSearchResultOpen
            ) { result in
                Button(local("打开", "Open")) {
                    openSearchResultURL(result)
                }
                Button(local("取消", "Cancel"), role: .cancel) {
                    pendingSearchResultOpen = nil
                }
            } message: { result in
                Text(
                    (result.record.title.isEmpty ? result.record.url : result.record.title)
                    + "\n"
                    + result.record.url
                )
            }
            .onExitCommand {
                guard isSearchFieldFocused || isSearchResultsPresented else {
                    return
                }
                clearSearch()
                isSearchFieldFocused = false
            }
    }

    private var stackBody: some View {
        ZStack(alignment: .bottom) {
            mainLayoutBody
            toastOverlay
        }
    }

    private var mainLayoutBody: some View {
        HStack(spacing: 0) {
            leftSidebar
            Divider()
            rightPanel
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = model.toastMessage {
            Text(toast)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
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

    private var isTodaySelected: Bool {
        DailyMarkdownStore.ymdString(from: selectedDate) == DailyMarkdownStore.ymdString(from: Date())
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
            case .attachments:
                attachmentsPanel
            case .calendar:
                calendarPanel
            case .settings:
                SettingsView(model: model, draftCoordinator: settingsDraftCoordinator)
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
        VStack(alignment: .leading, spacing: 4) {
            searchPanel

            if let selectedSearchResult {
                selectedSearchResultBanner(selectedSearchResult)
            }

            previewHeader

            Rectangle()
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 1)

            previewContentSection

            if isTodaySelected {
                Divider()

                HStack(spacing: 8) {
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
                        iconActionButton(
                            systemName: "doc.on.doc",
                            title: model.text(.copyLogs),
                            action: copyTodayLogRaw
                        )
                    }
                }

                if showLogPanel {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(todayLogContent.isEmpty ? "-" : todayLogContent)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("today-log-top")
                                .textSelection(.enabled)
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
        .padding(16)
    }

    private var previewHeader: some View {
        GeometryReader { proxy in
            let layout = previewHeaderLayout(for: proxy.size.width)

            VStack(alignment: .leading, spacing: 8) {
                switch layout {
                case .wide:
                    HStack(alignment: .center, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            previewHeaderLeadingControls
                            previewDateNavigator
                                .frame(maxWidth: 340, alignment: .leading)
                        }

                        Spacer(minLength: 0)
                        previewHeaderTrailingControls
                    }
                case .medium:
                    HStack(alignment: .center, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            previewHeaderLeadingControls
                            previewDateNavigator
                        }
                        Spacer(minLength: 0)
                        previewHeaderTrailingControls
                    }
                case .compact:
                    HStack(alignment: .center, spacing: 12) {
                        previewHeaderLeadingControls
                        Spacer(minLength: 0)
                        previewHeaderTrailingControls
                    }

                    previewDateNavigator
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 60)
    }

    private var previewHeaderLeadingControls: some View {
        HStack(spacing: 8) {
            if model.showBackToCalendarInPreview {
                iconActionButton(
                    systemName: "arrow.uturn.backward",
                    title: model.text(.backToCalendar)
                ) {
                    model.mainWindowPanel = .calendar
                }
            }

            if !isViewingToday {
                iconActionButton(
                    systemName: "scope",
                    title: model.text(.goToday),
                    action: goToToday
                )
            }
        }
        .fixedSize()
    }

    private var previewHeaderTrailingControls: some View {
        HStack(spacing: 8) {
            iconActionButton(
                systemName: model.isMainWindowPinned ? "pin.fill" : "pin",
                title: model.isMainWindowPinned ? model.text(.unpinMainWindow) : model.text(.pinMainWindow),
                action: model.toggleMainWindowPinned
            )

            iconActionButton(
                systemName: "arrow.clockwise",
                title: model.text(.reload),
                action: reloadFilesAndContent
            )

            iconActionButton(
                systemName: model.settings.monitoringEnabled ? "pause.circle" : "play.circle",
                title: model.settings.monitoringEnabled
                    ? local("暂停监控", "Pause Monitoring")
                    : local("恢复监控", "Resume Monitoring")
            ) {
                model.updateMonitoringEnabled(!model.settings.monitoringEnabled)
            }

            iconActionButton(
                systemName: "doc.on.doc",
                title: model.text(.copyMarkdown),
                action: copyMarkdownRaw
            )
            .disabled(selectedFilePath == nil)

            iconActionButton(
                systemName: "line.3.horizontal.decrease.circle",
                title: model.text(.sortByDomain),
                action: sortCurrentFileByDomain
            )
            .disabled(selectedFilePath == nil)

            iconActionButton(
                systemName: "paperclip",
                title: model.text(.attachments)
            ) {
                model.mainWindowPanel = .attachments
            }
        }
    }

    private var previewDateNavigator: some View {
        HStack(spacing: 8) {
            iconActionButton(
                systemName: "chevron.left",
                title: local("上一天", "Previous Day"),
                action: goToPreviousDay
            )

            Text(currentPreviewDateText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .help(currentPreviewDateText)

            iconActionButton(
                systemName: "chevron.right",
                title: local("下一天", "Next Day"),
                action: goToNextDay
            )
        }
    }

    private func previewHeaderLayout(for width: CGFloat) -> PreviewHeaderLayout {
        if width >= 1160 {
            return .wide
        }
        if width >= 860 {
            return .medium
        }
        return .compact
    }

    private func previewModeTitle(for mode: PreviewContentMode) -> String {
        switch mode {
        case .rendered:
            return local("渲染", "Rendered")
        case .split:
            return local("双栏", "Split")
        case .source:
            return local("源文件", "Source")
        }
    }

    private func previewModeRailButton(_ mode: PreviewContentMode) -> some View {
        let isSelected = previewContentMode == mode
        let title = previewModeTitle(for: mode)
        let iconName = previewModeIconName(for: mode)

        return Button {
            previewContentModeRaw = mode.rawValue
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.78) : Color.secondary.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func previewModeIconName(for mode: PreviewContentMode) -> String {
        switch mode {
        case .rendered:
            return "doc.text.image"
        case .split:
            return "square.split.2x1"
        case .source:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    local("搜索标题或网址", "Search titles or URLs"),
                    text: $searchQuery
                )
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    openHighlightedSearchResult()
                }

                if isBuildingSearchIndex {
                    ProgressView()
                        .controlSize(.small)
                }

                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .onMoveCommand(perform: handleSearchMoveCommand)

            if isSearchResultsPresented {
                searchResultsDropdown
            }
        }
    }

    @ViewBuilder
    private var searchResultsDropdown: some View {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if isBuildingSearchIndex && searchResults.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(local("正在建立搜索索引…", "Building search index..."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                } else if searchResults.isEmpty {
                    Text(local("没有找到匹配项", "No matches found"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults) { result in
                                    searchResultRow(result)
                                        .id(result.id)
                                    if result.id != searchResults.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 520)
                        .onChange(of: highlightedSearchResultID) { highlightedID in
                            guard let highlightedID else { return }
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(highlightedID, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private func searchResultRow(_ result: DailyLinkSearchResult) -> some View {
        Button {
            applySearchSelection(result)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(result.record.title.isEmpty ? result.record.url : result.record.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(searchDateText(for: result.record.date))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(result.record.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (
                    highlightedSearchResultID == result.id
                        ? Color.accentColor.opacity(0.18)
                        : (selectedSearchResult?.id == result.id ? Color.accentColor.opacity(0.10) : Color.clear)
                )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }

    private func selectedSearchResultBanner(_ result: DailyLinkSearchResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(local("当前命中项", "Current Match"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(result.record.title.isEmpty ? result.record.url : result.record.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(result.record.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(local("日期：", "Date: ") + searchDateText(for: result.record.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(local("清除", "Clear")) {
                selectedSearchResult = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
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
                Label(
                    model.hasUpdateBadge ? model.text(.updateNow) : model.text(.checkForUpdates),
                    systemImage: model.hasUpdateBadge ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath"
                )
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text("\(model.text(.currentVersion)): \(AppVersion.displayVersion)")
                .font(.headline)
                .foregroundStyle(.secondary)

            if !model.latestReleaseTag.isEmpty {
                Text(local("最新版本：", "Latest: ") + model.latestReleaseTag)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text(local("更新记录", "Release Notes"))
                    .font(.headline)
                Spacer()
            }

            Group {
                if model.isLoadingLatestReleaseNotes {
                    ProgressView(local("正在加载更新记录…", "Loading release notes..."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } else if model.latestReleaseNotesMarkdown.isEmpty {
                    Text(local("暂无更新记录。", "No release notes available."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        Markdown(model.latestReleaseNotesMarkdown)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Spacer()
        }
        .padding(22)
    }

    private var attachmentsPanel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(model.text(.attachments), systemImage: "paperclip")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    iconActionButton(
                        systemName: "arrow.clockwise",
                        title: model.text(.reload),
                        action: loadAttachments
                    )
                }

                if attachments.isEmpty {
                    Text(local("暂无附件", "No attachments yet"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    List(attachments, selection: $selectedAttachmentID) { attachment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attachment.label ?? attachment.id)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Text(attachment.sourceURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(Self.attachmentDateFormatter.string(from: attachment.createdAt))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(attachment.id)
                    }
                    .listStyle(.sidebar)
                }
            }
            .padding(18)
            .frame(minWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if let selectedAttachment {
                    HStack {
                        Text(selectedAttachment.label ?? selectedAttachment.id)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        Button(role: .destructive) {
                            deleteSelectedAttachment()
                        } label: {
                            Label(local("删除", "Delete"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(selectedAttachment.sourceURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text("MD5: \(selectedAttachment.md5)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text("\(selectedAttachment.contentType) · \(ByteCountFormatter.string(fromByteCount: Int64(selectedAttachment.byteCount), countStyle: .file))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(local("外部资源匹配", "External Resource Matches"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if attachmentResourceMatches.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(local("没有匹配到外部资源文件", "No external resource files matched"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(expectedExternalResourcePatterns(for: selectedAttachment))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(attachmentResourceMatches, id: \.self) { relativePath in
                                        Text(relativePath)
                                            .font(.caption.monospaced())
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                    }

                    AttachmentPreviewRepresentable(
                        fileURL: attachmentFileURL(for: selectedAttachment),
                        contentType: selectedAttachment.contentType,
                        fileExtension: selectedAttachment.fileExtension
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text(local("选择左侧附件后可预览和删除", "Select an attachment on the left to preview or delete"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var previewContentSection: some View {
        GeometryReader { proxy in
            let canUseSplit = proxy.size.width >= previewSplitMinimumWidth
            let mode = resolvedPreviewContentMode(canUseSplit: canUseSplit)

            Group {
                if mode == .split {
                    HStack(alignment: .top, spacing: 18) {
                        previewContentSurface(mode: mode)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                        previewModeRail(canUseSplit: canUseSplit)
                            .frame(width: previewModeRailWidth, alignment: .topLeading)
                    }
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        previewContentSurface(mode: mode)
                            .frame(
                                width: previewReadingSurfaceWidth(for: mode, availableWidth: proxy.size.width),
                                alignment: .topLeading
                            )
                            .frame(maxHeight: .infinity, alignment: .topLeading)

                        Spacer(minLength: 0)

                        previewModeRail(canUseSplit: canUseSplit)
                            .frame(width: previewModeRailWidth, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                syncPreviewContentModeAvailability(canUseSplit: canUseSplit)
            }
            .onChange(of: canUseSplit) { available in
                syncPreviewContentModeAvailability(canUseSplit: available)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func previewModeRail(canUseSplit: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(availablePreviewModes(canUseSplit: canUseSplit)) { mode in
                previewModeRailButton(mode)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .help(local("切换渲染、双栏和源文件视图", "Switch between rendered, split, and source views"))
    }

    private func previewContentSurface(mode: PreviewContentMode) -> some View {
        Group {
            if isLoadingContent {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text(local("正在加载内容…", "Loading content..."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            } else if content.isEmpty {
                Text(
                    selectedFilePath == nil
                        ? model.text(.noFileForDate)
                        : model.text(.emptyContent)
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            } else {
                previewContentBody(mode: mode)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func previewContentBody(mode: PreviewContentMode) -> some View {
        switch mode {
        case .rendered:
            renderedPreviewColumn
        case .split:
            HStack(alignment: .top, spacing: 14) {
                splitPreviewColumn(title: local("渲染", "Rendered")) {
                    renderedPreviewColumn
                }

                splitPreviewColumn(title: local("源文件", "Source")) {
                    sourcePreviewColumn
                }
            }
        case .source:
            sourcePreviewColumn
        }
    }

    private var renderedPreviewColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Markdown(content)
                    .font(.system(size: markdownFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                Color.clear
                    .frame(height: 1)
                    .id(markdownBottomAnchor)
            }
            .textSelection(.enabled)
            .onChange(of: content) { _ in
                guard isTodaySelected else { return }
                scrollMarkdownToBottom(proxy: proxy, anchorID: markdownBottomAnchor, animated: false)
            }
            .onAppear {
                guard isTodaySelected else { return }
                scrollMarkdownToBottom(proxy: proxy, anchorID: markdownBottomAnchor, animated: false)
            }
        }
    }

    private var sourcePreviewColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(content)
                    .font(.system(size: max(markdownFontSize - 1, 12), weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .textSelection(.enabled)

                Color.clear
                    .frame(height: 1)
                    .id("source-bottom-anchor")
            }
            .textSelection(.enabled)
            .onChange(of: content) { _ in
                guard isTodaySelected else { return }
                scrollMarkdownToBottom(proxy: proxy, anchorID: "source-bottom-anchor", animated: false)
            }
            .onAppear {
                guard isTodaySelected else { return }
                scrollMarkdownToBottom(proxy: proxy, anchorID: "source-bottom-anchor", animated: false)
            }
        }
    }

    private func splitPreviewColumn<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func navButton(for panel: MainWindowPanel) -> some View {
        let isActive = panel == selectedPanel

        return Button {
            requestPanelSwitch(to: panel)
        } label: {
            Image(systemName: panel.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if panel == .updates && model.hasUpdateBadge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(panelTitle(panel))
    }

    private func panelTitle(_ panel: MainWindowPanel) -> String {
        switch panel {
        case .preview: return model.text(.previewTitle)
        case .attachments: return model.text(.attachments)
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

    private func goToPreviousDay() {
        shiftSelectedDate(byDays: -1)
    }

    private func goToNextDay() {
        shiftSelectedDate(byDays: 1)
    }

    private func requestPanelSwitch(to panel: MainWindowPanel) {
        guard panel != selectedPanel else { return }
        if selectedPanel == .settings, settingsDraftCoordinator.hasUnsavedChanges {
            pendingPanelSwitch = panel
            showUnsavedSettingsAlert = true
            return
        }
        applyPanelSwitch(panel)
    }

    private func continuePendingPanelSwitch() {
        guard let panel = pendingPanelSwitch else { return }
        pendingPanelSwitch = nil
        applyPanelSwitch(panel)
    }

    private func applyPanelSwitch(_ panel: MainWindowPanel) {
        if panel == .preview {
            model.showBackToCalendarInPreview = false
        }
        if panel == .updates {
            model.loadLatestReleaseNotes(force: true)
        }
        model.mainWindowPanel = panel
    }

    private func handleMainWindowPanelChange(_ newPanel: MainWindowPanel) {
        if suppressPanelGuard {
            lastObservedPanel = newPanel
            return
        }

        if lastObservedPanel == .settings,
           newPanel != .settings,
           settingsDraftCoordinator.hasUnsavedChanges {
           pendingPanelSwitch = newPanel
           showUnsavedSettingsAlert = true
           suppressPanelGuard = true
           model.mainWindowPanel = .settings
            suppressPanelGuard = false
            lastObservedPanel = .settings
            return
        }

        lastObservedPanel = newPanel
    }

    private var currentPreviewDateText: String {
        let date = displayedPreviewDate
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
        rebuildSearchIndex(using: files)

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
        isLoadingContent = false
        lastLoadedSnapshot = nil
        todayLogContent = ""

        loadAttachments()
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
            isLoadingContent = false
            lastLoadedSnapshot = nil
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
            isLoadingContent = false
            lastLoadedSnapshot = nil
            return
        }

        if let snapshot = makeFileSnapshot(for: currentFilePath),
           snapshot == lastLoadedSnapshot {
            isLoadingContent = false
            return
        }

        isLoadingContent = true
        latestLoadRequestID += 1
        let requestID = latestLoadRequestID
        let targetPath = currentFilePath

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(filePath: targetPath)
            let newContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let snapshot: LoadedFileSnapshot? = {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: targetPath),
                      let modifiedAt = attributes[.modificationDate] as? Date else {
                    return nil
                }
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                return LoadedFileSnapshot(path: targetPath, modifiedAt: modifiedAt, size: size)
            }()

            DispatchQueue.main.async {
                guard requestID == latestLoadRequestID else { return }
                isLoadingContent = false
                lastLoadedSnapshot = snapshot
                if newContent != content {
                    content = newContent
                }
            }
        }
    }

    private func loadTodayLog() {
        guard isTodaySelected else {
            todayLogContent = ""
            return
        }

        let url = URL(filePath: todayLogFilePath)
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        todayLogContent = makeReverseChronologicalLog(raw)
    }

    private func refreshLivePanels() {
        refreshFileIndexIfNeeded()
        loadAttachments()

        if isTodaySelected {
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
        rebuildSearchIndex(using: latestFiles)
        syncSelectedFileForSelectedDate()
    }

    private func rebuildSearchIndex(using fileURLs: [URL]) {
        latestSearchIndexRequestID += 1
        let requestID = latestSearchIndexRequestID
        let snapshot = fileURLs

        isBuildingSearchIndex = true
        DispatchQueue.global(qos: .userInitiated).async {
            let index = DailyLinkSearchIndex.build(fileURLs: snapshot)

            DispatchQueue.main.async {
                guard requestID == latestSearchIndexRequestID else { return }
                isBuildingSearchIndex = false
                searchIndex = index

                if let selectedSearchResult,
                   !index.records.contains(where: { $0.id == selectedSearchResult.record.id }) {
                    self.selectedSearchResult = nil
                }

                if let highlightedSearchResultID,
                   !index.records.contains(where: { $0.id == highlightedSearchResultID }) {
                    self.highlightedSearchResultID = nil
                }

                updateSearchResults()
            }
        }
    }

    private func updateSearchResults() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            highlightedSearchResultID = nil
            isSearchResultsPresented = false
            return
        }

        searchResults = searchIndex.search(query: trimmed, limit: 14)
        if let highlightedSearchResultID,
           !searchResults.contains(where: { $0.id == highlightedSearchResultID }) {
            self.highlightedSearchResultID = nil
        }
        isSearchResultsPresented = true
    }

    private func openHighlightedSearchResult() {
        if let highlighted = highlightedSearchResult,
           searchResults.contains(where: { $0.id == highlighted.id }) {
            applySearchSelection(highlighted)
            return
        }

        guard let first = searchResults.first else {
            return
        }
        applySearchSelection(first)
    }

    private func clearSearch() {
        searchQuery = ""
        searchResults = []
        highlightedSearchResultID = nil
        isSearchResultsPresented = false
    }

    private func applySearchSelection(_ result: DailyLinkSearchResult) {
        highlightedSearchResultID = result.id
        selectedSearchResult = result
        selectedDate = result.record.date
        model.mainWindowPanel = .preview
        model.showBackToCalendarInPreview = false
        isSearchResultsPresented = false
        isSearchFieldFocused = false
        syncSelectedFileForSelectedDate()
        triggerSearchResultOpenIfNeeded(result)
    }

    private func triggerSearchResultOpenIfNeeded(_ result: DailyLinkSearchResult) {
        if model.settings.openSearchResultLinksDirectly {
            openSearchResultURL(result)
        } else {
            pendingSearchResultOpen = result
            showSearchResultOpenAlert = true
        }
    }

    private func openSearchResultURL(_ result: DailyLinkSearchResult) {
        pendingSearchResultOpen = nil
        guard let url = URL(string: result.record.url) else {
            model.showToast(local("链接地址无效", "Invalid link URL"))
            return
        }
        if !NSWorkspace.shared.open(url) {
            model.showToast(local("打开链接失败", "Failed to open link"))
        }
    }

    private func loadAttachments() {
        let store = AttachmentLibraryStore(baseDirectoryPath: outputDirectoryPath)
        let loaded = store.listAttachments()
        attachments = loaded

        if let selectedAttachmentID,
           loaded.contains(where: { $0.id == selectedAttachmentID }) {
            loadAttachmentResourceMatches()
            return
        }

        self.selectedAttachmentID = loaded.first?.id
        loadAttachmentResourceMatches()
    }

    private var selectedAttachment: StoredAttachment? {
        guard let selectedAttachmentID else {
            return nil
        }
        return attachments.first(where: { $0.id == selectedAttachmentID })
    }

    private func attachmentFileURL(for attachment: StoredAttachment) -> URL {
        AttachmentLibraryStore(baseDirectoryPath: outputDirectoryPath).fileURL(for: attachment)
    }

    private func deleteSelectedAttachment() {
        guard let attachment = selectedAttachment else {
            return
        }

        pendingDeleteAttachment = attachment
        showDeleteAttachmentAlert = true
    }

    private func performAttachmentDeletion(_ attachment: StoredAttachment, removeExternalResources: Bool) {
        let store = AttachmentLibraryStore(baseDirectoryPath: outputDirectoryPath)
        do {
            try store.blacklistURL(
                for: attachment,
                note: removeExternalResources
                    ? "deleted attachment and external resources from UI"
                    : "deleted attachment from UI"
            )
            if removeExternalResources {
                store.deleteExternalResources(
                    relativePaths: attachmentResourceMatches,
                    resourceDirectoryPath: model.settings.attachmentResourceDirectoryPath
                )
            }
            store.delete(attachment)
            pendingDeleteAttachment = nil
            loadAttachments()
            model.showToast(local("附件已删除并加入黑名单", "Attachment deleted and blacklisted"))
        } catch {
            model.showToast(local("删除失败", "Delete failed"))
        }
    }

    private func loadAttachmentResourceMatches() {
        guard let attachment = selectedAttachment else {
            attachmentResourceMatches = []
            return
        }

        attachmentResourceMatches = AttachmentLibraryStore(baseDirectoryPath: outputDirectoryPath)
            .findExternalResourceMatches(
                for: attachment,
                resourceDirectoryPath: model.settings.attachmentResourceDirectoryPath
            )
    }

    private func sortCurrentFileByDomain() {
        guard let selectedFilePath else {
            return
        }

        let store = DailyMarkdownStore(baseDirectoryPath: outputDirectoryPath)
        do {
            let changed = try store.sortFileByDomain(at: selectedFilePath)
            if changed {
                loadSelectedContent()
                reloadFilesAndContent()
                model.showToast(model.text(.sortByDomain))
            } else {
                model.showToast(local("无需排序", "No sorting needed"))
            }
        } catch {
            model.showToast(local("排序失败", "Sort failed"))
        }
    }

    private func handleSearchMoveCommand(_ direction: MoveCommandDirection) {
        guard isSearchFieldFocused || highlightedSearchResultID != nil else {
            return
        }
        guard !searchResults.isEmpty else {
            return
        }

        switch direction {
        case .down:
            isSearchResultsPresented = true
            if let currentIndex = currentHighlightedSearchResultIndex {
                let nextIndex = min(currentIndex + 1, searchResults.count - 1)
                highlightedSearchResultID = searchResults[nextIndex].id
            } else {
                highlightedSearchResultID = searchResults.first?.id
            }
        case .up:
            isSearchResultsPresented = true
            if let currentIndex = currentHighlightedSearchResultIndex {
                let nextIndex = max(currentIndex - 1, 0)
                highlightedSearchResultID = searchResults[nextIndex].id
            } else {
                highlightedSearchResultID = searchResults.last?.id
            }
        default:
            break
        }
    }

    private func makeFileSnapshot(for path: String) -> LoadedFileSnapshot? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return nil
        }
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        return LoadedFileSnapshot(path: path, modifiedAt: modifiedAt, size: size)
    }

    private func copyMarkdownRaw() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        model.showToast(model.text(.copied))
    }

    private func copyTodayLogRaw() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(todayLogContent, forType: .string)
        model.showToast(model.text(.copied))
    }

    private func makeReverseChronologicalLog(_ raw: String) -> String {
        let lines = raw.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return "" }
        return lines.suffix(400).reversed().joined(separator: "\n")
    }

    private func scrollMarkdownToBottom(proxy: ScrollViewProxy, anchorID: String, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(anchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(anchorID, anchor: .bottom)
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

    private func availablePreviewModes(canUseSplit: Bool) -> [PreviewContentMode] {
        canUseSplit ? PreviewContentMode.allCases : [.rendered, .source]
    }

    private func resolvedPreviewContentMode(canUseSplit: Bool) -> PreviewContentMode {
        if !canUseSplit, previewContentMode == .split {
            return .rendered
        }
        return previewContentMode
    }

    private func previewReadingWidth(for mode: PreviewContentMode, availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(availableWidth - previewModeRailWidth - 32, 0)
        switch mode {
        case .rendered:
            return clampedPreviewWidth(
                usableWidth * 0.82,
                minWidth: renderedPreviewReadingMinWidth,
                maxWidth: renderedPreviewReadingMaxWidth
            )
        case .source:
            return clampedPreviewWidth(
                usableWidth * 0.86,
                minWidth: sourcePreviewReadingMinWidth,
                maxWidth: sourcePreviewReadingMaxWidth
            )
        case .split:
            return .infinity
        }
    }

    private func previewReadingSurfaceWidth(for mode: PreviewContentMode, availableWidth: CGFloat) -> CGFloat {
        let reservedWidth = previewModeRailWidth + 18
        let maxSurfaceWidth = max(availableWidth - reservedWidth, 0)
        return min(previewReadingWidth(for: mode, availableWidth: availableWidth), maxSurfaceWidth)
    }

    private func syncPreviewContentModeAvailability(canUseSplit: Bool) {
        guard !canUseSplit, previewContentMode == .split else {
            return
        }
        previewContentModeRaw = PreviewContentMode.rendered.rawValue
    }

    private func clampedPreviewWidth(_ proposedWidth: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, minWidth), maxWidth)
    }

    private func deleteAttachmentAlertMessage(_ attachment: StoredAttachment) -> Text {
        let prefix = local("此操作会删除附件并加入 blacklist.yaml。", "This deletes the attachment and adds it to blacklist.yaml.")
        if attachmentResourceMatches.isEmpty {
            return Text(prefix)
        }

        let summary = attachmentResourceMatches.prefix(5).joined(separator: "\n")
        let message = prefix
            + "\n\n"
            + local("已匹配到外部资源：", "Matched external resources: ")
            + "\n"
            + summary
            + (attachmentResourceMatches.count > 5 ? "\n…" : "")
        return Text(message)
    }

    private func expectedExternalResourcePatterns(for attachment: StoredAttachment) -> String {
        let store = AttachmentLibraryStore(baseDirectoryPath: outputDirectoryPath)
        return store.externalResourceNamePrefixes(for: attachment)
            .map { prefix in
                if prefix.hasSuffix("_md.") {
                    return "\(attachment.md5)_MD.\(attachment.fileExtension)"
                }
                return prefix.replacingOccurrences(of: "_md5.", with: "_MD5.\(attachment.fileExtension)")
            }
            .joined(separator: "\n")
    }

    private func searchDateText(for date: Date) -> String {
        Self.searchDateFormatter.string(from: date)
    }

    private var previewContentMode: PreviewContentMode {
        PreviewContentMode(rawValue: previewContentModeRaw) ?? .rendered
    }

    private var previewContentModeBinding: Binding<PreviewContentMode> {
        Binding(
            get: { previewContentMode },
            set: { previewContentModeRaw = $0.rawValue }
        )
    }

    private var displayedPreviewDate: Date {
        dateFromFilePath(currentFilePath ?? "") ?? selectedDate
    }

    private func shiftSelectedDate(byDays offset: Int) {
        guard let nextDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: offset, to: displayedPreviewDate) else {
            return
        }
        selectedDate = nextDate
        syncSelectedFileForSelectedDate()
    }

    private var highlightedSearchResult: DailyLinkSearchResult? {
        guard let highlightedSearchResultID else {
            return nil
        }
        return searchResults.first(where: { $0.id == highlightedSearchResultID })
    }

    private var currentHighlightedSearchResultIndex: Int? {
        guard let highlightedSearchResultID else {
            return nil
        }
        return searchResults.firstIndex(where: { $0.id == highlightedSearchResultID })
    }

    private var isViewingToday: Bool {
        Calendar.autoupdatingCurrent.isDateInToday(displayedPreviewDate)
    }

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let searchDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let attachmentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct AttachmentPreviewRepresentable: View {
    let fileURL: URL
    let contentType: String
    let fileExtension: String

    var body: some View {
        if isImageFile {
            AttachmentImagePreview(fileURL: fileURL)
        } else {
            AttachmentQuickLookPreview(fileURL: fileURL)
        }
    }

    private var isImageFile: Bool {
        if let mimeType = UTType(mimeType: contentType), mimeType.conforms(to: .image) {
            return true
        }
        if let extType = UTType(filenameExtension: fileExtension), extType.conforms(to: .image) {
            return true
        }
        return false
    }
}

private struct AttachmentImagePreview: View {
    let fileURL: URL
    @State private var image: NSImage? = nil

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    let imageSize = image.size
                    let availableWidth = max(geometry.size.width - 24, 1)
                    let availableHeight = max(geometry.size.height - 24, 1)
                    let needsScale = imageSize.width > availableWidth || imageSize.height > availableHeight

                    VStack {
                        Spacer(minLength: 0)
                        if needsScale {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .antialiased(true)
                                .scaledToFit()
                                .frame(maxWidth: availableWidth, maxHeight: availableHeight)
                        } else {
                            Image(nsImage: image)
                                .interpolation(.high)
                                .antialiased(true)
                                .frame(width: imageSize.width, height: imageSize.height)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: loadImageIfNeeded)
        .onChange(of: fileURL) { _ in
            image = nil
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard image == nil else {
            return
        }
        image = NSImage(contentsOf: fileURL)
    }
}

private struct AttachmentQuickLookPreview: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.shouldCloseWithWindow = false
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = AttachmentPreviewItem(fileURL: fileURL)
    }
}

private final class AttachmentPreviewItem: NSObject, QLPreviewItem {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    var previewItemURL: URL? {
        fileURL
    }
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
