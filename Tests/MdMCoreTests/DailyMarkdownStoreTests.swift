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
