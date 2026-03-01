import Foundation

public struct DailyMarkdownStore {
    public static let defaultDirectoryPath = "~/Documents/cbm"

    private let baseDirectoryURL: URL
    private let fileManager: FileManager

    public init(baseDirectoryPath: String = DailyMarkdownStore.defaultDirectoryPath, fileManager: FileManager = .default) {
        self.baseDirectoryURL = DailyMarkdownStore.expandTilde(path: baseDirectoryPath)
        self.fileManager = fileManager
    }

    public var baseDirectory: URL {
        baseDirectoryURL
    }

    public func todayFileURL(now: Date = Date()) -> URL {
        fileURL(for: now)
    }

    public func fileURL(for date: Date) -> URL {
        let ymd = Self.ymdString(from: date)
        return baseDirectoryURL.appendingPathComponent("links_\(ymd).md")
    }

    public func ensureBaseDirectoryExists() throws {
        try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
    }

    public func readContent(for date: Date = Date()) throws -> String {
        let fileURL = fileURL(for: date)
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return ""
        }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    public func readDailyDedupKeys(for date: Date = Date()) throws -> Set<String> {
        let content = try readContent(for: date)
        let links = MarkdownLinkExtractor.extract(from: content)

        return Set(links.compactMap { link in
            GitHubRepositoryParser.parse(from: link.url)?.dailyDedupKey
        })
    }

    @discardableResult
    public func appendIfNeeded(label: String, repository: GitHubRepository, date: Date = Date()) throws -> Bool {
        try ensureBaseDirectoryExists()

        let existingKeys = try readDailyDedupKeys(for: date)
        guard !existingKeys.contains(repository.dailyDedupKey) else {
            return false
        }

        let dailyFile = fileURL(for: date)
        var existing = ""
        if fileManager.fileExists(atPath: dailyFile.path(percentEncoded: false)) {
            existing = try String(contentsOf: dailyFile, encoding: .utf8)
        }

        let line = MarkdownTaskLineBuilder.makeLine(label: label, repositoryURL: repository.canonicalURL)
        let output: String
        if existing.isEmpty {
            output = line + "\n"
        } else if existing.hasSuffix("\n") {
            output = existing + line + "\n"
        } else {
            output = existing + "\n" + line + "\n"
        }

        try output.write(to: dailyFile, atomically: true, encoding: .utf8)
        return true
    }

    public func listRecentDailyFiles(limit: Int? = nil) throws -> [URL] {
        guard fileManager.fileExists(atPath: baseDirectoryURL.path(percentEncoded: false)) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: baseDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let matched = files.compactMap { url -> (url: URL, ymd: String)? in
            let name = url.lastPathComponent
            guard name.hasPrefix("links_"), name.hasSuffix(".md") else {
                return nil
            }
            let body = name.dropFirst("links_".count).dropLast(".md".count)
            let ymd = String(body)
            guard ymd.count == 8, ymd.allSatisfy(\.isNumber) else {
                return nil
            }
            return (url, ymd)
        }

        let sorted = matched.sorted { $0.ymd > $1.ymd }.map(\.url)
        if let limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    public static func ymdString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func expandTilde(path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(filePath: expanded, directoryHint: .isDirectory)
    }
}
