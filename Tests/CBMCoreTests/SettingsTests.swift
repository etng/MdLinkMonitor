import Foundation
import Testing
@testable import CBMCore

@Test
func settingsStoreRoundTrip() {
    let suite = "cbm.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
    }

    let store = UserDefaultsSettingsStore(defaults: defaults)
    let expected = AppSettings(
        monitoringEnabled: true,
        notificationsEnabled: true,
        allowMultipleLinks: true,
        showDockIcon: false,
        previewMarkdownFontSize: 18.0,
        previewCalendarScale: 1.3,
        launchAtLogin: true,
        outputDirectoryPath: "~/Documents/cbm-custom",
        repositoryDomains: ["github.com", "gitlab.com", "self-host.example.com"],
        cloneCommandTemplate: "git clone {repo}.git",
        language: .en
    )

    store.save(expected)
    let loaded = store.load()

    #expect(loaded == expected)
}

@Test
func cloneCommandTemplateFallsBackWhenMissingPlaceholder() {
    let settings = AppSettings(cloneCommandTemplate: "git clone")
    #expect(settings.cloneCommandTemplate == AppSettings.defaultCloneCommandTemplate)
}
