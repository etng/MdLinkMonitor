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
        launchAtLogin: true,
        outputDirectoryPath: "~/Documents/cbm-custom",
        language: .en
    )

    store.save(expected)
    let loaded = store.load()

    #expect(loaded == expected)
}
