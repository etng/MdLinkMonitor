import Foundation

public struct RepositoryCapture: Equatable, Sendable {
    public let label: String
    public let repository: GitHubRepository

    public init(label: String, repository: GitHubRepository) {
        self.label = label
        self.repository = repository
    }
}

public enum ClipboardContentProcessor {
    public static func extractRepositoryCaptures(from text: String, allowMultipleLinks: Bool) -> [RepositoryCapture] {
        let links = MarkdownLinkExtractor.extract(from: text)
        guard !links.isEmpty else {
            return []
        }

        if !allowMultipleLinks, links.count != 1 {
            return []
        }

        return links.compactMap { link in
            guard let repository = GitHubRepositoryParser.parse(from: link.url) else {
                return nil
            }
            return RepositoryCapture(label: link.label, repository: repository)
        }
    }
}
