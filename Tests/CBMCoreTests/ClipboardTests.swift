import Testing
@testable import CBMCore

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
