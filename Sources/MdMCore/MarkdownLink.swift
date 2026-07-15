import Foundation

public struct MarkdownLink: Equatable, Sendable {
    public let label: String
    public let url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public enum AbsoluteWebURL {
    public static func normalize(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            var components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            let host = components.host?.lowercased(),
            !host.isEmpty,
            scheme == "https" || scheme == "http"
        else {
            return nil
        }

        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { !$0.name.lowercased().hasPrefix("utm_") }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        return components.url?.absoluteString
    }
}

public enum MarkdownLinkExtractor {
    private static let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#

    public static func extract(from text: String) -> [MarkdownLink] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsrange)

        return matches.compactMap { match in
            guard
                let labelRange = Range(match.range(at: 1), in: text),
                let urlRange = Range(match.range(at: 2), in: text)
            else {
                return nil
            }
            let label = String(text[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawURL = String(text[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !label.isEmpty,
                let url = AbsoluteWebURL.normalize(rawURL)
            else {
                return nil
            }
            return MarkdownLink(label: label, url: url)
        }
    }
}
