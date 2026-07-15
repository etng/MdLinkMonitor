import Foundation

public struct AttachmentCapture: Equatable, Sendable {
    public let sourceURL: String
    public let label: String?

    public init(sourceURL: String, label: String? = nil) {
        self.sourceURL = sourceURL
        let normalizedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = normalizedLabel?.isEmpty == true ? nil : normalizedLabel
    }
}

public enum ClipboardCaptureItem: Equatable, Sendable {
    case link(LinkCapture)
    case attachment(AttachmentCapture)
}

public struct LinkCapture: Equatable, Sendable {
    public let label: String
    public let url: String
    public let annotation: String?
    public let repository: GitRepository?

    public init(label: String, url: String, annotation: String? = nil, repository: GitRepository?) {
        self.label = label
        self.url = url
        let normalizedAnnotation = annotation?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.annotation = normalizedAnnotation?.isEmpty == true ? nil : normalizedAnnotation
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
    private static let attachmentHosts: Set<String> = ["mmbiz.qpic.cn"]

    public static func extractCaptures(
        from text: String,
        allowMultipleLinks: Bool,
        repositoryDomains: Set<String>,
        metadataAllowedDomains: Set<String> = [],
        metadataFetcher: any LinkMetadataFetching = HTTPLinkMetadataFetcher()
    ) -> [ClipboardCaptureItem] {
        let links = MarkdownLinkExtractor.extract(from: text)
        if !links.isEmpty {
            if !allowMultipleLinks, links.count != 1 {
                return []
            }

            return links.compactMap { link in
                if isAttachmentURL(link.url) {
                    return .attachment(AttachmentCapture(sourceURL: link.url, label: link.label))
                }

                let repository = GitRepositoryParser.parse(from: link.url, allowedDomains: repositoryDomains)
                return .link(LinkCapture(label: link.label, url: link.url, repository: repository))
            }
        }

        if let rawURL = AbsoluteWebURL.normalize(text), isAttachmentURL(rawURL) {
            return [.attachment(AttachmentCapture(sourceURL: rawURL))]
        }

        if let specialRepositoryCapture = extractSpecialPlainRepositoryCapture(
            from: text,
            repositoryDomains: repositoryDomains
        ) {
            return [specialRepositoryCapture]
        }

        guard let plainURL = extractWhitelistedPlainURL(from: text, allowedDomains: metadataAllowedDomains) else {
            return []
        }

        let urlString = plainURL.absoluteString
        if isAttachmentURL(urlString) {
            return [.attachment(AttachmentCapture(sourceURL: urlString))]
        }

        let metadata = metadataFetcher.fetchMetadata(for: plainURL) ?? PageLinkMetadata.fallback(for: plainURL)
        let repository = GitRepositoryParser.parse(from: urlString, allowedDomains: repositoryDomains)
        return [
            .link(
                LinkCapture(
                    label: metadata.title,
                    url: urlString,
                    annotation: metadata.summary,
                    repository: repository
                )
            )
        ]
    }

    public static func extractSpecialPlainRepositoryCapture(
        from text: String,
        repositoryDomains: Set<String>
    ) -> ClipboardCaptureItem? {
        guard
            let normalizedURL = AbsoluteWebURL.normalize(text),
            let components = URLComponents(string: normalizedURL),
            let scheme = components.scheme?.lowercased(),
            scheme == "https",
            let host = components.host?.lowercased(),
            repositoryDomains.contains(host)
        else {
            return nil
        }

        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard pathParts.count == 2 else { return nil }
        guard pathParts[1].lowercased().hasSuffix(".wiki.git") else { return nil }

        guard let repository = GitRepositoryParser.parse(from: normalizedURL, allowedDomains: repositoryDomains) else {
            return nil
        }

        return .link(
            LinkCapture(
                label: "\(repository.owner)/\(repository.name)",
                url: repository.canonicalURL,
                repository: repository
            )
        )
    }

    public static func extractLinkCaptures(
        from text: String,
        allowMultipleLinks: Bool,
        repositoryDomains: Set<String>,
        metadataAllowedDomains: Set<String> = [],
        metadataFetcher: any LinkMetadataFetching = HTTPLinkMetadataFetcher()
    ) -> [LinkCapture] {
        extractCaptures(
            from: text,
            allowMultipleLinks: allowMultipleLinks,
            repositoryDomains: repositoryDomains,
            metadataAllowedDomains: metadataAllowedDomains,
            metadataFetcher: metadataFetcher
        ).compactMap { item in
            guard case let .link(capture) = item else {
                return nil
            }
            return capture
        }
    }

    public static func isAttachmentURL(_ rawURL: String) -> Bool {
        guard
            let normalized = AbsoluteWebURL.normalize(rawURL),
            let components = URLComponents(string: normalized),
            let host = components.host?.lowercased()
        else {
            return false
        }

        return attachmentHosts.contains(host)
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

    public static func extractWhitelistedPlainURL(from text: String, allowedDomains: Set<String>) -> URL? {
        guard !allowedDomains.isEmpty else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else {
            return nil
        }

        guard
            let normalizedURL = AbsoluteWebURL.normalize(trimmed),
            let components = URLComponents(string: normalizedURL),
            let host = components.host?.lowercased(),
            allowedDomains.contains(host) || allowedDomains.contains(where: { host.hasSuffix(".\($0)") })
        else {
            return nil
        }

        return components.url
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
