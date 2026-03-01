import Foundation

enum AppVersion {
    static var semVer: String {
        let raw = shortVersion
        return isValidSemVer(raw) ? raw : "0.1.0"
    }

    static var shortVersion: String {
        if let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "0.1.0"
    }

    static var buildNumber: String {
        if let value = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "1"
    }

    static var displayVersion: String {
        "\(semVer) (\(buildNumber))"
    }

    private static func isValidSemVer(_ input: String) -> Bool {
        let pattern = #"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"#
        return input.range(of: pattern, options: .regularExpression) != nil
    }
}
