import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case zhHans = "zh-Hans"
    case en = "en"

    public var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

public struct AppSettings: Equatable, Sendable {
    public static let cloneCommandPlaceholder = "{repo}"
    public static let defaultCloneCommandTemplate = "git clone {repo}.git"
    public static let defaultCloneDirectoryPath = "~/Documents/cbm/repos"
    public static let defaultPinnedWindowOpacity = 0.88
    public static let defaultRestAPIBindAddress = "127.0.0.1"
    public static let defaultRestAPIPort = 18731
    public static let defaultRestAPIToken = "mdmonitor-local-token"
    public static let defaultLogRetentionDays = 0
    public static let defaultAttachmentResourceDirectoryPath = "~/Documents/Obsidian/_resources"
    public static let defaultDailyReferenceSectionHeading = "## 参考链接"
    public static let defaultMetadataFetchAllowedDomains = ["chromewebstore.google.com"]

    public var monitoringEnabled: Bool
    public var notificationsEnabled: Bool
    public var allowMultipleLinks: Bool
    public var showDockIcon: Bool
    public var previewMarkdownFontSize: Double
    public var previewCalendarScale: Double
    public var launchAtLogin: Bool
    public var outputDirectoryPath: String
    public var repositoryDomains: [String]
    public var metadataFetchAllowedDomains: [String]
    public var attachmentResourceDirectoryPath: String
    public var dailyReferenceDirectoryPath: String
    public var dailyReferenceSectionHeading: String
    public var openSearchResultLinksDirectly: Bool
    public var cloneCommandTemplate: String
    public var cloneDirectoryPath: String
    public var pinnedWindowOpacity: Double
    public var pinnedWindowClickThrough: Bool
    public var autoMergeMacWindowsEnabled: Bool
    public var autoMergeMacWindowsBundleIDs: [String]
    public var logRetentionDays: Int
    public var restAPIEnabled: Bool
    public var restAPIBindAddress: String
    public var restAPIPort: Int
    public var restAPIToken: String
    public var experimentalSettingsTabsEnabled: Bool
    public var language: AppLanguage

    public init(
        monitoringEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        allowMultipleLinks: Bool = false,
        showDockIcon: Bool = true,
        previewMarkdownFontSize: Double = 16.0,
        previewCalendarScale: Double = 1.15,
        launchAtLogin: Bool = false,
        outputDirectoryPath: String = DailyMarkdownStore.defaultDirectoryPath,
        repositoryDomains: [String] = ["github.com", "gitlab.com"],
        metadataFetchAllowedDomains: [String] = AppSettings.defaultMetadataFetchAllowedDomains,
        attachmentResourceDirectoryPath: String = AppSettings.defaultAttachmentResourceDirectoryPath,
        dailyReferenceDirectoryPath: String? = nil,
        dailyReferenceSectionHeading: String = AppSettings.defaultDailyReferenceSectionHeading,
        openSearchResultLinksDirectly: Bool = false,
        cloneCommandTemplate: String = AppSettings.defaultCloneCommandTemplate,
        cloneDirectoryPath: String = AppSettings.defaultCloneDirectoryPath,
        pinnedWindowOpacity: Double = AppSettings.defaultPinnedWindowOpacity,
        pinnedWindowClickThrough: Bool = false,
        autoMergeMacWindowsEnabled: Bool = false,
        autoMergeMacWindowsBundleIDs: [String] = [],
        logRetentionDays: Int = AppSettings.defaultLogRetentionDays,
        restAPIEnabled: Bool = false,
        restAPIBindAddress: String = AppSettings.defaultRestAPIBindAddress,
        restAPIPort: Int = AppSettings.defaultRestAPIPort,
        restAPIToken: String = AppSettings.defaultRestAPIToken,
        experimentalSettingsTabsEnabled: Bool = false,
        language: AppLanguage = .zhHans
    ) {
        self.monitoringEnabled = monitoringEnabled
        self.notificationsEnabled = notificationsEnabled
        self.allowMultipleLinks = allowMultipleLinks
        self.showDockIcon = showDockIcon
        self.previewMarkdownFontSize = max(12, min(previewMarkdownFontSize, 28))
        self.previewCalendarScale = max(0.9, min(previewCalendarScale, 1.8))
        self.launchAtLogin = launchAtLogin
        let normalizedAttachmentResourceDirectoryPath = Self.normalizeDirectoryPath(
            attachmentResourceDirectoryPath,
            fallback: Self.defaultAttachmentResourceDirectoryPath
        )
        self.outputDirectoryPath = outputDirectoryPath
        self.repositoryDomains = Self.normalizeDomains(repositoryDomains)
        self.metadataFetchAllowedDomains = Self.normalizeDomains(metadataFetchAllowedDomains)
        self.attachmentResourceDirectoryPath = normalizedAttachmentResourceDirectoryPath
        self.dailyReferenceDirectoryPath = Self.normalizeDirectoryPath(
            dailyReferenceDirectoryPath ?? Self.defaultDailyReferenceDirectoryPath(
                attachmentResourceDirectoryPath: normalizedAttachmentResourceDirectoryPath
            ),
            fallback: Self.defaultDailyReferenceDirectoryPath(
                attachmentResourceDirectoryPath: normalizedAttachmentResourceDirectoryPath
            )
        )
        self.dailyReferenceSectionHeading = Self.normalizeDailyReferenceSectionHeading(dailyReferenceSectionHeading)
        self.openSearchResultLinksDirectly = openSearchResultLinksDirectly
        self.cloneCommandTemplate = Self.normalizeCloneCommandTemplate(cloneCommandTemplate)
        self.cloneDirectoryPath = Self.normalizeDirectoryPath(cloneDirectoryPath, fallback: Self.defaultCloneDirectoryPath)
        self.pinnedWindowOpacity = max(0.40, min(pinnedWindowOpacity, 1.00))
        self.pinnedWindowClickThrough = pinnedWindowClickThrough
        self.autoMergeMacWindowsEnabled = autoMergeMacWindowsEnabled
        self.autoMergeMacWindowsBundleIDs = Self.normalizeBundleIDs(autoMergeMacWindowsBundleIDs)
        self.logRetentionDays = Self.normalizeLogRetentionDays(logRetentionDays)
        self.restAPIEnabled = restAPIEnabled
        self.restAPIBindAddress = Self.normalizeRestAPIBindAddress(restAPIBindAddress)
        self.restAPIPort = Self.normalizeRestAPIPort(restAPIPort)
        self.restAPIToken = Self.normalizeRestAPIToken(restAPIToken)
        self.experimentalSettingsTabsEnabled = experimentalSettingsTabsEnabled
        self.language = language
    }

