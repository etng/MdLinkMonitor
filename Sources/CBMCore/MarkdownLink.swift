import Foundation

public struct MarkdownLink: Equatable, Sendable {
    public let label: String
    public let url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
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
            let url = String(text[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, !url.isEmpty else { return nil }
            return MarkdownLink(label: label, url: url)
        }
    }
}
