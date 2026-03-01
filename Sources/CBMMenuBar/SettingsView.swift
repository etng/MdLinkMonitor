import CBMCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MenuBarViewModel

    @State private var domainsText = ""

    var body: some View {
        Form {
            settingToggle(
                model.text(.enableMonitoring),
                isOn: Binding(
                    get: { model.settings.monitoringEnabled },
                    set: { model.updateMonitoringEnabled($0) }
                )
            )

            settingToggle(
                model.text(.enableNotifications),
                isOn: Binding(
                    get: { model.settings.notificationsEnabled },
                    set: { model.updateNotificationsEnabled($0) }
                )
            )

            settingToggle(
                model.text(.allowMultipleLinks),
                isOn: Binding(
                    get: { model.settings.allowMultipleLinks },
                    set: { model.updateAllowMultipleLinks($0) }
                )
            )

            settingToggle(
                model.text(.showDockIcon),
                isOn: Binding(
                    get: { model.settings.showDockIcon },
                    set: { model.updateShowDockIcon($0) }
                )
            )

            settingToggle(
                model.text(.launchAtLogin),
                isOn: Binding(
                    get: { model.settings.launchAtLogin },
                    set: { model.updateLaunchAtLogin($0) }
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("\(model.text(.outputDirectory)): \(model.settings.outputDirectoryPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(model.text(.chooseDirectory)) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text(model.text(.repositoryDomains))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $domainsText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    }

                Button(model.text(.applyDomains)) {
                    model.updateRepositoryDomains(from: domainsText)
                    domainsText = model.repositoryDomainsText
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 560, minHeight: 560)
        .onAppear {
            domainsText = model.repositoryDomainsText
        }
        .onChange(of: model.settings.repositoryDomains) { _ in
            domainsText = model.repositoryDomainsText
        }
    }

    @ViewBuilder
    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .tint(.green)
            Spacer(minLength: 8)
            Text(isOn.wrappedValue ? "ON" : "OFF")
                .font(.caption.monospaced())
                .foregroundStyle(isOn.wrappedValue ? .green : .secondary)
        }
    }
}