    public static func normalizeDomains(_ domains: [String]) -> [String] {
        let cleaned = domains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted()
    }

    public static func parseDomains(from text: String) -> [String] {
        normalizeDomains(
            text
                .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " || $0 == "\t" })
                .map(String.init)
        )
    }

    public static func normalizeCloneCommandTemplate(_ template: String) -> String {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains(cloneCommandPlaceholder) else {
            return defaultCloneCommandTemplate
        }
        return trimmed
    }

    public static func normalizeDirectoryPath(_ path: String, fallback: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    public static func defaultDailyReferenceDirectoryPath(attachmentResourceDirectoryPath: String) -> String {
        DailyReferenceLinkSynchronizer.defaultDailyRootDirectoryPath(
            attachmentResourceDirectoryPath: attachmentResourceDirectoryPath
        )
    }

    public static func normalizeDailyReferenceSectionHeading(_ heading: String) -> String {
        let trimmed = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultDailyReferenceSectionHeading : trimmed
    }

    public static func normalizeBundleIDs(_ bundleIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in bundleIDs {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    public static func parseBundleIDs(from text: String) -> [String] {
        normalizeBundleIDs(
            text
                .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == "\r" })
                .map(String.init)
        )
    }

    public static func normalizeRestAPIBindAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultRestAPIBindAddress : trimmed
    }

    public static func normalizeLogRetentionDays(_ days: Int) -> Int {
        max(0, days)
    }

    public static func normalizeRestAPIPort(_ port: Int) -> Int {
        (1...65535).contains(port) ? port : defaultRestAPIPort
    }

    public static func normalizeRestAPIToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultRestAPIToken : trimmed
    }

    public static func makeRandomRestAPIToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}

