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

    private let fileManager: FileManager
    private let lock = NSLock()

    public init(baseDirectoryPath: String, fileManager: FileManager = .default) {
        self.baseDirectoryPath = baseDirectoryPath
        self.fileManager = fileManager
    }

    public func log(_ level: LogLevel, _ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let logURL = todayLogFileURL()
        do {
            try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let line = "\(timestampString()) [\(level.rawValue.uppercased())] \(message)\n"

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
    }

    public func todayLogFileURL(now: Date = Date()) -> URL {
        let ymd = DailyMarkdownStore.ymdString(from: now)
        let dir = URL(filePath: NSString(string: baseDirectoryPath).expandingTildeInPath, directoryHint: .isDirectory)
        return dir.appendingPathComponent("logs_\(ymd).log")
    }

    private func timestampString(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: now)
    }
}
