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
    private final class LoggerBox: @unchecked Sendable {
        let logger: (any Logging)?

        init(_ logger: (any Logging)?) {
            self.logger = logger
        }
    }

    private struct BackgroundLogCapture {
        let stdoutURL: URL
        let stderrURL: URL
        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle
    }

    private enum CloneExecutionError: Error {
        case prepareDirectoryFailed(String)
        case prepareLogCaptureFailed(String)

        var message: String {
            switch self {
            case .prepareDirectoryFailed(let value): return value
            case .prepareLogCaptureFailed(let value): return value
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
        logCommandOutput(repository: repository, standardOutput: result.standardOutput, standardError: result.standardError)

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

        let logCapture: BackgroundLogCapture
        do {
            logCapture = try prepareBackgroundLogCapture(for: repository)
        } catch let error as CloneExecutionError {
            let message = error.message
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        } catch {
            let message = error.localizedDescription
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        }
        process.standardOutput = logCapture.stdoutHandle
        process.standardError = logCapture.stderrHandle

        do {
            try process.run()
            logger?.log(.info, "Clone launched in background: \(repository.canonicalURL) pid=\(process.processIdentifier)")
            finalizeBackgroundCloneLogging(
                process: process,
                repository: repository,
                stdoutURL: logCapture.stdoutURL,
                stderrURL: logCapture.stderrURL,
                stdoutHandle: logCapture.stdoutHandle,
                stderrHandle: logCapture.stderrHandle
            )
            return CommandExecutionResult(exitCode: 0, standardOutput: "launched", standardError: "")
        } catch {
            let message = error.localizedDescription
            closeAndCleanup(logCapture: logCapture)
            logger?.log(.error, "Clone launch failed: \(repository.canonicalURL) \(message)")
            return CommandExecutionResult(exitCode: -1, standardOutput: "", standardError: message)
        }
    }

    private func prepareBackgroundLogCapture(for repository: GitRepository) throws -> BackgroundLogCapture {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdmonitor-clone", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw CloneExecutionError.prepareLogCaptureFailed(
                "Failed to prepare clone log temp directory for \(repository.canonicalURL): \(error.localizedDescription)"
            )
        }

        let uuid = UUID().uuidString
        let stdoutURL = dir.appendingPathComponent("\(uuid).stdout.log")
        let stderrURL = dir.appendingPathComponent("\(uuid).stderr.log")

        FileManager.default.createFile(atPath: stdoutURL.path(percentEncoded: false), contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path(percentEncoded: false), contents: nil)

        do {
            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            return BackgroundLogCapture(
                stdoutURL: stdoutURL,
                stderrURL: stderrURL,
                stdoutHandle: stdoutHandle,
                stderrHandle: stderrHandle
            )
        } catch {
            throw CloneExecutionError.prepareLogCaptureFailed(
                "Failed to open clone output file for \(repository.canonicalURL): \(error.localizedDescription)"
            )
        }
    }

    private func finalizeBackgroundCloneLogging(
        process: Process,
        repository: GitRepository,
        stdoutURL: URL,
        stderrURL: URL,
        stdoutHandle: FileHandle,
        stderrHandle: FileHandle
    ) {
        let loggerBox = LoggerBox(self.logger)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            try? stdoutHandle.close()
            try? stderrHandle.close()

            let stdout = Self.readText(from: stdoutURL)
            let stderr = Self.readText(from: stderrURL)
            Self.logOutput(
                logger: loggerBox.logger,
                repository: repository,
                standardOutput: stdout,
                standardError: stderr
            )

            if process.terminationStatus == 0 {
                loggerBox.logger?.log(.info, "Clone success: \(repository.canonicalURL)")
            } else {
                loggerBox.logger?.log(.error, "Clone failed(\(process.terminationStatus)): \(repository.canonicalURL)")
            }

            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }
    }

    private func closeAndCleanup(logCapture: BackgroundLogCapture) {
        try? logCapture.stdoutHandle.close()
        try? logCapture.stderrHandle.close()
        try? FileManager.default.removeItem(at: logCapture.stdoutURL)
        try? FileManager.default.removeItem(at: logCapture.stderrURL)
    }

    private func logCommandOutput(repository: GitRepository, standardOutput: String, standardError: String) {
        Self.logOutput(logger: logger, repository: repository, standardOutput: standardOutput, standardError: standardError)
    }

    private static func logOutput(
        logger: (any Logging)?,
        repository: GitRepository,
        standardOutput: String,
        standardError: String
    ) {
        if !standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logLines(
                logger: logger,
                level: .info,
                prefix: "Clone stdout: \(repository.canonicalURL)",
                content: standardOutput
            )
        }

        if !standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logLines(
                logger: logger,
                level: .error,
                prefix: "Clone stderr: \(repository.canonicalURL)",
                content: standardError
            )
        }
    }

    private static func logLines(logger: (any Logging)?, level: LogLevel, prefix: String, content: String) {
        content.split(whereSeparator: \.isNewline).forEach { line in
            logger?.log(level, "\(prefix) \(line)")
        }
    }

    private static func readText(from url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