public protocol SettingsStoring {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

public final class UserDefaultsSettingsStore: SettingsStoring {
    private enum Keys {
        static let monitoringEnabled = "cbm.monitoringEnabled"
        static let notificationsEnabled = "cbm.notificationsEnabled"
        static let allowMultipleLinks = "cbm.allowMultipleLinks"
        static let showDockIcon = "cbm.showDockIcon"
        static let previewMarkdownFontSize = "cbm.previewMarkdownFontSize"
        static let previewCalendarScale = "cbm.previewCalendarScale"
        static let launchAtLogin = "cbm.launchAtLogin"
        static let outputDirectoryPath = "cbm.outputDirectoryPath"
        static let repositoryDomains = "cbm.repositoryDomains"
        static let metadataFetchAllowedDomains = "cbm.metadataFetchAllowedDomains"
        static let attachmentResourceDirectoryPath = "cbm.attachmentResourceDirectoryPath"
        static let dailyReferenceDirectoryPath = "cbm.dailyReferenceDirectoryPath"
        static let dailyReferenceSectionHeading = "cbm.dailyReferenceSectionHeading"
        static let openSearchResultLinksDirectly = "cbm.openSearchResultLinksDirectly"
        static let cloneCommandTemplate = "cbm.cloneCommandTemplate"
        static let cloneDirectoryPath = "cbm.cloneDirectoryPath"
        static let pinnedWindowOpacity = "cbm.pinnedWindowOpacity"
        static let pinnedWindowClickThrough = "cbm.pinnedWindowClickThrough"
        static let autoMergeMacWindowsEnabled = "cbm.autoMergeMacWindowsEnabled"
        static let autoMergeMacWindowsBundleID = "cbm.autoMergeMacWindowsBundleID"
        static let logRetentionDays = "cbm.logRetentionDays"
        static let restAPIEnabled = "cbm.restAPIEnabled"
        static let restAPIBindAddress = "cbm.restAPIBindAddress"
        static let restAPIPort = "cbm.restAPIPort"
        static let restAPIToken = "cbm.restAPIToken"
        static let experimentalSettingsTabsEnabled = "cbm.experimentalSettingsTabsEnabled"
        static let language = "cbm.language"
    }

    private let defaults: UserDefaults
    private let preferredObsidianVault: () -> ObsidianVaultLocation?

    public init(
        defaults: UserDefaults = AppRuntimeIdentity.currentUserDefaults(),
        preferredObsidianVault: @escaping () -> ObsidianVaultLocation? = {
            ObsidianVaultDiscovery().preferredVault()
        }
    ) {
        self.defaults = defaults
        self.preferredObsidianVault = preferredObsidianVault
    }

    public func load() -> AppSettings {
        let language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .zhHans
        let storedToken = defaults.string(forKey: Keys.restAPIToken) ?? ""
        let normalizedToken: String
        if storedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedToken = AppSettings.makeRandomRestAPIToken()
            defaults.set(normalizedToken, forKey: Keys.restAPIToken)
        } else {
            normalizedToken = AppSettings.normalizeRestAPIToken(storedToken)
        }

        let domainsRaw = defaults.string(forKey: Keys.repositoryDomains) ?? "github.com,gitlab.com"
        let metadataDomainsRaw: String = {
            guard let stored = defaults.string(forKey: Keys.metadataFetchAllowedDomains) else {
                return AppSettings.defaultMetadataFetchAllowedDomains.joined(separator: ",")
            }

            let parsed = AppSettings.parseDomains(from: stored)
            guard !parsed.isEmpty else {
                return AppSettings.defaultMetadataFetchAllowedDomains.joined(separator: ",")
            }
            return stored
        }()

        let autoMergeBundleIDsRaw = defaults.string(forKey: Keys.autoMergeMacWindowsBundleID) ?? ""
        let storedAttachmentResourceDirectoryPath = defaults.string(forKey: Keys.attachmentResourceDirectoryPath)
        let storedDailyReferenceDirectoryPath = defaults.string(forKey: Keys.dailyReferenceDirectoryPath)
        let discoveredVault = storedAttachmentResourceDirectoryPath == nil && storedDailyReferenceDirectoryPath == nil
            ? preferredObsidianVault()
            : nil

        if let discoveredVault {
            defaults.set(discoveredVault.attachmentResourceDirectoryPath, forKey: Keys.attachmentResourceDirectoryPath)
            defaults.set(discoveredVault.dailyReferenceDirectoryPath, forKey: Keys.dailyReferenceDirectoryPath)
        }

