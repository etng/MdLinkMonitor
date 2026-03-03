import Foundation

public struct CommandExecutionResult: Equatable, Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var isSuccess: Bool {
        exitCode == 0
    }
}

public protocol CommandRunning {
    func run(command: String, arguments: [String]) -> CommandExecutionResult
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(command: String, arguments: [String]) -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(filePath: command)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandExecutionResult(exitCode: process.terminationStatus, standardOutput: stdout, standardError: stderr)
    }
}

public struct GitC1CloneExecutor {
    private enum CloneExecutionError: Error {
        case prepareDirectoryFailed(String)

        var message: String {
            switch self {
            case .prepareDirectoryFailed(let value): return value
            }
        }
    }

    private let commandRunner: any CommandRunning
    private let logger: (any Logging)?

    public init(commandRunner: any CommandRunning = ProcessCommandRunner(), logger: (any Logging)? = nil) {
        self.commandRunner = commandRunner
        self.logger = logger
    }

    public func clone(
        repository: GitRepository,
        commandTemplate: String = AppSettings.defaultCloneCommandTemplate,
        cloneDirectoryPath: String? = nil
    ) -> CommandExecutionResult {
        let normalizedTemplate = AppSettings.normalizeCloneCommandTemplate(commandTemplate)
        let baseCommandLine = normalizedTemplate.replacingOccurrences(
            of: AppSettings.cloneCommandPlaceholder,
            with: repository.canonicalURL
        )
        let commandLine: String
        do {
            commandLine = try composeCommandLine(baseCommandLine: baseCommandLine, cloneDirectoryPath: cloneDirectoryPath)
        } catch let error as CloneExecutionError {
            let message = error.message
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        } catch {
            let message = error.localizedDescription
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        }

        logger?.log(.info, "Start clone: \(repository.canonicalURL) with cmdline: \(commandLine)")

        if commandRunner is ProcessCommandRunner {
            return launchBackgroundClone(commandLine: commandLine, repository: repository)
        }

        let result = commandRunner.run(command: "/bin/zsh", arguments: ["-lc", commandLine])

        if result.isSuccess {
            logger?.log(.info, "Clone success: \(repository.canonicalURL)")
        } else {
            logger?.log(.error, "Clone failed(\(result.exitCode)): \(repository.canonicalURL) \(result.standardError)")
        }

        return result
    }

    private func composeCommandLine(baseCommandLine: String, cloneDirectoryPath: String?) throws -> String {
        guard let cloneDirectory = normalizedCloneDirectoryPath(cloneDirectoryPath) else {
            return baseCommandLine
        }

        do {
            try FileManager.default.createDirectory(
                at: URL(filePath: cloneDirectory),
                withIntermediateDirectories: true
            )
        } catch {
            throw CloneExecutionError.prepareDirectoryFailed(
                "Failed to prepare clone directory '\(cloneDirectory)': \(error.localizedDescription)"
            )
        }

        let escapedDirectory = shellEscape(cloneDirectory)
        return "cd \(escapedDirectory) && \(baseCommandLine)"
    }

    private func normalizedCloneDirectoryPath(_ path: String?) -> String? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return NSString(string: trimmed).expandingTildeInPath
    }

    private func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func launchBackgroundClone(commandLine: String, repository: GitRepository) -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-lc", commandLine]

        do {
            try process.run()
            logger?.log(.info, "Clone launched in background: \(repository.canonicalURL) pid=\(process.processIdentifier)")
            return CommandExecutionResult(exitCode: 0, standardOutput: "launched", standardError: "")
        } catch {
            let message = error.localizedDescription
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        }
    }
}
