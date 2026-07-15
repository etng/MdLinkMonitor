import Foundation

public enum DomainSortKey {
    private static let compoundPublicSuffixes: Set<String> = [
        "ac.cn", "com.au", "com.cn", "com.hk", "com.tw", "co.jp", "co.kr", "co.nz", "co.uk",
        "edu.cn", "gov.cn", "net.cn", "org.cn", "org.hk", "org.tw"
    ]

    public static func make(for host: String) -> (registrableDomain: String, fullHost: String) {
        let normalized = host.lowercased()
        let parts = normalized.split(separator: ".").map(String.init)
        guard parts.count >= 2 else {
            return (normalized, normalized)
        }

        let suffix2 = parts.suffix(2).joined(separator: ".")
        if parts.count >= 3, compoundPublicSuffixes.contains(suffix2) {
            let registrable = parts.suffix(3).joined(separator: ".")
            return (registrable, normalized)
        }

        let registrable = parts.suffix(2).joined(separator: ".")
        return (registrable, normalized)
    }
}
