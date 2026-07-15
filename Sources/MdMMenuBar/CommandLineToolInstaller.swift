import Foundation
import MdMCore

enum CommandLineToolInstallResult {
    case installed(linkPath: String, requiredAdmin: Bool)
    case cancelled
    case failed(reason: String)
}

enum CommandLineToolInstaller {
    static var executableName: String {
        AppRuntimeIdentity.currentCommandName
    }

    static var installLinkPath: String {
        "/usr/local/bin/\(executableName)"
    }

    static func isInstalled(linkPath: String = installLinkPath) -> Bool {
        SystemIntegrationGuard.isCurrentBundledToolInstalled(
            toolName: executableName,
            linkPath: linkPath
        )
    }

    static func resolveBundledExecutablePath() -> Result<String, SystemIntegrationGuard.FailureReason> {
        SystemIntegrationGuard.commandLineToolInstallResolution(toolName: executableName)
    }

    static func install(executablePath: String, linkPath: String = installLinkPath) -> CommandLineToolInstallResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: executablePath) else {
            return .failed(reason: "Executable not found: \(executablePath)")
        }

        let shellCommand = buildInstallCommand(executablePath: executablePath, linkPath: linkPath)
        let direct = runShell(command: shellCommand)
        if direct.status == 0 {
            return .installed(linkPath: linkPath, requiredAdmin: false)
        }

        let privileged = runPrivilegedShell(command: shellCommand)
        if privileged.status == 0 {
            return .installed(linkPath: linkPath, requiredAdmin: true)
        }

        let detail = "\(privileged.stderr)\n\(privileged.stdout)"
        if detail.localizedCaseInsensitiveContains("user canceled") ||
            detail.localizedCaseInsensitiveContains("user cancelled") ||
            detail.localizedCaseInsensitiveContains("(-128)") {
            return .cancelled
        }
        return .failed(reason: detail.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func buildInstallCommand(executablePath: String, linkPath: String) -> String {
        let source = singleQuoted(executablePath)
        let link = singleQuoted(linkPath)
        return """
        mkdir -p /usr/local/bin && \
        chmod +x \(source) && \
        ln -sf \(source) \(link)
        """
    }

    private static func runShell(command: String) -> (status: Int32, stdout: String, stderr: String) {
        runProcess(
            launchPath: "/bin/zsh",
            arguments: ["-lc", command]
        )
    }

    private static func runPrivilegedShell(command: String) -> (status: Int32, stdout: String, stderr: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return runProcess(
            launchPath: "/usr/bin/osascript",
            arguments: ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        )
    }

    private static func runProcess(launchPath: String, arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (status: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private static func singleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
