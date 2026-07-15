import Foundation
import Testing
@testable import MdMCore

@Test
func dailyFileLoggerWritesLogFile() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let logger = DailyFileLogger(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    logger.log(.info, "hello")

    let logURL = logger.todayLogFileURL()
    let content = try String(contentsOf: logURL, encoding: .utf8)

    #expect(content.contains("[INFO] hello"))
}

@Test
func compositeLoggerForwardsLogs() {
    let memory1 = InMemoryLogger()
    let memory2 = InMemoryLogger()
    let logger = CompositeLogger(loggers: [memory1, memory2])

    logger.log(.warning, "x")

    #expect(memory1.entries.count == 1)
    #expect(memory2.entries.count == 1)
    #expect(memory1.entries[0].level == .warning)
}

@Test
func dailyFileLoggerPrunesExpiredLogs() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let oldLog = tempRoot.appendingPathComponent("logs_20260201.log")
    let keptLog = tempRoot.appendingPathComponent("logs_20260210.log")
    try "old\n".write(to: oldLog, atomically: true, encoding: .utf8)
    try "keep\n".write(to: keptLog, atomically: true, encoding: .utf8)

    let logger = DailyFileLogger(
        baseDirectoryPath: tempRoot.path(percentEncoded: false),
        retentionDays: 3
    )
    let now = ISO8601DateFormatter().date(from: "2026-02-12T08:00:00Z")!
    logger.pruneOldLogsIfNeeded(now: now, force: true)

    #expect(FileManager.default.fileExists(atPath: keptLog.path(percentEncoded: false)))
    #expect(FileManager.default.fileExists(atPath: oldLog.path(percentEncoded: false)) == false)
}
