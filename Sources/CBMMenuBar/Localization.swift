import CBMCore
import Foundation

enum L10nKey {
    case appTitle
    case enableMonitoring
    case enableNotifications
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
    case copyMarkdown
    case copied
    case historyFiles
    case emptyContent
    case checkForUpdates
    case aboutHeadline
    case aboutDescription
}

enum AppLocalizer {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            switch key {
            case .appTitle: return "剪贴板仓库监视"
            case .enableMonitoring: return "启用监控"
            case .enableNotifications: return "系统通知"
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
            case .copyMarkdown: return "复制 Markdown"
            case .copied: return "已复制"
            case .historyFiles: return "历史文件"
            case .emptyContent: return "该文件暂无内容"
            case .checkForUpdates: return "检查更新"
            case .aboutHeadline: return "剪贴板仓库监视"
            case .aboutDescription: return "一个用于从 Markdown 链接中收集 GitHub 仓库的 Swift 菜单栏应用。"
            }
        case .en:
            switch key {
            case .appTitle: return "Clipboard Repo Monitor"
            case .enableMonitoring: return "Enable Monitoring"
            case .enableNotifications: return "System Notifications"
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
            case .copyMarkdown: return "Copy Markdown"
            case .copied: return "Copied"
            case .historyFiles: return "History"
            case .emptyContent: return "No content in this file"
            case .checkForUpdates: return "Check for Updates"
            case .aboutHeadline: return "Clipboard Repo Monitor"
            case .aboutDescription: return "Swift menu bar app for collecting GitHub repos from markdown links."
            }
        }
    }
}
