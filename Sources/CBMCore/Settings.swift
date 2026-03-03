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

    public var monitoringEnabled: Bool
    public var notificationsEnabled: Bool
    public var allowMultipleLinks: Bool
    public var showDockIcon: Bool
    public var previewMarkdownFontSize: Double
    public var previewCalendarScale: Double
    public var launchAtLogin: Bool
    public var outputDirectoryPath: String
    public var repositoryDomains: [String]
    public var cloneCommandTemplate: String
    public var cloneDirectoryPath: String
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
        cloneCommandTemplate: String = AppSettings.defaultCloneCommandTemplate,
        cloneDirectoryPath: String = AppSettings.defaultCloneDirectoryPath,
        language: AppLanguage = .zhHans
    ) {
        self.monitoringEnabled = monitoringEnabled
        self.notificationsEnabled = notificationsEnabled
        self.allowMultipleLinks = allowMultipleLinks
        self.showDockIcon = showDockIcon
        self.previewMarkdownFontSize = max(12, min(previewMarkdownFontSize, 28))
        self.previewCalendarScale = max(0.9, min(previewCalendarScale, 1.8))
        self.launchAtLogin = launchAtLogin
        self.outputDirectoryPath = outputDirectoryPath
        self.repositoryDomains = Self.normalizeDomains(repositoryDomains)
        self.cloneCommandTemplate = Self.normalizeCloneCommandTemplate(cloneCommandTemplate)
        self.cloneDirectoryPath = Self.normalizeDirectoryPath(cloneDirectoryPath, fallback: Self.defaultCloneDirectoryPath)
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
        static let cloneCommandTemplate = "cbm.cloneCommandTemplate"
        static let cloneDirectoryPath = "cbm.cloneDirectoryPath"
        static let language = "cbm.language"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        let language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .zhHans

        let domainsRaw = defaults.string(forKey: Keys.repositoryDomains) ?? "github.com,gitlab.com"

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
            cloneCommandTemplate: defaults.string(forKey: Keys.cloneCommandTemplate) ?? AppSettings.defaultCloneCommandTemplate,
            cloneDirectoryPath: defaults.string(forKey: Keys.cloneDirectoryPath) ?? AppSettings.defaultCloneDirectoryPath,
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
        defaults.set(settings.cloneCommandTemplate, forKey: Keys.cloneCommandTemplate)
        defaults.set(settings.cloneDirectoryPath, forKey: Keys.cloneDirectoryPath)
        defaults.set(settings.language.rawValue, forKey: Keys.language)
    }
}
