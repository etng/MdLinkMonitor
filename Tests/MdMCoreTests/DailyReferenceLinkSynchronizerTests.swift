import Foundation
import Testing
@testable import MdMCore

@Test
func dailyReferenceSyncPreservesRealLinksAndFiltersGarbage() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    let cbmContent = """
    * [ ] [Keep Me](https://example.com/keep)
    * [ ] [🦞](https://abs-0.twimg.com/emoji/v2/svg/1f99e.svg)
    * [ ] [1.9M](https://x.com/systematicls/status/2028814227004395561/analytics)
    * [ ] [New Link](https://example.com/new)
    * [ ] [Relative](/bad/path)
    """
    try cbmContent.write(
        to: cbmRoot.appendingPathComponent("links_20260305.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyContent = """
    ---
    date: 2026-03-05
    ---

    ## 参考链接
    * [ ]
    * [ ] [Keep Me](https://example.com/keep)
    * [x] []()

    ## 今日搜藏
    """
    let dailyFile = monthRoot.appendingPathComponent("daily_260305.md")
    try dailyContent.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false)
    )

    let result = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-05"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(result.processedFiles == 1)
    #expect(result.updatedFiles == 1)
    #expect(result.appendedLinks == 1)
    #expect(updated.contains("* [ ] [Keep Me](https://example.com/keep)"))
    #expect(updated.contains("* [ ] [New Link](https://example.com/new)"))
    #expect(!updated.contains("1.9M"))
    #expect(!updated.contains("🦞"))
    #expect(!updated.contains("* [ ] \n"))
    #expect(!updated.contains("* [x] []()"))
}

@Test
func dailyReferenceSyncIsIdempotentAfterInitialCatchUp() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [One](https://example.com/one)
    * [ ] [Two](https://example.com/two)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260306.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260306.md")
    try """
    ## 参考链接

    ## 今日搜藏
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false)
    )

    let first = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-06"))
    let firstContent = try String(contentsOf: dailyFile, encoding: .utf8)
    let second = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-06"))
    let secondContent = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(first.updatedFiles == 1)
    #expect(first.appendedLinks == 2)
    #expect(second.updatedFiles == 0)
    #expect(second.appendedLinks == 0)
    #expect(firstContent == secondContent)
}

@Test
func dailyReferenceSyncPreservesCheckedStateAndManualEdits() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [Keep Me](https://example.com/keep)
    * [ ] [New Link](https://example.com/new)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260307.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260307.md")
    try """
    ## 参考链接
    * [x] [Keep Me](https://example.com/keep) - reviewed

    ## 今日搜藏
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false)
    )

    let result = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-07"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(result.updatedFiles == 1)
    #expect(updated.contains("* [x] [Keep Me](https://example.com/keep) - reviewed"))
    #expect(updated.contains("* [ ] [New Link](https://example.com/new)"))
    #expect(!updated.contains("* [ ] [Keep Me](https://example.com/keep)"))
}

@Test
func dailyReferenceSyncRespectsCustomHeadingLevelBoundary() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [New Link](https://example.com/new)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260308.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260308.md")
    try """
    # Day Note

    ### 参考链接

    ### 后续章节
    keep-this-content
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false),
        referenceSectionHeading: "### 参考链接"
    )

    let _ = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-08"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(updated.contains("### 后续章节"))
    #expect(updated.contains("keep-this-content"))
    #expect(updated.contains("* [ ] [New Link](https://example.com/new)"))
}

@Test
func dailyReferenceSyncPreservesLowerLevelSubheadingContentWithinSection() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [New Link](https://example.com/new)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260309.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260309.md")
    try """
    ### 参考链接
    #### 手工备注
    keep-child-content

    ### 后续章节
    untouched
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false),
        referenceSectionHeading: "### 参考链接"
    )

    let _ = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-09"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(updated.contains("* [ ] [New Link](https://example.com/new)"))
    #expect(updated.contains("#### 手工备注"))
    #expect(updated.contains("keep-child-content"))
    #expect(updated.contains("### 后续章节"))
    #expect(updated.contains("untouched"))
}

@Test
func dailyReferenceSyncExtendsToEndOfFileWhenNoLaterHeadingExists() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [EOF Link](https://example.com/eof)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260310.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260310.md")
    try """
    # Day Note

    ## 参考链接
    手工补充留在结尾
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false)
    )

    let _ = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-10"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(updated.contains("* [ ] [EOF Link](https://example.com/eof)"))
    #expect(updated.contains("手工补充留在结尾"))
    #expect(updated.hasSuffix("手工补充留在结尾"))
}

@Test
func dailyReferenceSyncStopsAtHigherLevelHeading() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cbmRoot = tempRoot.appendingPathComponent("cbm", isDirectory: true)
    let dailyRoot = tempRoot.appendingPathComponent("daily", isDirectory: true)
    let monthRoot = dailyRoot.appendingPathComponent("2603", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: cbmRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: monthRoot, withIntermediateDirectories: true)

    try """
    * [ ] [Root Boundary Link](https://example.com/root)
    """.write(
        to: cbmRoot.appendingPathComponent("links_20260311.md"),
        atomically: true,
        encoding: .utf8
    )

    let dailyFile = monthRoot.appendingPathComponent("daily_260311.md")
    try """
    ## 前言

    ### 参考链接

    # 顶层章节
    root-content
    """.write(to: dailyFile, atomically: true, encoding: .utf8)

    let synchronizer = DailyReferenceLinkSynchronizer(
        cbmDirectoryPath: cbmRoot.path(percentEncoded: false),
        dailyRootDirectoryPath: dailyRoot.path(percentEncoded: false),
        referenceSectionHeading: "### 参考链接"
    )

    let _ = try synchronizer.sync(through: TestDateFactory.makeDate("2026-03-11"))
    let updated = try String(contentsOf: dailyFile, encoding: .utf8)

    #expect(updated.contains("* [ ] [Root Boundary Link](https://example.com/root)"))
    #expect(updated.contains("# 顶层章节"))
    #expect(updated.contains("root-content"))
}

private enum TestDateFactory {
    static func makeDate(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
