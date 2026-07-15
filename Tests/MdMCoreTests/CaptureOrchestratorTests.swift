import Foundation
import Testing
@testable import MdMCore

private final class CountingRunner: CommandRunning {
    private(set) var calls = 0

    func run(command: String, arguments: [String]) -> CommandExecutionResult {
        calls += 1
        return CommandExecutionResult(exitCode: 0, standardOutput: "", standardError: "")
    }
}

private struct StaticMetadataFetcher: LinkMetadataFetching {
    let response: PageLinkMetadata?

    func fetchMetadata(for url: URL) -> PageLinkMetadata? {
        response
    }
}

private struct StaticAttachmentDownloader: AttachmentDownloading {
    let response: DownloadedAttachment?

    func download(url: URL) -> DownloadedAttachment? {
        response
    }
}

@Test
func orchestratorAppendsAndClonesOncePerDay() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let orchestrator = ClipboardCaptureOrchestrator(cloneExecutor: executor)

    let text = "[Swift](https://github.com/apple/swift?tab=readme#readme)"
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    let first = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store,
        date: date
    )
    let second = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store,
        date: date
    )

    #expect(first.appendedCount == 1)
    #expect(first.clonedCount == 1)
    #expect(second.appendedCount == 0)
    #expect(second.skippedCount == 1)
    #expect(second.duplicateCount == 1)
    #expect(runner.calls == 1)
}

@Test
func orchestratorHonorsMultipleSwitch() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let orchestrator = ClipboardCaptureOrchestrator(cloneExecutor: executor)

    let text = "[A](https://github.com/o1/r1) [B](https://github.com/o2/r2)"
    let disabled = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store
    )
    let enabled = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: true,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store
    )

    #expect(disabled.totalCandidates == 0)
    #expect(enabled.totalCandidates == 2)
    #expect(enabled.appendedCount == 2)
    #expect(runner.calls == 2)
}

@Test
func nonRepositoryLinksStillAppendButDoNotClone() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let orchestrator = ClipboardCaptureOrchestrator(cloneExecutor: executor)

    let text = "[Article](https://example.com/blog/post-1)"
    let result = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store
    )

    #expect(result.totalCandidates == 1)
    #expect(result.appendedCount == 1)
    #expect(result.clonedCount == 0)
    #expect(runner.calls == 0)
}

@Test
func plainGithubWikiURLIsAppendedAndClonedWithoutMetadataAllowlist() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let orchestrator = ClipboardCaptureOrchestrator(cloneExecutor: executor)

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let text = "https://github.com/SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki.git"
    let result = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store,
        date: date
    )
    let content = try store.readContent(for: date)

    #expect(result.totalCandidates == 1)
    #expect(result.appendedCount == 1)
    #expect(result.clonedCount == 1)
    #expect(runner.calls == 1)
    #expect(content.contains("* [ ] [SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki](https://github.com/SHORiN-KiWATA/Shorin-ArchLinux-Guide.wiki)"))
}

@Test
func allowlistedPlainURLAppendsFetchedTitleAndSummary() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let orchestrator = ClipboardCaptureOrchestrator(
        cloneExecutor: executor,
        metadataFetcher: StaticMetadataFetcher(
            response: PageLinkMetadata(
                title: "AIChatIndex",
                summary: "AI聊天目录，快速回溯，精准定位。"
            )
        )
    )

    let text = "https://chromewebstore.google.com/detail/aichatindex/kgaaloljjidblambloblebocaobjjmlb"
    let result = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        metadataAllowedDomains: ["chromewebstore.google.com"],
        store: store
    )

    let content = try store.readContent(for: Date())
    #expect(result.totalCandidates == 1)
    #expect(result.appendedCount == 1)
    #expect(result.clonedCount == 0)
    #expect(runner.calls == 0)
    #expect(content.contains("* [ ] [AIChatIndex](https://chromewebstore.google.com/detail/aichatindex/kgaaloljjidblambloblebocaobjjmlb) - AI聊天目录，快速回溯，精准定位。"))
}

@Test
func wechatImageIsSavedAsAttachmentWithoutMarkdownAppend() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let store = DailyMarkdownStore(baseDirectoryPath: tempRoot.path(percentEncoded: false))
    let runner = CountingRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
    let orchestrator = ClipboardCaptureOrchestrator(
        cloneExecutor: executor,
        attachmentDownloader: StaticAttachmentDownloader(
            response: DownloadedAttachment(data: imageData, contentType: "image/jpeg")
        )
    )

    let text = "* [ ] [图片](https://mmbiz.qpic.cn/sz_mmbiz_jpg/example/640?wx_fmt=jpeg)"
    let result = orchestrator.process(
        clipboardText: text,
        allowMultipleLinks: false,
        repositoryDomains: ["github.com", "gitlab.com"],
        store: store
    )

    let content = try store.readContent(for: Date())
    let attachments = AttachmentLibraryStore(baseDirectoryPath: tempRoot.path(percentEncoded: false)).listAttachments()

    #expect(result.totalCandidates == 1)
    #expect(result.appendedCount == 0)
    #expect(result.attachmentCount == 1)
    #expect(result.clonedCount == 0)
    #expect(runner.calls == 0)
    #expect(content.isEmpty)
    #expect(attachments.count == 1)
    #expect(attachments[0].contentType == "image/jpeg")
}
