import Foundation

public struct StoredMarkdownTaskLine: Equatable, Sendable {
    public let label: String
    public let url: String
    public let annotation: String?
    public let isChecked: Bool
    public let rawLine: String

    public init(label: String, url: String, annotation: String?, isChecked: Bool, rawLine: String) {
        self.label = label
        self.url = url
        self.annotation = annotation
        self.isChecked = isChecked
        self.rawLine = rawLine
    }

    public var host: String? {
        URLComponents(string: url)?.host?.lowercased()
    }

    public var domainSortKey: (registrableDomain: String, fullHost: String) {
        DomainSortKey.make(for: host ?? "")
    }
}

public enum MarkdownTaskLineParser {
    private static let pattern = #"^\s*\* \[([ xX])\] \[([^\]]+)\]\(([^)]+)\)(?: - (.+))?\s*$"#

    public static func parse(line: String) -> StoredMarkdownTaskLine? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let statusRange = Range(match.range(at: 1), in: line),
              let labelRange = Range(match.range(at: 2), in: line),
              let urlRange = Range(match.range(at: 3), in: line)
        else {
            return nil
        }

        let status = String(line[statusRange])
        let label = String(line[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawURL = String(line[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !label.isEmpty,
            let url = AbsoluteWebURL.normalize(rawURL)
        else {
            return nil
        }

        let annotation: String?
        if match.numberOfRanges > 4, let annotationRange = Range(match.range(at: 4), in: line) {
            let value = String(line[annotationRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            annotation = value.isEmpty ? nil : value
        } else {
            annotation = nil
        }

        return StoredMarkdownTaskLine(
            label: label,
            url: url,
            annotation: annotation,
            isChecked: status.lowercased() == "x",
            rawLine: line
        )
    }
}
