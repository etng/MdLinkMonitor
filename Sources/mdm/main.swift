import MdMCore
import Foundation

enum CLIError: Error {
    case unknownCommand
}

struct MdMCLI {
    private let settingsStore: any SettingsStoring

    init(settingsStore: any SettingsStoring = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
    }

    func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "today":
            try runToday(arguments: Array(arguments.dropFirst()))
        case "status":
            runStatus()
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
        print("clone_command_template=\(settings.cloneCommandTemplate)")
        print("clone_directory=\(settings.cloneDirectoryPath)")
        print("pinned_window_opacity=\(settings.pinnedWindowOpacity)")
        print("pinned_window_click_through=\(settings.pinnedWindowClickThrough)")
        print("language=\(settings.language.rawValue)")
    }

    private func printUsage() {
        print("""
        mdm commands:
          mdm today --path      Print today's markdown file path (default)
          mdm today --print     Print today's markdown file content
          mdm status            Print current settings snapshot
          mdm help              Show this message
        """)
    }
}

do {
    let cli = MdMCLI()
    try cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch CLIError.unknownCommand {
    fputs("Unknown command. Use 'mdm help'.\n", stderr)
    exit(2)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
