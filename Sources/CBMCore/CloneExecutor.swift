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
    private let commandRunner: any CommandRunning
    private let logger: (any Logging)?

    public init(commandRunner: any CommandRunning = ProcessCommandRunner(), logger: (any Logging)? = nil) {
        self.commandRunner = commandRunner
        self.logger = logger
    }

    public func clone(repository: GitHubRepository) -> CommandExecutionResult {
        let cloneURL = repository.cloneURL
        logger?.log(.info, "Start clone: \(cloneURL)")

        let result = commandRunner.run(command: "/usr/bin/env", arguments: ["git", "c1", cloneURL])

        if result.isSuccess {
            logger?.log(.info, "Clone success: \(cloneURL)")
        } else {
            logger?.log(.error, "Clone failed(\(result.exitCode)): \(cloneURL) \(result.standardError)")
        }

        return result
    }
}
