import Foundation

public struct DailyLinkSearchRecord: Equatable, Sendable, Identifiable {
    public let title: String
    public let url: String
    public let normalizedURL: String
    public let date: Date
    public let ymd: String
    public let markdownFilePath: String
    public let logFilePath: String
    public let ordinal: Int

    public init(
        title: String,
        url: String,
        normalizedURL: String,
        date: Date,
        ymd: String,
        markdownFilePath: String,
        logFilePath: String,
        ordinal: Int
    ) {
        self.title = title
        self.url = url
        self.normalizedURL = normalizedURL
        self.date = date
        self.ymd = ymd
        self.markdownFilePath = markdownFilePath
        self.logFilePath = logFilePath
        self.ordinal = ordinal
    }

    public var id: String {
        "\(markdownFilePath)#\(ordinal)"
    }
}

public struct DailyLinkSearchResult: Equatable, Sendable, Identifiable {
    public let record: DailyLinkSearchRecord
    public let score: Int

    public init(record: DailyLinkSearchRecord, score: Int) {
        self.record = record
        self.score = score
    }

    public var id: String {
        record.id
    }
}

public struct DailyLinkSearchIndex: Sendable {
    public let records: [DailyLinkSearchRecord]

    public init(records: [DailyLinkSearchRecord] = []) {
        self.records = records
    }

    public static func build(fileURLs: [URL], fileManager: FileManager = .default) -> DailyLinkSearchIndex {
        let records = fileURLs.flatMap { fileURL in
            buildRecords(for: fileURL, fileManager: fileManager)
        }
        return DailyLinkSearchIndex(records: records)
    }

    public func search(query rawQuery: String, limit: Int = 12) -> [DailyLinkSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        if Self.looksLikeURL(query) {
            let normalizedQuery = URLNormalizer.normalizedURLForDedup(query)
            let exactMatches = records
                .filter { $0.normalizedURL == normalizedQuery }
                .map { DailyLinkSearchResult(record: $0, score: 10_000) }
                .sorted {
                    if $0.record.date != $1.record.date {
                        return $0.record.date > $1.record.date
                    }
                    return $0.record.ordinal < $1.record.ordinal
                }

            if !exactMatches.isEmpty {
                return Array(exactMatches.prefix(limit))
            }
        }

        let candidates = records.compactMap { record -> DailyLinkSearchResult? in
            guard let score = Self.score(record: record, query: query) else {
                return nil
            }
            return DailyLinkSearchResult(record: record, score: score)
        }

        return candidates
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                if $0.record.date != $1.record.date {
                    return $0.record.date > $1.record.date
                }
                if $0.record.ordinal != $1.record.ordinal {
                    return $0.record.ordinal < $1.record.ordinal
                }
                return $0.record.title.localizedCaseInsensitiveCompare($1.record.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func buildRecords(for fileURL: URL, fileManager: FileManager) -> [DailyLinkSearchRecord] {
        guard
            let ymd = parseYMD(from: fileURL.lastPathComponent),
            let date = ymdFormatter.date(from: ymd),
            let content = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            return []
        }

        let directory = fileURL.deletingLastPathComponent()
        let logFilePath = directory
            .appendingPathComponent("logs_\(ymd).log")
            .path(percentEncoded: false)
        let markdownFilePath = fileURL.path(percentEncoded: false)

        return MarkdownLinkExtractor.extract(from: content).enumerated().map { index, link in
            DailyLinkSearchRecord(
                title: link.label,
                url: link.url,
                normalizedURL: URLNormalizer.normalizedURLForDedup(link.url),
                date: date,
                ymd: ymd,
                markdownFilePath: markdownFilePath,
                logFilePath: logFilePath,
                ordinal: index
            )
        }
    }

    private static func score(record: DailyLinkSearchRecord, query rawQuery: String) -> Int? {
        if looksLikeURL(rawQuery) {
            return scoreURLQuery(record: record, query: rawQuery)
        }
        return scoreTextQuery(record: record, query: rawQuery)
    }

    private static func scoreURLQuery(record: DailyLinkSearchRecord, query rawQuery: String) -> Int? {
        let query = URLNormalizer.normalizedURLForDedup(rawQuery)
        let url = record.normalizedURL

        if url == query {
            return 10_000
        }

        let loweredQuery = query.lowercased()
        let loweredURL = url.lowercased()

        if loweredURL.hasPrefix(loweredQuery) {
            return 7_000
        }

        if loweredURL.contains(loweredQuery) {
            return 5_000
        }

        return nil
    }

    private static func scoreTextQuery(record: DailyLinkSearchRecord, query rawQuery: String) -> Int? {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = record.title.lowercased()
        let url = record.url.lowercased()

        if title == query {
            return 9_000
        }

        if title.hasPrefix(query) {
            return 7_500
        }

        if title.contains(query) {
            return 6_000
        }

        if url.contains(query) {
            return 4_000
        }

        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
        if tokens.count > 1 {
            let titleTokenMatches = tokens.filter { title.contains($0) }.count
            let urlTokenMatches = tokens.filter { url.contains($0) }.count
            let matchedTokenCount = tokens.filter { title.contains($0) || url.contains($0) }.count

            if titleTokenMatches == tokens.count {
                return 3_000 + titleTokenMatches * 200
            }

            if matchedTokenCount >= 2 {
                return 2_000 + titleTokenMatches * 150 + urlTokenMatches * 80
            }
        }

        if query.count >= 3 {
            let titleFuzzy = fuzzyScore(query: query, in: title)
            if titleFuzzy >= minimumFuzzyScore(for: query) {
                return 1_200 + titleFuzzy
            }
        }

        return nil
    }

    private static func looksLikeURL(_ rawQuery: String) -> Bool {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("://"), let components = URLComponents(string: trimmed) else {
            return false
        }
        return components.scheme?.isEmpty == false && components.host?.isEmpty == false
    }

    private static func fuzzyScore(query: String, in text: String) -> Int {
        guard !query.isEmpty, !text.isEmpty else {
            return 0
        }

        let queryChars = Array(query)
        let textChars = Array(text)
        var queryIndex = 0
        var score = 0
        var contiguousRun = 0

        for (textIndex, character) in textChars.enumerated() {
            guard queryIndex < queryChars.count else {
                break
            }

            if character == queryChars[queryIndex] {
                contiguousRun += 1
                score += 8 + contiguousRun * 4
                if textIndex == 0 {
                    score += 6
                }
                queryIndex += 1
            } else {
                contiguousRun = 0
            }
        }

        return queryIndex == queryChars.count ? score : 0
    }

    private static func minimumFuzzyScore(for query: String) -> Int {
        max(60, query.filter { !$0.isWhitespace }.count * 18)
    }

    private static func parseYMD(from fileName: String) -> String? {
        guard fileName.hasPrefix("links_"), fileName.hasSuffix(".md") else {
            return nil
        }

        let start = fileName.index(fileName.startIndex, offsetBy: 6)
        let end = fileName.index(fileName.endIndex, offsetBy: -3)
        let ymd = String(fileName[start..<end])
        guard ymd.count == 8, ymd.allSatisfy(\.isNumber) else {
            return nil
        }
        return ymd
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
