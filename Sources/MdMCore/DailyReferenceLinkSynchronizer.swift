import Foundation

public struct DailyReferenceLinkSyncResult: Equatable, Sendable {
    public let processedFiles: Int
    public let updatedFiles: Int
    public let skippedFiles: Int
    public let keptLinks: Int
    public let appendedLinks: Int

    public init(
        processedFiles: Int,
        updatedFiles: Int,
        skippedFiles: Int,
        keptLinks: Int,
        appendedLinks: Int
    ) {
        self.processedFiles = processedFiles
        self.updatedFiles = updatedFiles
        self.skippedFiles = skippedFiles
        self.keptLinks = keptLinks
        self.appendedLinks = appendedLinks
    }
}

public struct DailyReferenceLinkSynchronizer {
    private let cbmDirectoryURL: URL
    private let dailyRootDirectoryURL: URL
    private let referenceSectionHeading: String
    private let fileManager: FileManager
    private let calendar: Calendar

    public init(
        cbmDirectoryPath: String,
        dailyRootDirectoryPath: String,
        referenceSectionHeading: String = AppSettings.defaultDailyReferenceSectionHeading,
        fileManager: FileManager = .default,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.cbmDirectoryURL = Self.expandTilde(path: cbmDirectoryPath)
        self.dailyRootDirectoryURL = Self.expandTilde(path: dailyRootDirectoryPath)
        self.referenceSectionHeading = AppSettings.normalizeDailyReferenceSectionHeading(referenceSectionHeading)
        self.fileManager = fileManager
        self.calendar = calendar
    }

    public func sync(through throughDate: Date) throws -> DailyReferenceLinkSyncResult {
        guard fileManager.fileExists(atPath: cbmDirectoryURL.path(percentEncoded: false)) else {
            return DailyReferenceLinkSyncResult(processedFiles: 0, updatedFiles: 0, skippedFiles: 0, keptLinks: 0, appendedLinks: 0)
        }

        let throughYMD = Self.ymdFormatter.string(from: throughDate)
        let sourceFiles = try fileManager.contentsOfDirectory(
            at: cbmDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
            .filter { url in
                guard let ymd = Self.parseSourceYMD(from: url.lastPathComponent) else {
                    return false
                }
                return ymd <= throughYMD
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var processedFiles = 0
        var updatedFiles = 0
        var skippedFiles = 0
        var keptLinks = 0
        var appendedLinks = 0

        for sourceFileURL in sourceFiles {
            guard let ymd = Self.parseSourceYMD(from: sourceFileURL.lastPathComponent) else {
                continue
            }

            let targetFileURL = dailyFileURL(forYMD: ymd)
            guard fileManager.fileExists(atPath: targetFileURL.path(percentEncoded: false)) else {
                skippedFiles += 1
                continue
            }

            let sourceLines = try String(contentsOf: sourceFileURL, encoding: .utf8).components(separatedBy: .newlines)
            let targetLines = try String(contentsOf: targetFileURL, encoding: .utf8).components(separatedBy: .newlines)

            guard let sectionRange = Self.referenceSectionRange(in: targetLines, heading: referenceSectionHeading) else {
                skippedFiles += 1
                continue
            }

            processedFiles += 1

            let existingSectionLines = Array(targetLines[(sectionRange.lowerBound + 1)..<sectionRange.upperBound])
            let classifiedExisting = Self.classifySectionLines(existingSectionLines)
            let preservedExisting = classifiedExisting.tasks
            let preservedOtherContent = classifiedExisting.otherLines
            let hasInvalidExisting = classifiedExisting.hadInvalidOrGarbage

            var existingKeys = Set(preservedExisting.map(\.normalizedKey))
            var mergedLines = preservedExisting.map(\.renderedLine)
            var appendedForFile = 0

            for item in Self.extractValidTaskLines(from: sourceLines, preserveExistingFormatting: false) {
                guard !existingKeys.contains(item.normalizedKey) else {
                    continue
                }
                mergedLines.append(item.renderedLine)
                existingKeys.insert(item.normalizedKey)
                appendedForFile += 1
            }

            keptLinks += preservedExisting.count
            appendedLinks += appendedForFile

            guard appendedForFile > 0 || hasInvalidExisting else {
                continue
            }

            var rewritten = Array(targetLines[..<sectionRange.lowerBound])
            rewritten.append(referenceSectionHeading)
            rewritten.append(contentsOf: mergedLines)
            if !mergedLines.isEmpty, !preservedOtherContent.isEmpty {
                rewritten.append("")
            }
            rewritten.append(contentsOf: preservedOtherContent)
            rewritten.append(contentsOf: targetLines[sectionRange.upperBound...])

            let output = rewritten.joined(separator: "\n")
            try output.write(to: targetFileURL, atomically: true, encoding: .utf8)
            updatedFiles += 1
        }

        return DailyReferenceLinkSyncResult(
            processedFiles: processedFiles,
            updatedFiles: updatedFiles,
            skippedFiles: skippedFiles,
            keptLinks: keptLinks,
            appendedLinks: appendedLinks
        )
    }

    public static func defaultDailyRootDirectoryPath(
        attachmentResourceDirectoryPath: String = AppSettings.defaultAttachmentResourceDirectoryPath
    ) -> String {
        let resourceURL = expandTilde(path: attachmentResourceDirectoryPath)
        let vaultRoot = resourceURL.deletingLastPathComponent()
        return vaultRoot.appendingPathComponent("daily", isDirectory: true).path(percentEncoded: false)
    }

    private func dailyFileURL(forYMD ymd: String) -> URL {
        let yymm = String(ymd.dropFirst(2).prefix(4))
        let yymmdd = String(ymd.dropFirst(2))
        return dailyRootDirectoryURL
            .appendingPathComponent(yymm, isDirectory: true)
            .appendingPathComponent("daily_\(yymmdd).md")
    }

    private static func parseSourceYMD(from fileName: String) -> String? {
        guard fileName.hasPrefix("links_"), fileName.hasSuffix(".md") else {
            return nil
        }
        let body = fileName.dropFirst("links_".count).dropLast(".md".count)
        let ymd = String(body)
        guard ymd.count == 8, ymd.allSatisfy(\.isNumber) else {
            return nil
        }
        return ymd
    }

    private static func referenceSectionRange(in lines: [String], heading: String) -> Range<Int>? {
        let normalizedHeading = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedHeading }) else {
            return nil
        }

        let startLevel = markdownHeadingLevel(for: lines[start])
        let end = lines[(start + 1)...].firstIndex { line in
            guard let level = markdownHeadingLevel(for: line) else {
                return false
            }
            guard let startLevel else {
                return level <= 2
            }
            return level <= startLevel
        } ?? lines.endIndex
        return start..<end
    }

