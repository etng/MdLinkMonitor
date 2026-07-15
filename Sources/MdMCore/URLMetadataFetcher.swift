import Foundation
import Dispatch

public struct PageLinkMetadata: Equatable, Sendable {
    public let title: String
    public let summary: String?

    public init(title: String, summary: String? = nil) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSummary = summary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = normalizedSummary?.isEmpty == true ? nil : normalizedSummary
    }

    public static func fallback(for url: URL) -> PageLinkMetadata {
        PageLinkMetadata(title: PageMetadataHTMLParser.fallbackTitle(for: url))
    }
}

public protocol LinkMetadataFetching: Sendable {
    func fetchMetadata(for url: URL) -> PageLinkMetadata?
}

public struct HTTPLinkMetadataFetcher: LinkMetadataFetching {
    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 4.0) {
        self.timeout = timeout
    }

    public func fetchMetadata(for url: URL) -> PageLinkMetadata? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("MdMonitor/1.0", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = FetchResultBox()

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard error == nil, let data else {
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }

            resultBox.value = PageMetadataHTMLParser.parse(data: data, for: url)
        }

        task.resume()

        let deadline = DispatchTime.now() + timeout + 0.5
        if semaphore.wait(timeout: deadline) == .timedOut {
            task.cancel()
        }

        return resultBox.value
    }
}

private final class FetchResultBox: @unchecked Sendable {
    var value: PageLinkMetadata?
}

private enum PageMetadataHTMLParser {
    private static let metaTagRegex = try! NSRegularExpression(pattern: "(?is)<meta\\b[^>]*>")
    private static let titleRegex = try! NSRegularExpression(pattern: "(?is)<title\\b[^>]*>(.*?)</title>")
    private static let attributeRegex = try! NSRegularExpression(
        pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*("([^"]*)"|'([^']*)')"#
    )

    static func parse(data: Data, for url: URL) -> PageLinkMetadata? {
        let html = String(decoding: data, as: UTF8.self)

        var title = metaContent(in: html, key: "property", value: "og:title")
            ?? metaContent(in: html, key: "name", value: "og:title")
            ?? titleTagContent(in: html)
        let summary = metaContent(in: html, key: "property", value: "og:description")
            ?? metaContent(in: html, key: "name", value: "og:description")
            ?? metaContent(in: html, key: "name", value: "description")

        title = normalizeTitle(title, host: url.host?.lowercased())
        let normalizedSummary = normalizeSummary(summary)

        if let title, !title.isEmpty {
            return PageLinkMetadata(title: title, summary: normalizedSummary)
        }

        return PageLinkMetadata(title: fallbackTitle(for: url), summary: normalizedSummary)
    }

    static func fallbackTitle(for url: URL) -> String {
        let segments = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { prettifyURLPathSegment(String($0)) }

        if let preferred = segments.last(where: { !$0.isEmpty && !looksLikeOpaqueIdentifier($0) }) {
            return preferred
        }

        if let host = url.host?.lowercased(), !host.isEmpty {
            return host
        }

        return url.absoluteString
    }

    private static func metaContent(in html: String, key: String, value: String) -> String? {
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in metaTagRegex.matches(in: html, range: nsRange) {
            guard let range = Range(match.range, in: html) else {
                continue
            }

            let tag = String(html[range])
            let attributes = parseAttributes(in: tag)
            guard attributes[key] == value else {
                continue
            }

            if let content = attributes["content"] {
                let normalized = normalizeInlineText(content)
                if !normalized.isEmpty {
                    return normalized
                }
            }
        }
        return nil
    }

    private static func titleTagContent(in html: String) -> String? {
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard
            let match = titleRegex.firstMatch(in: html, range: nsRange),
            let range = Range(match.range(at: 1), in: html)
        else {
            return nil
        }
        let title = normalizeInlineText(String(html[range]))
        return title.isEmpty ? nil : title
    }

    private static func parseAttributes(in tag: String) -> [String: String] {
        let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        var attributes: [String: String] = [:]

        for match in attributeRegex.matches(in: tag, range: nsRange) {
            guard
                let keyRange = Range(match.range(at: 1), in: tag),
                let valueRange = Range(match.range(at: 3), in: tag) ?? Range(match.range(at: 4), in: tag)
            else {
                continue
            }

            let key = String(tag[keyRange]).lowercased()
            let value = String(tag[valueRange])
            attributes[key] = value
        }

        return attributes
    }

    private static func normalizeTitle(_ value: String?, host: String?) -> String? {
        guard let value else {
            return nil
        }

        var normalized = normalizeInlineText(value)
        guard !normalized.isEmpty else {
            return nil
        }

        if host == "chromewebstore.google.com" {
            normalized = normalized
                .replacingOccurrences(of: " - Chrome Web Store", with: "")
                .replacingOccurrences(of: " | Chrome Web Store", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizeSummary(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = normalizeInlineText(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizeInlineText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func prettifyURLPathSegment(_ raw: String) -> String {
        let decoded = raw.removingPercentEncoding ?? raw
        return normalizeInlineText(
            decoded
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        )
    }

    private static func looksLikeOpaqueIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 24 else {
            return false
        }

        let dash = "-".unicodeScalars.first!
        let underscore = "_".unicodeScalars.first!
        return trimmed.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == dash || $0 == underscore
        }
    }
}
