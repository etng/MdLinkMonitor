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

    let store = UserDefaultsSettingsStore(defaults: defaults, preferredObsidianVault: { nil })
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
        metadataFetchAllowedDomains: ["chromewebstore.google.com", "addons.mozilla.org"],
        attachmentResourceDirectoryPath: "~/Documents/ExampleVault/_resources",
        dailyReferenceDirectoryPath: "~/Documents/ExampleVault/daily",
        dailyReferenceSectionHeading: "## 参考链接",
        openSearchResultLinksDirectly: true,
        cloneCommandTemplate: "git clone {repo}.git",
        cloneDirectoryPath: "~/Documents/cbm/repos-custom",
        pinnedWindowOpacity: 0.72,
        pinnedWindowClickThrough: true,
        autoMergeMacWindowsEnabled: true,
        autoMergeMacWindowsBundleIDs: ["com.apple.Safari", "com.google.Chrome"],
        logRetentionDays: 14,
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
func metadataFetchAllowedDomainsAreNormalized() {
    let settings = AppSettings(
        metadataFetchAllowedDomains: ["  chromewebstore.google.com  ", "", "addons.mozilla.org", "chromewebstore.google.com"]
    )
    #expect(settings.metadataFetchAllowedDomains == ["addons.mozilla.org", "chromewebstore.google.com"])
}

@Test
func metadataFetchAllowedDomainsDefaultIncludesChromeWebStore() {
    let settings = AppSettings()
    #expect(settings.metadataFetchAllowedDomains.contains("chromewebstore.google.com"))
}

@Test
func settingsStoreFallsBackToDefaultMetadataAllowlistWhenStoredValueIsBlank() {
    let suite = "cbm.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
    }

    defaults.set("", forKey: "cbm.metadataFetchAllowedDomains")

    let store = UserDefaultsSettingsStore(defaults: defaults, preferredObsidianVault: { nil })
    let loaded = store.load()

    #expect(loaded.metadataFetchAllowedDomains == AppSettings.defaultMetadataFetchAllowedDomains)
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

@Test
func logRetentionDaysAreNormalized() {
    let settings = AppSettings(logRetentionDays: -10)
    #expect(settings.logRetentionDays == 0)
}

@Test
func autoMergeBundleIDsAreNormalized() {
    let settings = AppSettings(
        autoMergeMacWindowsBundleIDs: ["  com.apple.Safari  ", "", "com.google.Chrome", "com.apple.Safari"]
    )
    #expect(settings.autoMergeMacWindowsBundleIDs == ["com.apple.Safari", "com.google.Chrome"])
}

@Test
func autoMergeBundleIDsCanLoadFromSingleLegacyValue() {
    let suite = "cbm.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
    }

    defaults.set(true, forKey: "cbm.autoMergeMacWindowsEnabled")
    defaults.set("com.apple.Safari", forKey: "cbm.autoMergeMacWindowsBundleID")

    let store = UserDefaultsSettingsStore(defaults: defaults, preferredObsidianVault: { nil })
    let loaded = store.load()
    #expect(loaded.autoMergeMacWindowsEnabled == true)
    #expect(loaded.autoMergeMacWindowsBundleIDs == ["com.apple.Safari"])
}

@Test
func dailyReferenceSectionHeadingFallsBackWhenEmpty() {
    let settings = AppSettings(dailyReferenceSectionHeading: "   ")
    #expect(settings.dailyReferenceSectionHeading == AppSettings.defaultDailyReferenceSectionHeading)
}

@Test
func launchAtLoginRejectsDevelopmentBuildExecutable() {
    let reason = SystemIntegrationGuard.launchAtLoginFailureReason(
        executablePath: "/Users/example/Projects/MdLinkMonitor/.build/arm64-apple-macosx/debug/MdMonitor",
        homeDirectoryPath: "/Users/example"
    )

    #expect(reason == .developmentBuild(executablePath: "/Users/example/Projects/MdLinkMonitor/.build/arm64-apple-macosx/debug/MdMonitor"))
}

@Test
func launchAtLoginAllowsInstalledApplicationsApp() {
    let reason = SystemIntegrationGuard.launchAtLoginFailureReason(
        executablePath: "/Applications/MdMonitor.app/Contents/MacOS/MdMonitor",
        homeDirectoryPath: "/Users/example"
    )

    #expect(reason == nil)
}

