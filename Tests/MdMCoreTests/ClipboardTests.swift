import Foundation
import Testing
@testable import MdMCore

private struct MockLinkMetadataFetcher: LinkMetadataFetching {
    let response: PageLinkMetadata?

    func fetchMetadata(for url: URL) -> PageLinkMetadata? {
        response
    }
}

@Test
func singleLinkModeRequiresExactlyOneMarkdownLink() {
    let text = "[one](https://github.com/a/one) [two](https://github.com/b/two)"
    let captures = ClipboardContentProcessor.extractRepositoryCaptures(from: text, allowMultipleLinks: false)
    #expect(captures.isEmpty)
}

@Test
func multipleModeProcessesAllValidGitHubRepos() {
    let text = "[a](https://github.com/o1/r1) [bad](https://example.com/x/y) [b](https://github.com/o2/r2?tab=readme#top)"
    let captures = ClipboardContentProcessor.extractRepositoryCaptures(from: text, allowMultipleLinks: true)

    #expect(captures.count == 2)
    #expect(captures[0].repository.canonicalURL == "https://github.com/o1/r1")
    #expect(captures[1].repository.canonicalURL == "https://github.com/o2/r2")
}

@Test
func allowlistedPlainURLUsesFetchedMetadata() {
    let text = "https://chromewebstore.google.com/detail/example-extension/abcdefghijklmnopabcdefghijklmnop?utm_source=rss&id=42"
    let captures = ClipboardContentProcessor.extractLinkCaptures(
        from: text,
        allowMultipleLinks: false,
        repositoryDomains: [],
        metadataAllowedDomains: ["chromewebstore.google.com"],
        metadataFetcher: MockLinkMetadataFetcher(
            response: PageLinkMetadata(
                title: "Example Extension",
                summary: "Fast lookup for long conversations."
            )
        )
    )

    #expect(captures.count == 1)
    #expect(captures[0].label == "Example Extension")
    #expect(captures[0].url == "https://chromewebstore.google.com/detail/example-extension/abcdefghijklmnopabcdefghijklmnop?id=42")
    #expect(captures[0].annotation == "Fast lookup for long conversations.")
    #expect(captures[0].repository == nil)
}

@Test
func nonAllowlistedPlainURLIsIgnored() {
    let text = "https://chromewebstore.google.com/detail/example-extension/abcdefghijklmnopabcdefghijklmnop"
    let captures = ClipboardContentProcessor.extractLinkCaptures(
        from: text,
        allowMultipleLinks: false,
        repositoryDomains: [],
        metadataAllowedDomains: [],
        metadataFetcher: MockLinkMetadataFetcher(response: nil)
    )

    #expect(captures.isEmpty)
}

@Test
func plainGithubWikiURLIsProcessedAsRepositoryLink() {
    let text = "https://github.com/SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki.git"
    let captures = ClipboardContentProcessor.extractLinkCaptures(
        from: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com"]
    )

    #expect(captures.count == 1)
    #expect(captures[0].label == "SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki")
    #expect(captures[0].repository?.canonicalURL == "https://github.com/SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki")
    #expect(captures[0].annotation == nil)
}

@Test
func wechatImageMarkdownLinkIsTreatedAsAttachment() {
    let text = "* [ ] [图片](https://mmbiz.qpic.cn/sz_mmbiz_jpg/example/640?wx_fmt=jpeg)"
    let captures = ClipboardContentProcessor.extractCaptures(
        from: text,
        allowMultipleLinks: false,
        repositoryDomains: []
    )

    #expect(captures.count == 1)
    if case let .attachment(attachment) = captures[0] {
        #expect(attachment.sourceURL == "https://mmbiz.qpic.cn/sz_mmbiz_jpg/example/640?wx_fmt=jpeg")
        #expect(attachment.label == "图片")
    } else {
        Issue.record("Expected attachment capture")
    }
}

private final class MutableMockClipboardProvider: ClipboardTextProviding {
    var changeCount: Int
    var text: String?

    init(changeCount: Int, text: String?) {
        self.changeCount = changeCount
        self.text = text
    }

    func readString() -> String? {
        text
    }
}

@Test
func monitorOnlyEmitsWhenEnabledAndChanged() {
    let provider = MutableMockClipboardProvider(changeCount: 1, text: "[swift](https://github.com/apple/swift)")
    var received: [String] = []

    let monitor = ClipboardMonitor(provider: provider) { text in
        received.append(text)
    }

    monitor.tick()
    #expect(received.isEmpty)

    monitor.isEnabled = true
    monitor.tick()
    #expect(received.isEmpty)

    provider.changeCount = 2
    monitor.tick()

    #expect(received.count == 1)
}
