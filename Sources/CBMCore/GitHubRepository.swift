import Foundation

public struct GitRepository: Equatable, Hashable, Sendable {
    public let host: String
    public let owner: String
    public let name: String

    public init(host: String = "github.com", owner: String, name: String) {
        self.host = host
        self.owner = owner
        self.name = name
    }

    public var canonicalURL: String {
        "https://\(host)/\(owner)/\(name)"
    }

    public var cloneURL: String {
        "\(canonicalURL).git"
    }

    public var dailyDedupKey: String {
        "\(host.lowercased())/\(owner.lowercased())/\(name.lowercased())"
    }
}

public typealias GitHubRepository = GitRepository

public enum URLNormalizer {
    public static func normalizedURLForDedup(_ rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            return trimmed
        }

        components.query = nil
        components.fragment = nil
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        var path = components.path.isEmpty ? "" : components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path

        return components.url?.absoluteString ?? trimmed
    }
}

public enum GitRepositoryParser {
    public static func parse(from rawURL: String, allowedDomains: Set<String>) -> GitRepository? {
        guard var components = URLComponents(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        components.query = nil
        components.fragment = nil

        guard
            let scheme = components.scheme?.lowercased(),
            scheme == "https",
            let host = components.host?.lowercased(),
            allowedDomains.contains(host)
        else {
            return nil
        }

        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard pathParts.count == 2 else {
            return nil
        }

        let owner = pathParts[0]
        var repo = pathParts[1]
        if repo.lowercased().hasSuffix(".git") {
            repo = String(repo.dropLast(4))
        }

        guard isValidSegment(owner), isValidSegment(repo) else {
            return nil
        }

        return GitRepository(host: host, owner: owner, name: repo)
    }

    private static func isValidSegment(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

public enum GitHubRepositoryParser {
    public static func parse(from rawURL: String) -> GitRepository? {
        GitRepositoryParser.parse(from: rawURL, allowedDomains: ["github.com"])
    }
}

public enum MarkdownTaskLineBuilder {
    public static func makeLine(label: String, repositoryURL: String) -> String {
        "* [ ] [\(label)](\(repositoryURL))"
    }
}
