import Foundation

public enum LogLevel: String, Sendable {
    case info
    case warning
    case error
}

public struct LogEntry: Sendable {
    public let timestamp: Date
    public let level: LogLevel
    public let message: String

    public init(timestamp: Date = Date(), level: LogLevel, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public protocol Logging: AnyObject {
    func log(_ level: LogLevel, _ message: String)
}

public final class InMemoryLogger: Logging {
    private var storage: [LogEntry] = []
    private let lock = NSLock()

    public var entries: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    public init() {}

    public func log(_ level: LogLevel, _ message: String) {
        lock.lock()
        storage.append(LogEntry(level: level, message: message))
        lock.unlock()
    }
}

public final class CompositeLogger: Logging {
    private let loggers: [any Logging]

    public init(loggers: [any Logging]) {
        self.loggers = loggers
    }

    public func log(_ level: LogLevel, _ message: String) {
        for logger in loggers {
            logger.log(level, message)
        }
    }
}

public final class DailyFileLogger: Logging {
    public var baseDirectoryPath: String
    public var retentionDays: Int {
        get { normalizedRetentionDays }
        set { normalizedRetentionDays = max(0, newValue) }
    }

    private let fileManager: FileManager
    private let lock = NSLock()
    private var normalizedRetentionDays: Int
    private var lastPrunedYMD: String?

    public init(
        baseDirectoryPath: String,
        retentionDays: Int = AppSettings.defaultLogRetentionDays,
        fileManager: FileManager = .default
    ) {
        self.baseDirectoryPath = baseDirectoryPath
        self.normalizedRetentionDays = max(0, retentionDays)
        self.fileManager = fileManager
    }

    public func log(_ level: LogLevel, _ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let logURL = todayLogFileURL(now: now)
        do {
            try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let line = "\(timestampString(now: now)) [\(level.rawValue.uppercased())] \(message)\n"

            if fileManager.fileExists(atPath: logURL.path(percentEncoded: false)) {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } else {
                try line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Swallow logger errors to avoid breaking app flow.
        }

        pruneOldLogsIfNeededLocked(now: now)
    }

    public func todayLogFileURL(now: Date = Date()) -> URL {
        let ymd = DailyMarkdownStore.ymdString(from: now)
        let dir = URL(filePath: NSString(string: baseDirectoryPath).expandingTildeInPath, directoryHint: .isDirectory)
        return dir.appendingPathComponent("logs_\(ymd).log")
    }

    public func pruneOldLogsIfNeeded(now: Date = Date(), force: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        pruneOldLogsIfNeededLocked(now: now, force: force)
    }

    private func pruneOldLogsIfNeededLocked(now: Date, force: Bool = false) {
        guard retentionDays > 0 else {
            return
        }

        let currentYMD = DailyMarkdownStore.ymdString(from: now)
        if !force, lastPrunedYMD == currentYMD {
            return
        }
        lastPrunedYMD = currentYMD

        let directory = URL(filePath: NSString(string: baseDirectoryPath).expandingTildeInPath, directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return
        }

        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoffDate = calendar.date(byAdding: .day, value: -(retentionDays - 1), to: startOfToday) else {
            return
        }

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in files {
            guard
                let ymd = Self.parseLogYMD(from: fileURL.lastPathComponent),
                let fileDate = Self.ymdFormatter.date(from: ymd),
                fileDate < cutoffDate
            else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func timestampString(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: now)
    }

    private static func parseLogYMD(from fileName: String) -> String? {
        guard fileName.hasPrefix("logs_"), fileName.hasSuffix(".log") else {
            return nil
        }

        let start = fileName.index(fileName.startIndex, offsetBy: 5)
        let end = fileName.index(fileName.endIndex, offsetBy: -4)
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
