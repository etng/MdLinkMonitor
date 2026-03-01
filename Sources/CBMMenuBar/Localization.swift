import CBMCore
import Foundation

enum L10nKey {
    case appTitle
    case enableMonitoring
    case allowMultipleLinks
    case launchAtLogin
    case outputDirectory
    case chooseDirectory
    case language
    case recentFiles
    case noRecentFiles
    case openToday
    case statusIdle
    case about
    case quit
    case previewTitle
    case reload
    case checkForUpdates
}

enum AppLocalizer {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            switch key {
            case .appTitle: return "剪贴板仓库监视"
            case .enableMonitoring: return "启用监控"
            case .allowMultipleLinks: return "允许多链接"
            case .launchAtLogin: return "开机启动"
            case .outputDirectory: return "输出目录"
            case .chooseDirectory: return "选择目录"
            case .language: return "语言"
            case .recentFiles: return "最近文件"
            case .noRecentFiles: return "暂无记录"
            case .openToday: return "打开今天文件"
            case .statusIdle: return "空闲"
            case .about: return "关于"
            case .quit: return "退出"
            case .previewTitle: return "Markdown 预览"
            case .reload: return "刷新"
            case .checkForUpdates: return "检查更新"
            }
        case .en:
            switch key {
            case .appTitle: return "Clipboard Repo Monitor"
            case .enableMonitoring: return "Enable Monitoring"
            case .allowMultipleLinks: return "Allow Multiple Links"
            case .launchAtLogin: return "Launch at Login"
            case .outputDirectory: return "Output Directory"
            case .chooseDirectory: return "Choose Directory"
            case .language: return "Language"
            case .recentFiles: return "Recent Files"
            case .noRecentFiles: return "No Files"
            case .openToday: return "Open Today"
            case .statusIdle: return "Idle"
            case .about: return "About"
            case .quit: return "Quit"
            case .previewTitle: return "Markdown Preview"
            case .reload: return "Reload"
            case .checkForUpdates: return "Check for Updates"
            }
        }
    }
}
