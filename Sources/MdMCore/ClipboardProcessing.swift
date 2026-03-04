import Foundation

public struct LinkCapture: Equatable, Sendable {
    public let label: String
    public let url: String
    public let repository: GitRepository?

    public init(label: String, url: String, repository: GitRepository?) {
        self.label = label
        self.url = url
        self.repository = repository
    }

    public var dedupKey: String {
        repository?.dailyDedupKey ?? URLNormalizer.normalizedURLForDedup(url)
    }

    public var markdownURL: String {
        repository?.canonicalURL ?? url
    }
}

public enum ClipboardContentProcessor {
    public static func extractLinkCaptures(
        from text: String,
        allowMultipleLinks: Bool,
        repositoryDomains: Set<String>
    ) -> [LinkCapture] {
        let links = MarkdownLinkExtractor.extract(from: text)
        guard !links.isEmpty else {
            return []
        }

        if !allowMultipleLinks, links.count != 1 {
            return []
        }

        return links.map { link in
            let repository = GitRepositoryParser.parse(from: link.url, allowedDomains: repositoryDomains)
            return LinkCapture(label: link.label, url: link.url, repository: repository)
        }
    }

    // Backward compatible helper used by older tests/callers.
    public static func extractRepositoryCaptures(from text: String, allowMultipleLinks: Bool) -> [RepositoryCapture] {
        let captures = extractLinkCaptures(
            from: text,
            allowMultipleLinks: allowMultipleLinks,
            repositoryDomains: ["github.com"]
        )

        return captures.compactMap { capture in
            guard let repository = capture.repository else {
                return nil
            }
            return RepositoryCapture(label: capture.label, repository: repository)
        }
    }
}

public struct RepositoryCapture: Equatable, Sendable {
    public let label: String
    public let repository: GitRepository

    public init(label: String, repository: GitRepository) {
        self.label = label
        self.repository = repository
    }
}
