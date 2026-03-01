import CBMCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

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
                model.chooseOutputDirectory()
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

            Menu(model.text(.recentFiles)) {
                if model.recentFiles.isEmpty {
                    Text(model.text(.noRecentFiles))
                } else {
                    ForEach(model.recentFiles, id: \.path) { file in
                        Button(file.lastPathComponent) {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "preview", value: file.path(percentEncoded: false))
                        }
                    }
                }
            }

            Button(model.text(.openToday)) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "preview", value: model.openTodayFilePath())
            }

            Divider()

            Button(model.text(.checkForUpdates)) {
                model.checkForUpdates()
            }

            Button(model.text(.about)) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
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
}
