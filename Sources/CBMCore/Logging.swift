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
    public private(set) var entries: [LogEntry] = []

    public init() {}

    public func log(_ level: LogLevel, _ message: String) {
        entries.append(LogEntry(level: level, message: message))
    }
}
