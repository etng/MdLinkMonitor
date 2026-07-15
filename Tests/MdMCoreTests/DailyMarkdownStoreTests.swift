import Foundation
import Testing
@testable import MdMCore

@Test
func appendAndDailyDedupWorks() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let repo = GitHubRepository(owner: "apple", name: "swift")
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    let first = try store.appendIfNeeded(label: "Swift", repository: repo, date: date)
    let second = try store.appendIfNeeded(label: "Swift", repository: repo, date: date)

    #expect(first)
    #expect(!second)

    let content = try store.readContent(for: date)
    #expect(content.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 1)
    #expect(content.contains("* [ ] [Swift](https://github.com/apple/swift)"))
}

@Test
func duplicateAllowedOnDifferentDay() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let repo = GitHubRepository(owner: "apple", name: "swift")

    let day1 = Date(timeIntervalSince1970: 1_700_000_000)
    let day2 = Date(timeIntervalSince1970: 1_700_086_400)

    let first = try store.appendIfNeeded(label: "Swift", repository: repo, date: day1)
    let second = try store.appendIfNeeded(label: "Swift", repository: repo, date: day2)

    #expect(first)
    #expect(second)
}

@Test
func recentFilesAreSortedDescByDate() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let repo = GitHubRepository(owner: "o", name: "r")

    let d1 = Date(timeIntervalSince1970: 1_700_000_000)
    let d2 = Date(timeIntervalSince1970: 1_700_172_800)
    let d3 = Date(timeIntervalSince1970: 1_700_259_200)

    _ = try store.appendIfNeeded(label: "r", repository: repo, date: d1)
    _ = try store.appendIfNeeded(label: "r", repository: repo, date: d2)
    _ = try store.appendIfNeeded(label: "r", repository: repo, date: d3)

    let recent = try store.listRecentDailyFiles()
    let names = recent.map { $0.lastPathComponent }

    #expect(names.count == 3)
    #expect(names[0] > names[1])
    #expect(names[1] > names[2])
}

@Test
func sortFileByDomainReordersMarkdownEntries() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    _ = try store.appendIfNeeded(label: "WeChat", linkURL: "https://mp.weixin.qq.com/s/example", date: date)
    _ = try store.appendIfNeeded(label: "GitHub", linkURL: "https://github.com/apple/swift", date: date)
    _ = try store.appendIfNeeded(label: "Docs", linkURL: "https://developer.apple.com/documentation", date: date)
    _ = try store.appendIfNeeded(label: "Forums", linkURL: "https://forums.developer.apple.com/forums/thread/1", date: date)

    let changed = try store.sortFileByDomain(at: store.fileURL(for: date).path(percentEncoded: false))
    let content = try store.readContent(for: date)
    let lines = content.split(whereSeparator: \.isNewline).map(String.init)

    #expect(changed)
    #expect(lines.count == 4)
    #expect(lines[0].contains("developer.apple.com"))
    #expect(lines[1].contains("forums.developer.apple.com"))
    #expect(lines[2].contains("github.com"))
    #expect(lines[3].contains("mp.weixin.qq.com"))
}
