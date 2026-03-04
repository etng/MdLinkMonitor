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
