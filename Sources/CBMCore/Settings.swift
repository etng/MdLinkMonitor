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
    public var monitoringEnabled: Bool
    public var notificationsEnabled: Bool
    public var allowMultipleLinks: Bool
    public var launchAtLogin: Bool
    public var outputDirectoryPath: String
    public var language: AppLanguage

    public init(
        monitoringEnabled: Bool = false,
        notificationsEnabled: Bool = true,
        allowMultipleLinks: Bool = false,
        launchAtLogin: Bool = false,
        outputDirectoryPath: String = DailyMarkdownStore.defaultDirectoryPath,
        language: AppLanguage = .zhHans
    ) {
        self.monitoringEnabled = monitoringEnabled
        self.notificationsEnabled = notificationsEnabled
        self.allowMultipleLinks = allowMultipleLinks
        self.launchAtLogin = launchAtLogin
        self.outputDirectoryPath = outputDirectoryPath
        self.language = language
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
        static let launchAtLogin = "cbm.launchAtLogin"
        static let outputDirectoryPath = "cbm.outputDirectoryPath"
        static let language = "cbm.language"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        let language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .zhHans

        return AppSettings(
            monitoringEnabled: defaults.object(forKey: Keys.monitoringEnabled) as? Bool ?? false,
            notificationsEnabled: defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true,
            allowMultipleLinks: defaults.object(forKey: Keys.allowMultipleLinks) as? Bool ?? false,
            launchAtLogin: defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false,
            outputDirectoryPath: defaults.string(forKey: Keys.outputDirectoryPath) ?? DailyMarkdownStore.defaultDirectoryPath,
            language: language
        )
    }

    public func save(_ settings: AppSettings) {
        defaults.set(settings.monitoringEnabled, forKey: Keys.monitoringEnabled)
        defaults.set(settings.notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(settings.allowMultipleLinks, forKey: Keys.allowMultipleLinks)
        defaults.set(settings.launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(settings.outputDirectoryPath, forKey: Keys.outputDirectoryPath)
        defaults.set(settings.language.rawValue, forKey: Keys.language)
    }
}
