import Foundation
import Testing
@testable import MdMCore

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
        cloneDirectoryPath: "~/Documents/cbm/repos-custom",
        pinnedWindowOpacity: 0.72,
        pinnedWindowClickThrough: true,
        restAPIEnabled: true,
        restAPIBindAddress: "127.0.0.1",
        restAPIPort: 19090,
        restAPIToken: "test-token-123",
        experimentalSettingsTabsEnabled: true,
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

@Test
func cloneDirectoryFallsBackWhenEmpty() {
    let settings = AppSettings(cloneDirectoryPath: "   ")
    #expect(settings.cloneDirectoryPath == AppSettings.defaultCloneDirectoryPath)
}

@Test
func pinnedWindowOpacityIsClamped() {
    let low = AppSettings(pinnedWindowOpacity: 0.1)
    #expect(low.pinnedWindowOpacity == 0.40)

    let high = AppSettings(pinnedWindowOpacity: 1.5)
    #expect(high.pinnedWindowOpacity == 1.00)
}

@Test
func restAPIPortIsNormalized() {
    let low = AppSettings(restAPIPort: 0)
    #expect(low.restAPIPort == AppSettings.defaultRestAPIPort)

    let high = AppSettings(restAPIPort: 70000)
    #expect(high.restAPIPort == AppSettings.defaultRestAPIPort)
}