@Test
func appRuntimeIdentityUsesDevelopmentFlavorForMdmdev() {
    let flavor = AppRuntimeIdentity.flavor(
        bundleIdentifier: nil,
        executablePath: "/Users/example/Applications/MdMonitorDev.app/Contents/Resources/mdmdev"
    )

    #expect(flavor == .development)
    #expect(AppRuntimeIdentity.commandName(for: flavor) == "mdmdev")
    #expect(AppRuntimeIdentity.defaultsSuiteName(for: flavor) == "com.y10n.mdmonitor.dev")
}

@Test
func appRuntimeIdentityUsesProductionFlavorForMdm() {
    let flavor = AppRuntimeIdentity.flavor(
        bundleIdentifier: nil,
        executablePath: "/Applications/MdMonitor.app/Contents/Resources/mdm"
    )

    #expect(flavor == .production)
    #expect(AppRuntimeIdentity.commandName(for: flavor) == "mdm")
    #expect(AppRuntimeIdentity.defaultsSuiteName(for: flavor) == "com.y10n.mdmonitor")
}

@Test
func commandLineToolResolutionRequiresInstalledAppBundle() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let appBundleURL = tempRoot
        .appendingPathComponent("Applications")
        .appendingPathComponent("MdMonitor.app")
    let macOSURL = appBundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("MacOS")
    let resourcesURL = appBundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Resources")
    try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

    let executableURL = macOSURL.appendingPathComponent("MdMonitor")
    FileManager.default.createFile(atPath: executableURL.path(percentEncoded: false), contents: Data())
    let toolURL = resourcesURL.appendingPathComponent("mdm")
    FileManager.default.createFile(atPath: toolURL.path(percentEncoded: false), contents: Data("#!/bin/sh\n".utf8))
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: toolURL.path(percentEncoded: false))

    let resolution = SystemIntegrationGuard.commandLineToolInstallResolution(
        toolName: "mdm",
        executablePath: executableURL.path(percentEncoded: false),
        homeDirectoryPath: tempRoot.path(percentEncoded: false),
        fileManager: .default
    )

    #expect(try resolution.get() == toolURL.standardizedFileURL.path(percentEncoded: false))
}

@Test
func currentBundledToolInstalledRequiresSymlinkToInstalledAppBundle() throws {
    let fileManager = FileManager.default
    let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: tempRoot) }

    let homeDirectory = tempRoot.path(percentEncoded: false)
    let appBundleURL = tempRoot
        .appendingPathComponent("Applications")
        .appendingPathComponent("MdMonitor.app")
    let macOSURL = appBundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("MacOS")
    let resourcesURL = appBundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Resources")
    try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

    let executableURL = macOSURL.appendingPathComponent("MdMonitor")
    fileManager.createFile(atPath: executableURL.path(percentEncoded: false), contents: Data())
    let toolURL = resourcesURL.appendingPathComponent("mdm")
    fileManager.createFile(atPath: toolURL.path(percentEncoded: false), contents: Data("#!/bin/sh\n".utf8))
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: toolURL.path(percentEncoded: false))

    let binDirectoryURL = tempRoot.appendingPathComponent("usr").appendingPathComponent("local").appendingPathComponent("bin")
    try fileManager.createDirectory(at: binDirectoryURL, withIntermediateDirectories: true)
    let linkURL = binDirectoryURL.appendingPathComponent("mdm")
    try fileManager.createSymbolicLink(atPath: linkURL.path(percentEncoded: false), withDestinationPath: toolURL.path(percentEncoded: false))

    #expect(
        SystemIntegrationGuard.isCurrentBundledToolInstalled(
            toolName: "mdm",
            linkPath: linkURL.path(percentEncoded: false),
            executablePath: executableURL.path(percentEncoded: false),
            homeDirectoryPath: homeDirectory,
            fileManager: fileManager
        )
    )

    try fileManager.removeItem(at: linkURL)
    let otherToolURL = tempRoot.appendingPathComponent("other-mdm")
    fileManager.createFile(atPath: otherToolURL.path(percentEncoded: false), contents: Data("#!/bin/sh\n".utf8))
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: otherToolURL.path(percentEncoded: false))
    try fileManager.createSymbolicLink(atPath: linkURL.path(percentEncoded: false), withDestinationPath: otherToolURL.path(percentEncoded: false))

    #expect(
        !SystemIntegrationGuard.isCurrentBundledToolInstalled(
            toolName: "mdm",
            linkPath: linkURL.path(percentEncoded: false),
            executablePath: executableURL.path(percentEncoded: false),
            homeDirectoryPath: homeDirectory,
            fileManager: fileManager
        )
    )
}
