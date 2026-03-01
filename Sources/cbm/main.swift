import CBMCore
import Foundation

enum CLIError: Error {
    case unknownCommand
}

struct CBMCLI {
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
        print("language=\(settings.language.rawValue)")
    }

    private func printUsage() {
        print("""
        cbm commands:
          cbm today --path      Print today's markdown file path (default)
          cbm today --print     Print today's markdown file content
          cbm status            Print current settings snapshot
          cbm help              Show this message
        """)
    }
}

do {
    let cli = CBMCLI()
    try cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch CLIError.unknownCommand {
    fputs("Unknown command. Use 'cbm help'.\n", stderr)
    exit(2)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
