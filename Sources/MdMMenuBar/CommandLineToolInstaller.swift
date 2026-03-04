import Foundation

enum CommandLineToolInstallResult {
    case installed(linkPath: String, requiredAdmin: Bool)
    case cancelled
    case failed(reason: String)
}

enum CommandLineToolInstaller {
    static let executableName = "mdm"
    static let installLinkPath = "/usr/local/bin/mdm"

    static func isInstalled(linkPath: String = installLinkPath) -> Bool {
        let path = NSString(string: linkPath).expandingTildeInPath
        return FileManager.default.isExecutableFile(atPath: path)
    }

    static func findBundledExecutablePath() -> String? {
        let fileManager = FileManager.default
        let executableDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(executableName),
            executableDir.appendingPathComponent(executableName),
            cwd.appendingPathComponent(".build/release/\(executableName)"),
            cwd.appendingPathComponent(".build/debug/\(executableName)"),
            cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/\(executableName)"),
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if fileManager.isReadableFile(atPath: candidate.path(percentEncoded: false)) {
                return candidate.path(percentEncoded: false)
            }
        }
        return nil
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
