import Foundation
import Testing
@testable import MdMCore

@Test
func obsidianVaultDiscoveryPrefersOpenVault() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let openVault = tempRoot.appendingPathComponent("Open Vault", isDirectory: true)
    let recentVault = tempRoot.appendingPathComponent("Recent Vault", isDirectory: true)
    let configurationURL = tempRoot.appendingPathComponent("obsidian.json")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: openVault, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: recentVault, withIntermediateDirectories: true)
    let configuration: [String: Any] = [
        "vaults": [
            "open": ["path": openVault.path(percentEncoded: false), "open": true, "ts": 100],
            "recent": ["path": recentVault.path(percentEncoded: false), "open": false, "ts": 200],
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: configuration)
    try data.write(to: configurationURL)

    let discovered = ObsidianVaultDiscovery(configurationURL: configurationURL).preferredVault()

    #expect(discovered?.vaultDirectoryPath == openVault.path(percentEncoded: false))
    #expect(discovered?.attachmentResourceDirectoryPath == openVault.appendingPathComponent("_resources").path(percentEncoded: false))
    #expect(discovered?.dailyReferenceDirectoryPath == openVault.appendingPathComponent("daily").path(percentEncoded: false))
}

@Test
func obsidianVaultDiscoveryFallsBackToMostRecentAvailableVault() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let olderVault = tempRoot.appendingPathComponent("Older", isDirectory: true)
    let newerVault = tempRoot.appendingPathComponent("Newer", isDirectory: true)
    let configurationURL = tempRoot.appendingPathComponent("obsidian.json")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: olderVault, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newerVault, withIntermediateDirectories: true)
    let configuration: [String: Any] = [
        "vaults": [
            "older": ["path": olderVault.path(percentEncoded: false), "ts": 100],
            "newer": ["path": newerVault.path(percentEncoded: false), "ts": 200],
            "missing": ["path": tempRoot.appendingPathComponent("Missing").path(percentEncoded: false), "open": true, "ts": 300],
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: configuration)
    try data.write(to: configurationURL)

    let discovered = ObsidianVaultDiscovery(configurationURL: configurationURL).preferredVault()

    #expect(discovered?.vaultDirectoryPath == newerVault.path(percentEncoded: false))
}

@Test
func settingsStoreUsesDiscoveredVaultOnlyWhenVaultDirectoriesAreUnset() {
    let suite = "cbm.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let discovered = ObsidianVaultLocation(vaultDirectoryPath: "/Users/example/Documents/ExampleVault")
    let store = UserDefaultsSettingsStore(defaults: defaults) { discovered }

    let loaded = store.load()

    #expect(loaded.attachmentResourceDirectoryPath == "/Users/example/Documents/ExampleVault/_resources")
    #expect(loaded.dailyReferenceDirectoryPath == "/Users/example/Documents/ExampleVault/daily")

    defaults.set("/Users/example/Documents/CustomResources", forKey: "cbm.attachmentResourceDirectoryPath")
    defaults.set("/Users/example/Documents/CustomDaily", forKey: "cbm.dailyReferenceDirectoryPath")
    let explicitlyConfigured = UserDefaultsSettingsStore(defaults: defaults) {
        ObsidianVaultLocation(vaultDirectoryPath: "/Users/example/Documents/OtherVault")
    }.load()

    #expect(explicitlyConfigured.attachmentResourceDirectoryPath == "/Users/example/Documents/CustomResources")
    #expect(explicitlyConfigured.dailyReferenceDirectoryPath == "/Users/example/Documents/CustomDaily")
}
