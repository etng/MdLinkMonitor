import Foundation

public enum AppRuntimeFlavor: Sendable {
    case production
    case development
}

public enum AppRuntimeIdentity {
    public static let productionAppName = "MdMonitor"
    public static let developmentAppName = "MdMonitorDev"
    public static let productionBundleIdentifier = "com.y10n.mdmonitor"
    public static let developmentBundleIdentifier = "com.y10n.mdmonitor.dev"
    public static let productionCommandName = "mdm"
    public static let developmentCommandName = "mdmdev"

    public static var currentFlavor: AppRuntimeFlavor {
        flavor(executablePath: CommandLine.arguments[0])
    }

    public static var currentAppName: String {
        appName(for: currentFlavor)
    }

    public static var currentBundleIdentifier: String {
        bundleIdentifier(for: currentFlavor)
    }

    public static var currentCommandName: String {
        commandName(for: currentFlavor)
    }

    public static var currentDefaultsSuiteName: String {
        defaultsSuiteName(for: currentFlavor)
    }

    public static func currentUserDefaults() -> UserDefaults {
        UserDefaults(suiteName: currentDefaultsSuiteName) ?? .standard
    }

    public static func flavor(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        executablePath: String
    ) -> AppRuntimeFlavor {
        let resolvedBundleIdentifier = resolvedBundleIdentifier(
            bundleIdentifier: bundleIdentifier,
            executablePath: executablePath
        )

        switch resolvedBundleIdentifier {
        case developmentBundleIdentifier:
            return .development
        case productionBundleIdentifier:
            return .production
        default:
            let executableName = URL(filePath: normalizedPath(executablePath))
                .lastPathComponent
                .lowercased()
            if executableName == developmentCommandName || executableName == developmentAppName.lowercased() {
                return .development
            }
            return .production
        }
    }

    public static func appName(for flavor: AppRuntimeFlavor) -> String {
        switch flavor {
        case .production:
            return productionAppName
        case .development:
            return developmentAppName
        }
    }

    public static func bundleIdentifier(for flavor: AppRuntimeFlavor) -> String {
        switch flavor {
        case .production:
            return productionBundleIdentifier
        case .development:
            return developmentBundleIdentifier
        }
    }

    public static func commandName(for flavor: AppRuntimeFlavor) -> String {
        switch flavor {
        case .production:
            return productionCommandName
        case .development:
            return developmentCommandName
        }
    }

    public static func defaultsSuiteName(for flavor: AppRuntimeFlavor) -> String {
        bundleIdentifier(for: flavor)
    }

    private static func resolvedBundleIdentifier(
        bundleIdentifier: String?,
        executablePath: String
    ) -> String? {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        let executableURL = URL(filePath: normalizedPath(executablePath)).standardizedFileURL
        guard let bundleURL = enclosingAppBundleURL(for: executableURL),
              let bundle = Bundle(url: bundleURL),
              let resolved = bundle.bundleIdentifier,
              !resolved.isEmpty else {
            return nil
        }
        return resolved
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

    private static func normalizedPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
