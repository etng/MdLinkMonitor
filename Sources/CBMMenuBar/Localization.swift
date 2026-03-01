import CBMCore
import Foundation

enum L10nKey {
    case appTitle
    case enableMonitoring
    case enableNotifications
    case allowMultipleLinks
    case showDockIcon
    case launchAtLogin
    case outputDirectory
    case chooseDirectory
    case openSettings
    case settingsTitle
    case repositoryDomains
    case applyDomains
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
    case todayLogs
    case checkForUpdates
    case aboutHeadline
    case aboutDescription
}

enum AppLocalizer {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            switch key {
            case .appTitle: return "MdMonitor"
            case .enableMonitoring: return "启用监控"
            case .enableNotifications: return "系统通知"
            case .allowMultipleLinks: return "允许多链接"
            case .showDockIcon: return "显示 Dock 图标"
            case .launchAtLogin: return "开机启动"
            case .outputDirectory: return "输出目录"
            case .chooseDirectory: return "选择目录"
            case .openSettings: return "打开设置"
            case .settingsTitle: return "设置"
            case .repositoryDomains: return "仓库域名（每行一个）"
            case .applyDomains: return "应用域名配置"
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
            case .todayLogs: return "今日日志（自动刷新）"
            case .checkForUpdates: return "检查更新"
            case .aboutHeadline: return "MdMonitor"
            case .aboutDescription: return "一个用于从 Markdown 链接中收集 Git 仓库并自动处理的 Swift 菜单栏应用。"
            }
        case .en:
            switch key {
            case .appTitle: return "MdMonitor"
            case .enableMonitoring: return "Enable Monitoring"
            case .enableNotifications: return "System Notifications"
            case .allowMultipleLinks: return "Allow Multiple Links"
            case .showDockIcon: return "Show Dock Icon"
            case .launchAtLogin: return "Launch at Login"
            case .outputDirectory: return "Output Directory"
            case .chooseDirectory: return "Choose Directory"
            case .openSettings: return "Open Settings"
            case .settingsTitle: return "Settings"
            case .repositoryDomains: return "Repository Domains (one per line)"
            case .applyDomains: return "Apply Domains"
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
            case .todayLogs: return "Today's Logs (Auto Refresh)"
            case .checkForUpdates: return "Check for Updates"
            case .aboutHeadline: return "MdMonitor"
            case .aboutDescription: return "Swift menu bar app for collecting and processing Git repositories from markdown links."
            }
        }
    }
}
