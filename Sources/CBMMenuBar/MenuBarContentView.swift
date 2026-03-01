import CBMCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                model.text(.enableMonitoring),
                isOn: Binding(
                    get: { model.settings.monitoringEnabled },
                    set: { model.updateMonitoringEnabled($0) }
                )
            )

            Toggle(
                model.text(.enableNotifications),
                isOn: Binding(
                    get: { model.settings.notificationsEnabled },
                    set: { model.updateNotificationsEnabled($0) }
                )
            )

            Toggle(
                model.text(.allowMultipleLinks),
                isOn: Binding(
                    get: { model.settings.allowMultipleLinks },
                    set: { model.updateAllowMultipleLinks($0) }
                )
            )

            Toggle(
                model.text(.launchAtLogin),
                isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.updateLaunchAtLogin($0) }
                )
            )

            Divider()

            Text("\(model.text(.outputDirectory)): \(model.settings.outputDirectoryPath)")
                .font(.caption)
                .lineLimit(2)

            Button(model.text(.chooseDirectory)) {
                runAfterMenuDismiss {
                    model.chooseOutputDirectory()
                }
            }

            Picker(
                model.text(.language),
                selection: Binding(
                    get: { model.settings.language },
                    set: { model.updateLanguage($0) }
                )
            ) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
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
