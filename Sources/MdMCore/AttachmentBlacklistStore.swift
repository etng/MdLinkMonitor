import Foundation

public struct AttachmentBlacklistEntry: Equatable, Sendable {
    public let sourceURL: String
    public let md5: String
    public let addedAt: Date
    public let note: String?

    public init(sourceURL: String, md5: String, addedAt: Date, note: String? = nil) {
        self.sourceURL = sourceURL
        self.md5 = md5
        self.addedAt = addedAt
        self.note = note
    }
}

public struct AttachmentBlacklistStore: @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(baseDirectoryPath: String, fileManager: FileManager = .default) {
        let baseURL = URL(filePath: NSString(string: baseDirectoryPath).expandingTildeInPath, directoryHint: .isDirectory)
        self.fileURL = baseURL.appendingPathComponent("blacklist.yaml")
        self.fileManager = fileManager
    }

    public func load() -> [AttachmentBlacklistEntry] {
        guard
            fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)),
            let content = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            return []
        }

        return parse(content: content)
    }

    public func contains(sourceURL: String) -> Bool {
        let normalized = AbsoluteWebURL.normalize(sourceURL) ?? sourceURL
        return load().contains { $0.sourceURL == normalized }
    }

    public func add(entry: AttachmentBlacklistEntry) throws {
        let normalizedURL = AbsoluteWebURL.normalize(entry.sourceURL) ?? entry.sourceURL
        var entries = load()
        guard !entries.contains(where: { $0.sourceURL == normalizedURL }) else {
            return
        }

        entries.append(
            AttachmentBlacklistEntry(
                sourceURL: normalizedURL,
                md5: entry.md5,
                addedAt: entry.addedAt,
                note: entry.note
            )
        )
        try write(entries: entries)
    }

    private func write(entries: [AttachmentBlacklistEntry]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let output = makeYAML(entries: entries)
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func makeYAML(entries: [AttachmentBlacklistEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["entries:"]
        for entry in entries.sorted(by: { $0.addedAt > $1.addedAt }) {
            lines.append("  - source_url: \"\(escape(entry.sourceURL))\"")
            lines.append("    md5: \"\(escape(entry.md5))\"")
            lines.append("    added_at: \"\(formatter.string(from: entry.addedAt))\"")
            if let note = entry.note, !note.isEmpty {
                lines.append("    note: \"\(escape(note))\"")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func parse(content: String) -> [AttachmentBlacklistEntry] {
        let formatter = ISO8601DateFormatter()
        let lines = content.split(whereSeparator: \.isNewline).map(String.init)
        var entries: [AttachmentBlacklistEntry] = []
        var current: [String: String] = [:]

        func flush() {
            guard
                let sourceURL = current["source_url"],
                let md5 = current["md5"],
                let addedAtRaw = current["added_at"],
                let addedAt = formatter.date(from: addedAtRaw)
            else {
                current = [:]
                return
            }
            entries.append(
                AttachmentBlacklistEntry(
                    sourceURL: sourceURL,
                    md5: md5,
                    addedAt: addedAt,
                    note: current["note"]
                )
            )
            current = [:]
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- ") {
                flush()
                parseField(from: String(line.dropFirst(2)), into: &current)
            } else if line.contains(":") {
                parseField(from: line, into: &current)
            }
        }

        flush()
        return entries
    }

    private func parseField(from line: String, into values: inout [String: String]) {
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = unescape(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        values[key] = value
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func unescape(_ value: String) -> String {
        var trimmed = value
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
