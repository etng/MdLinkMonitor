import Foundation

public struct GitHubRepository: Equatable, Hashable, Sendable {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    public var canonicalURL: String {
        "https://github.com/\(owner)/\(name)"
    }

    public var cloneURL: String {
        "\(canonicalURL).git"
    }

    public var dailyDedupKey: String {
        "\(owner.lowercased())/\(name.lowercased())"
    }
}

public enum GitHubRepositoryParser {
    public static func parse(from rawURL: String) -> GitHubRepository? {
        guard var components = URLComponents(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        components.query = nil
        components.fragment = nil

        guard
            let scheme = components.scheme?.lowercased(),
            scheme == "https",
            let host = components.host?.lowercased(),
            host == "github.com"
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

        return GitHubRepository(owner: owner, name: repo)
    }

    private static func isValidSegment(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

public enum MarkdownTaskLineBuilder {
    public static func makeLine(label: String, repositoryURL: String) -> String {
        "* [ ] [\(label)](\(repositoryURL))"
    }
}
