import Foundation
import Testing
@testable import MdMCore

@Test
func urlSearchPrefersExactNormalizedMatch() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let records = [
        DailyLinkSearchRecord(
            title: "Swift",
            url: "https://github.com/apple/swift",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://github.com/apple/swift"),
            date: date,
            ymd: "20231114",
            markdownFilePath: "/tmp/links_20231114.md",
            logFilePath: "/tmp/logs_20231114.log",
            ordinal: 0
        ),
        DailyLinkSearchRecord(
            title: "Swift Evolution",
            url: "https://github.com/apple/swift-evolution",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://github.com/apple/swift-evolution"),
            date: date,
            ymd: "20231114",
            markdownFilePath: "/tmp/links_20231114.md",
            logFilePath: "/tmp/logs_20231114.log",
            ordinal: 1
        ),
    ]

    let index = DailyLinkSearchIndex(records: records)
    let results = index.search(query: "https://github.com/apple/swift/?ref=top")

    #expect(results.count == 1)
    #expect(results.first?.record.title == "Swift")
}

@Test
func textSearchSortsByRelevanceThenDate() {
    let older = Date(timeIntervalSince1970: 1_700_000_000)
    let newer = Date(timeIntervalSince1970: 1_700_086_400)

    let index = DailyLinkSearchIndex(records: [
        DailyLinkSearchRecord(
            title: "Swift Compiler Internals",
            url: "https://example.com/compiler",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://example.com/compiler"),
            date: newer,
            ymd: "20231115",
            markdownFilePath: "/tmp/links_20231115.md",
            logFilePath: "/tmp/logs_20231115.log",
            ordinal: 0
        ),
        DailyLinkSearchRecord(
            title: "Understanding the Swift Compiler",
            url: "https://example.com/swift-compiler",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://example.com/swift-compiler"),
            date: older,
            ymd: "20231114",
            markdownFilePath: "/tmp/links_20231114.md",
            logFilePath: "/tmp/logs_20231114.log",
            ordinal: 0
        ),
        DailyLinkSearchRecord(
            title: "Build Systems",
            url: "https://example.com/swift-compiler-build",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://example.com/swift-compiler-build"),
            date: newer,
            ymd: "20231115",
            markdownFilePath: "/tmp/links_20231115.md",
            logFilePath: "/tmp/logs_20231115.log",
            ordinal: 1
        ),
    ])

    let results = index.search(query: "swift compiler")

    #expect(results.count == 3)
    #expect(results[0].record.title == "Swift Compiler Internals")
    #expect(results[1].record.title == "Understanding the Swift Compiler")
    #expect(results[2].record.title == "Build Systems")
}

@Test
func weakTextFuzzyMatchesAreFilteredOut() {
    let index = DailyLinkSearchIndex(records: [
        DailyLinkSearchRecord(
            title: "Understanding the Swift Compiler",
            url: "https://example.com/swift-compiler",
            normalizedURL: URLNormalizer.normalizedURLForDedup("https://example.com/swift-compiler"),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            ymd: "20231114",
            markdownFilePath: "/tmp/links_20231114.md",
            logFilePath: "/tmp/logs_20231114.log",
            ordinal: 0
        )
    ])

    let results = index.search(query: "uhr")

    #expect(results.isEmpty)
}
