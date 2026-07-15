import MdMCore
import Dispatch
import Foundation

enum CLIError: Error {
    case unknownCommand
    case invalidArguments(String)
}

struct MdMCLI {
    private let settingsStore: any SettingsStoring
    private let commandName: String

    init(
        settingsStore: any SettingsStoring = UserDefaultsSettingsStore(defaults: AppRuntimeIdentity.currentUserDefaults()),
        commandName: String = AppRuntimeIdentity.currentCommandName
    ) {
        self.settingsStore = settingsStore
        self.commandName = commandName
    }

    func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "today":
            try runToday(arguments: Array(arguments.dropFirst()))
        case "sync-daily-md-links":
            try runSyncDailyMDLinks(arguments: Array(arguments.dropFirst()))
        case "status":
            runStatus()
        case "watchdog", "--watchdog":
            runWatchdog()
        case "help", "-h", "--help":
            printUsage()
        default:
            throw CLIError.unknownCommand
        }
    }

    private func runToday(arguments: [String]) throws {
        let printContent = arguments.contains("--print")
        let settings = settingsStore.load()
        let store = DailyMarkdownStore(baseDirectoryPath: settings.outputDirectoryPath)

        if printContent {
            let content = try store.readContent(for: Date())
            if !content.isEmpty {
                print(content, terminator: "")
            }
        } else {
            print(store.todayFileURL().path(percentEncoded: false))
        }
    }

    private func runStatus() {
        let settings = settingsStore.load()
        print("monitoring=\(settings.monitoringEnabled)")
        print("allow_multiple_links=\(settings.allowMultipleLinks)")
        print("launch_at_login=\(settings.launchAtLogin)")
        print("output_directory=\(settings.outputDirectoryPath)")
        print("metadata_fetch_allowed_domains=\(settings.metadataFetchAllowedDomains.joined(separator: ","))")
        print("attachment_resource_directory=\(settings.attachmentResourceDirectoryPath)")
        print("daily_reference_directory=\(settings.dailyReferenceDirectoryPath)")
        print("daily_reference_section_heading=\(settings.dailyReferenceSectionHeading)")
        print("open_search_result_links_directly=\(settings.openSearchResultLinksDirectly)")
        print("clone_command_template=\(settings.cloneCommandTemplate)")
        print("clone_directory=\(settings.cloneDirectoryPath)")
        print("pinned_window_opacity=\(settings.pinnedWindowOpacity)")
        print("pinned_window_click_through=\(settings.pinnedWindowClickThrough)")
        print("auto_merge_mac_windows_enabled=\(settings.autoMergeMacWindowsEnabled)")
        print("auto_merge_mac_windows_bundle_ids=\(settings.autoMergeMacWindowsBundleIDs.joined(separator: ","))")
        print("log_retention_days=\(settings.logRetentionDays)")
        print("language=\(settings.language.rawValue)")
    }

    private func runWatchdog() {
        let settings = settingsStore.load()
        guard settings.autoMergeMacWindowsEnabled else {
            fputs("auto_merge_mac_windows_enabled=false\nEnable auto-merge in MdMonitor settings first.\n", stderr)
            return
        }

        let manager = AutoMergeWindowsManager { message in
            CLIWatchdogLogger.log(message)
        }
        manager.apply(enabled: true, targetBundleIDs: settings.autoMergeMacWindowsBundleIDs)

        if settings.autoMergeMacWindowsBundleIDs.isEmpty {
            CLIWatchdogLogger.log("[watchdog] started, bundleIds=<all>")
        } else {
            CLIWatchdogLogger.log("[watchdog] started, bundleIds=\(settings.autoMergeMacWindowsBundleIDs.joined(separator: ","))")
        }
        CLIWatchdogLogger.log("[watchdog] press Ctrl-C to stop")

        let signalForwarder = CLISignalForwarder {
            CLIWatchdogLogger.log("[watchdog] stopping")
            manager.stop()
            CFRunLoopStop(CFRunLoopGetMain())
        }

        withExtendedLifetime((manager, signalForwarder)) {
            RunLoop.main.run()
        }
    }

    private func runSyncDailyMDLinks(arguments: [String]) throws {
        let settings = settingsStore.load()
        let throughDate = try parseSyncThroughDate(arguments: arguments)
        let synchronizer = DailyReferenceLinkSynchronizer(
            cbmDirectoryPath: settings.outputDirectoryPath,
            dailyRootDirectoryPath: settings.dailyReferenceDirectoryPath,
            referenceSectionHeading: settings.dailyReferenceSectionHeading
        )

        let result = try synchronizer.sync(through: throughDate)
        let through = Self.cliDateFormatter.string(from: throughDate)
        print("through=\(through)")
        print("processed_files=\(result.processedFiles)")
        print("updated_files=\(result.updatedFiles)")
        print("skipped_files=\(result.skippedFiles)")
        print("kept_links=\(result.keptLinks)")
        print("appended_links=\(result.appendedLinks)")

        persistDailyReferenceSyncThroughYMD(throughDate)
    }

    private func persistDailyReferenceSyncThroughYMD(_ throughDate: Date) {
        let throughYMD = DailyMarkdownStore.ymdString(from: throughDate)
        let defaults = AppRuntimeIdentity.currentUserDefaults()
        let key = "mdmonitor.dailyReferenceLinks.lastThroughYMD"
        let previous = defaults.string(forKey: key) ?? ""
        defaults.set(max(previous, throughYMD), forKey: key)
    }

    private func printUsage() {
        print("""
        \(commandName) commands:
          \(commandName) today --path      Print today's markdown file path (default)
          \(commandName) today --print     Print today's markdown file content
          \(commandName) sync-daily-md-links [--through yyyy-MM-dd]
                               Merge cbm links into Obsidian daily notes through yesterday by default
          \(commandName) status            Print current settings snapshot
          \(commandName) watchdog          Run auto-merge watcher in terminal
          \(commandName) --watchdog        Same as `\(commandName) watchdog`
          \(commandName) help              Show this message
        """)
    }

    private func parseSyncThroughDate(arguments: [String]) throws -> Date {
        var explicitDate: String?
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--through" {
                let nextIndex = index + 1
                guard nextIndex < arguments.count else {
                    throw CLIError.invalidArguments("Missing value after --through")
                }
                explicitDate = arguments[nextIndex]
                index += 2
                continue
            }
            if argument.hasPrefix("--through=") {
                explicitDate = String(argument.dropFirst("--through=".count))
                index += 1
                continue
            }
            throw CLIError.invalidArguments("Unknown argument: \(argument)")
        }

        guard let yesterday = Self.yesterday() else {
            throw CLIError.invalidArguments("Unable to resolve yesterday")
        }
        guard let explicitDate else {
            return yesterday
        }
        guard let parsed = Self.cliDateFormatter.date(from: explicitDate) else {
            throw CLIError.invalidArguments("Invalid --through date, expected yyyy-MM-dd")
        }
        return min(parsed, yesterday)
    }

    private static func yesterday(now: Date = Date()) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -1, to: startOfToday)
    }

    private static let cliDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum CLIWatchdogLogger {
    static func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        fputs("\(timestamp) [INFO] \(message)\n", stderr)
    }
}

private final class CLISignalForwarder {
    private var sources: [DispatchSourceSignal] = []

    init(onSignal: @escaping @Sendable () -> Void) {
        for signalNumber in [SIGINT, SIGTERM] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler(handler: onSignal)
            source.resume()
            sources.append(source)
        }
    }
}

do {
    let cli = MdMCLI()
    try cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch CLIError.unknownCommand {
    fputs("Unknown command. Use '\(AppRuntimeIdentity.currentCommandName) help'.\n", stderr)
    exit(2)
} catch CLIError.invalidArguments(let message) {
    fputs("\(message)\n", stderr)
    exit(2)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