    private static func extractValidTaskLines(from lines: [String], preserveExistingFormatting: Bool) -> [ReferenceTaskLine] {
        lines.compactMap { parseValidTaskLine(from: $0, preserveExistingFormatting: preserveExistingFormatting) }
            .filter { !$0.isGarbage }
    }

    private static func classifySectionLines(_ lines: [String]) -> ClassifiedSectionLines {
        var tasks: [ReferenceTaskLine] = []
        var otherLines: [String] = []
        var hadInvalidOrGarbage = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                otherLines.append(line)
                continue
            }

            if let item = parseValidTaskLine(from: line, preserveExistingFormatting: true) {
                if item.isGarbage {
                    hadInvalidOrGarbage = true
                    continue
                }
                tasks.append(item)
                continue
            }

            if trimmed.hasPrefix("* [") {
                hadInvalidOrGarbage = true
                continue
            }

            otherLines.append(line)
        }

        while otherLines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            otherLines.removeFirst()
        }
        while otherLines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            otherLines.removeLast()
        }

        return ClassifiedSectionLines(tasks: tasks, otherLines: otherLines, hadInvalidOrGarbage: hadInvalidOrGarbage)
    }

    private static func parseValidTaskLine(from line: String, preserveExistingFormatting: Bool = false) -> ReferenceTaskLine? {
        guard let parsed = MarkdownTaskLineParser.parse(line: line) else {
            return nil
        }
        return ReferenceTaskLine(parsed: parsed, preserveExistingFormatting: preserveExistingFormatting)
    }

    private static func markdownHeadingLevel(for line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else {
            return nil
        }

        let hashes = trimmed.prefix(while: { $0 == "#" })
        let level = hashes.count
        guard (1...6).contains(level) else {
            return nil
        }

        let remainder = trimmed.dropFirst(level)
        guard remainder.first?.isWhitespace == true else {
            return nil
        }
        return level
    }

    private static func expandTilde(path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(filePath: expanded, directoryHint: .isDirectory)
    }

    private static let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

private struct ReferenceTaskLine: Sendable {
    let label: String
    let url: String
    let annotation: String?
    let isChecked: Bool
    let rawLine: String
    let preserveExistingFormatting: Bool

    init(parsed: StoredMarkdownTaskLine, preserveExistingFormatting: Bool) {
        self.label = parsed.label
        self.url = parsed.url
        self.annotation = parsed.annotation
        self.isChecked = parsed.isChecked
        self.rawLine = parsed.rawLine
        self.preserveExistingFormatting = preserveExistingFormatting
    }

    var normalizedKey: String {
        URLNormalizer.normalizedURLForDedup(url)
    }

    var renderedLine: String {
        if preserveExistingFormatting {
            return rawLine
        }
        if isChecked {
            let base = "* [x] [\(label)](\(url))"
            guard
                let annotation,
                !annotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return base
            }

            let normalizedAnnotation = annotation
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return normalizedAnnotation.isEmpty ? base : "\(base) - \(normalizedAnnotation)"
        }
        return MarkdownTaskLineBuilder.makeLine(label: label, repositoryURL: url, annotation: annotation)
    }

    var isGarbage: Bool {
        if url.hasSuffix("/analytics") {
            return true
        }
        if informationalCharacterCount == 0 {
            return true
        }
        return false
    }

    private var informationalCharacterCount: Int {
        label.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }.count
    }
}

private struct ClassifiedSectionLines: Sendable {
    let tasks: [ReferenceTaskLine]
    let otherLines: [String]
    let hadInvalidOrGarbage: Bool
}
