import CBMCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.text(.recentFiles))
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.recentFiles.isEmpty {
                Text(model.text(.noRecentFiles))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.recentFiles.prefix(7)), id: \.path) { file in
                    Button(dateLabel(for: file)) {
                        runAfterMenuDismiss {
                            model.openPreview(filePath: file.path(percentEncoded: false))
                        }
                    }
                }
            }

            Button(model.todayMenuDateText) {
                runAfterMenuDismiss {
                    model.openTodayPreview()
                }
            }

            Divider()

            Text(model.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(model.text(.quit)) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    private func runAfterMenuDismiss(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            action()
        }
    }

    private func dateLabel(for file: URL) -> String {
        let fileName = file.lastPathComponent
        guard fileName.hasPrefix("links_"), fileName.hasSuffix(".md") else {
            return fileName
        }

        let start = fileName.index(fileName.startIndex, offsetBy: 6)
        let end = fileName.index(fileName.endIndex, offsetBy: -3)
        let ymd = String(fileName[start..<end])
        guard let date = Self.ymdParser.date(from: ymd) else {
            return fileName
        }

        let formatter = DateFormatter()
        formatter.locale = model.settings.language == .zhHans
            ? Locale(identifier: "zh_Hans_CN")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