        return AppSettings(
            monitoringEnabled: defaults.object(forKey: Keys.monitoringEnabled) as? Bool ?? true,
            notificationsEnabled: defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true,
            allowMultipleLinks: defaults.object(forKey: Keys.allowMultipleLinks) as? Bool ?? false,
            showDockIcon: defaults.object(forKey: Keys.showDockIcon) as? Bool ?? true,
            previewMarkdownFontSize: defaults.object(forKey: Keys.previewMarkdownFontSize) as? Double ?? 16.0,
            previewCalendarScale: defaults.object(forKey: Keys.previewCalendarScale) as? Double ?? 1.15,
            launchAtLogin: defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false,
            outputDirectoryPath: defaults.string(forKey: Keys.outputDirectoryPath) ?? DailyMarkdownStore.defaultDirectoryPath,
            repositoryDomains: AppSettings.parseDomains(from: domainsRaw),
            metadataFetchAllowedDomains: AppSettings.parseDomains(from: metadataDomainsRaw),
            attachmentResourceDirectoryPath: storedAttachmentResourceDirectoryPath
                ?? discoveredVault?.attachmentResourceDirectoryPath
                ?? AppSettings.defaultAttachmentResourceDirectoryPath,
            dailyReferenceDirectoryPath: storedDailyReferenceDirectoryPath
                ?? discoveredVault?.dailyReferenceDirectoryPath,
            dailyReferenceSectionHeading: defaults.string(forKey: Keys.dailyReferenceSectionHeading) ?? AppSettings.defaultDailyReferenceSectionHeading,
            openSearchResultLinksDirectly: defaults.object(forKey: Keys.openSearchResultLinksDirectly) as? Bool ?? false,
            cloneCommandTemplate: defaults.string(forKey: Keys.cloneCommandTemplate) ?? AppSettings.defaultCloneCommandTemplate,
            cloneDirectoryPath: defaults.string(forKey: Keys.cloneDirectoryPath) ?? AppSettings.defaultCloneDirectoryPath,
            pinnedWindowOpacity: defaults.object(forKey: Keys.pinnedWindowOpacity) as? Double ?? AppSettings.defaultPinnedWindowOpacity,
            pinnedWindowClickThrough: defaults.object(forKey: Keys.pinnedWindowClickThrough) as? Bool ?? false,
            autoMergeMacWindowsEnabled: defaults.object(forKey: Keys.autoMergeMacWindowsEnabled) as? Bool ?? false,
            autoMergeMacWindowsBundleIDs: AppSettings.parseBundleIDs(from: autoMergeBundleIDsRaw),
            logRetentionDays: defaults.object(forKey: Keys.logRetentionDays) as? Int ?? AppSettings.defaultLogRetentionDays,
            restAPIEnabled: defaults.object(forKey: Keys.restAPIEnabled) as? Bool ?? false,
            restAPIBindAddress: defaults.string(forKey: Keys.restAPIBindAddress) ?? AppSettings.defaultRestAPIBindAddress,
            restAPIPort: defaults.object(forKey: Keys.restAPIPort) as? Int ?? AppSettings.defaultRestAPIPort,
            restAPIToken: normalizedToken,
            experimentalSettingsTabsEnabled: defaults.object(forKey: Keys.experimentalSettingsTabsEnabled) as? Bool ?? false,
            language: language
        )
    }

    public func save(_ settings: AppSettings) {
        defaults.set(settings.monitoringEnabled, forKey: Keys.monitoringEnabled)
        defaults.set(settings.notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(settings.allowMultipleLinks, forKey: Keys.allowMultipleLinks)
        defaults.set(settings.showDockIcon, forKey: Keys.showDockIcon)
        defaults.set(settings.previewMarkdownFontSize, forKey: Keys.previewMarkdownFontSize)
        defaults.set(settings.previewCalendarScale, forKey: Keys.previewCalendarScale)
        defaults.set(settings.launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(settings.outputDirectoryPath, forKey: Keys.outputDirectoryPath)
        defaults.set(settings.repositoryDomains.joined(separator: ","), forKey: Keys.repositoryDomains)
        defaults.set(settings.metadataFetchAllowedDomains.joined(separator: ","), forKey: Keys.metadataFetchAllowedDomains)
        defaults.set(settings.attachmentResourceDirectoryPath, forKey: Keys.attachmentResourceDirectoryPath)
        defaults.set(settings.dailyReferenceDirectoryPath, forKey: Keys.dailyReferenceDirectoryPath)
        defaults.set(settings.dailyReferenceSectionHeading, forKey: Keys.dailyReferenceSectionHeading)
        defaults.set(settings.openSearchResultLinksDirectly, forKey: Keys.openSearchResultLinksDirectly)
        defaults.set(settings.cloneCommandTemplate, forKey: Keys.cloneCommandTemplate)
        defaults.set(settings.cloneDirectoryPath, forKey: Keys.cloneDirectoryPath)
        defaults.set(settings.pinnedWindowOpacity, forKey: Keys.pinnedWindowOpacity)
        defaults.set(settings.pinnedWindowClickThrough, forKey: Keys.pinnedWindowClickThrough)
        defaults.set(settings.autoMergeMacWindowsEnabled, forKey: Keys.autoMergeMacWindowsEnabled)
        defaults.set(settings.autoMergeMacWindowsBundleIDs.joined(separator: "\n"), forKey: Keys.autoMergeMacWindowsBundleID)
        defaults.set(settings.logRetentionDays, forKey: Keys.logRetentionDays)
        defaults.set(settings.restAPIEnabled, forKey: Keys.restAPIEnabled)
        defaults.set(settings.restAPIBindAddress, forKey: Keys.restAPIBindAddress)
        defaults.set(settings.restAPIPort, forKey: Keys.restAPIPort)
        defaults.set(settings.restAPIToken, forKey: Keys.restAPIToken)
        defaults.set(settings.experimentalSettingsTabsEnabled, forKey: Keys.experimentalSettingsTabsEnabled)
        defaults.set(settings.language.rawValue, forKey: Keys.language)
    }
}
