import CBMCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(model.text(.openSettings)) {
                runAfterMenuDismiss {
                    model.openSettings()
                }
            }

            Divider()

            Text(model.text(.recentFiles))
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.recentFiles.isEmpty {
                Text(model.text(.noRecentFiles))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.recentFiles.prefix(7)), id: \.path) { file in
                    Button(file.lastPathComponent) {
                        runAfterMenuDismiss {
                            model.openPreview(filePath: file.path(percentEncoded: false))
                        }
                    }
                }
            }

            Button(model.text(.openToday)) {
                runAfterMenuDismiss {
                    model.openTodayPreview()
                }
            }

            Divider()

            Button(model.text(.checkForUpdates)) {
                runAfterMenuDismiss {
                    model.checkForUpdates()
                }
            }

            Button(model.text(.about)) {
                runAfterMenuDismiss {
                    model.openAbout()
                }
            }

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
}
