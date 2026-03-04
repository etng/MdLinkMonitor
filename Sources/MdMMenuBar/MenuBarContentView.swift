import AppKit
import MdMCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: MenuBarViewModel
    @Environment(\.dismiss) private var dismissMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.text(.previewMenu))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(model.text(.today)) {
                runAfterMenuDismiss {
                    model.openTodayMainWindow()
                }
            }

            if model.isMainWindowPinned {
                Button(model.text(.unpinMainWindow)) {
                    runAfterMenuDismiss {
                        model.setMainWindowPinned(false)
                        model.openTodayMainWindow()
                    }
                }
            }

            if !recentFilesWithoutToday.isEmpty {
                Divider()
                ForEach(Array(recentFilesWithoutToday.prefix(7)), id: \.path) { file in
                    Button(dateLabel(for: file)) {
                        runAfterMenuDismiss {
                            model.openMainWindow(filePath: file.path(percentEncoded: false), panel: .preview)
                        }
                    }
                }
            }

            Divider()

            Button(model.text(.settingsTitle)) {
                runAfterMenuDismiss {
                    model.openSettings()
                }
            }

            Button(model.text(.checkForUpdates)) {
                runAfterMenuDismiss {
                    model.openUpdatesPanel()
                }
            }

            Button(model.text(.about)) {
                runAfterMenuDismiss {
                    model.openAbout()
                }
            }

            Divider()

            Button(model.text(.quit)) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private var recentFilesWithoutToday: [URL] {
        let todayYMD = DailyMarkdownStore.ymdString(from: Date())
        return model.recentFiles.filter { file in
            ymdFromFile(file) != todayYMD
        }
    }

    private func runAfterMenuDismiss(_ action: @escaping @MainActor () -> Void) {
        dismissMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            Task { @MainActor in
                action()
            }
        }
    }

    private func dateLabel(for file: URL) -> String {
        guard let ymd = ymdFromFile(file),
              let date = Self.ymdParser.date(from: ymd) else {
            return file.lastPathComponent
        }

        let formatter = DateFormatter()
        formatter.locale = model.settings.language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func ymdFromFile(_ file: URL) -> String? {
        let fileName = file.lastPathComponent
        guard fileName.hasPrefix("links_"), fileName.hasSuffix(".md") else {
            return nil
        }

        let start = fileName.index(fileName.startIndex, offsetBy: 6)
        let end = fileName.index(fileName.endIndex, offsetBy: -3)
        let ymd = String(fileName[start..<end])
        return ymd.count == 8 ? ymd : nil
    }

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
