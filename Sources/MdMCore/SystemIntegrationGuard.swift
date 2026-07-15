import Foundation

public enum SystemIntegrationGuard {
    public enum FailureReason: Error, Equatable, Sendable {
        case developmentBuild(executablePath: String)
        case appNotInstalled(appBundlePath: String)
        case standaloneExecutable(executablePath: String)
        case missingBundledTool(appBundlePath: String, toolName: String)
    }

    public static func launchAtLoginFailureReason(
        executablePath: String = CommandLine.arguments[0],
        homeDirectoryPath: String = NSHomeDirectory()
    ) -> FailureReason? {
        switch classifyRuntime(executablePath: executablePath, homeDirectoryPath: homeDirectoryPath) {
        case .installedApp:
            return nil
        case .developmentBuild(let executableURL):
            return .developmentBuild(executablePath: standardizedPath(executableURL))
        case .uninstalledApp(let bundleURL):
            return .appNotInstalled(appBundlePath: standardizedPath(bundleURL))
        case .standaloneExecutable(let executableURL):
            return .standaloneExecutable(executablePath: standardizedPath(executableURL))
        }
    }

    public static func commandLineToolInstallResolution(
        toolName: String,
        executablePath: String = CommandLine.arguments[0],
        homeDirectoryPath: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> Result<String, FailureReason> {
        switch classifyRuntime(executablePath: executablePath, homeDirectoryPath: homeDirectoryPath) {
        case .installedApp(let bundleURL):
            let bundledToolURL = bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent(toolName)
                .standardizedFileURL
            let bundledToolPath = standardizedPath(bundledToolURL)
            guard fileManager.isExecutableFile(atPath: bundledToolPath) else {
                return .failure(.missingBundledTool(appBundlePath: standardizedPath(bundleURL), toolName: toolName))
            }
            return .success(bundledToolPath)
        case .developmentBuild(let executableURL):
            return .failure(.developmentBuild(executablePath: standardizedPath(executableURL)))
        case .uninstalledApp(let bundleURL):
            return .failure(.appNotInstalled(appBundlePath: standardizedPath(bundleURL)))
        case .standaloneExecutable(let executableURL):
            return .failure(.standaloneExecutable(executablePath: standardizedPath(executableURL)))
        }
    }

    public static func isCurrentBundledToolInstalled(
        toolName: String,
        linkPath: String,
        executablePath: String = CommandLine.arguments[0],
        homeDirectoryPath: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> Bool {
        guard case .success(let expectedPath) = commandLineToolInstallResolution(
            toolName: toolName,
            executablePath: executablePath,
            homeDirectoryPath: homeDirectoryPath,
            fileManager: fileManager
        ) else {
            return false
        }

        let normalizedLinkPath = NSString(string: linkPath).expandingTildeInPath
        guard fileManager.isExecutableFile(atPath: normalizedLinkPath) else {
            return false
        }
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: normalizedLinkPath) else {
            return false
        }

        let actualTargetURL: URL
        if destination.hasPrefix("/") {
            actualTargetURL = URL(filePath: destination).standardizedFileURL
        } else {
            let baseURL = URL(filePath: normalizedLinkPath).deletingLastPathComponent()
            actualTargetURL = URL(filePath: destination, relativeTo: baseURL).standardizedFileURL
        }

        return standardizedPath(actualTargetURL) == NSString(string: expectedPath).standardizingPath
    }

    private enum RuntimeClassification {
        case installedApp(bundleURL: URL)
        case uninstalledApp(bundleURL: URL)
        case developmentBuild(executableURL: URL)
        case standaloneExecutable(executableURL: URL)
    }

    private static func classifyRuntime(
        executablePath: String,
        homeDirectoryPath: String
    ) -> RuntimeClassification {
        let normalizedExecutablePath = NSString(string: executablePath).expandingTildeInPath
        let executableURL = URL(filePath: normalizedExecutablePath).standardizedFileURL

        if isDevelopmentBuild(executableURL: executableURL) {
            return .developmentBuild(executableURL: executableURL)
        }

        if let bundleURL = enclosingAppBundleURL(for: executableURL) {
            let standardizedBundleURL = bundleURL.standardizedFileURL
            if isInstalledAppBundle(bundleURL: standardizedBundleURL, homeDirectoryPath: homeDirectoryPath) {
                return .installedApp(bundleURL: standardizedBundleURL)
            }
            return .uninstalledApp(bundleURL: standardizedBundleURL)
        }

        return .standaloneExecutable(executableURL: executableURL)
    }

    private static func isDevelopmentBuild(executableURL: URL) -> Bool {
        let components = executableURL.pathComponents
        return components.contains(".build") || components.contains("DerivedData")
    }

    private static func enclosingAppBundleURL(for executableURL: URL) -> URL? {
        var currentURL = executableURL.deletingLastPathComponent()
        while currentURL.path != "/" {
            if currentURL.pathExtension == "app" {
                return currentURL
            }
            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL == currentURL {
                break
            }
            currentURL = parentURL
        }
        return nil
    }

    private static func isInstalledAppBundle(bundleURL: URL, homeDirectoryPath: String) -> Bool {
        let bundlePath = standardizedPath(bundleURL)
        let normalizedHome = NSString(string: homeDirectoryPath).expandingTildeInPath
        let allowedRoots = [
            standardizedPath(URL(filePath: "/Applications")),
            standardizedPath(URL(filePath: normalizedHome).appendingPathComponent("Applications")),
        ]

        return allowedRoots.contains { root in
            bundlePath == root || bundlePath.hasPrefix(root + "/")
        }
    }

    private static func standardizedPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else {
            return path
        }
        return String(path.dropLast())
    }
}
