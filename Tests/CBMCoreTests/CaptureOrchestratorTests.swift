import Foundation
import Testing
@testable import CBMCore

private final class CountingRunner: CommandRunning {
    private(set) var calls = 0

    func run(command: String, arguments: [String]) -> CommandExecutionResult {
        calls += 1
        return CommandExecutionResult(exitCode: 0, standardOutput: "", standardError: "")
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

    let first = orchestrator.process(clipboardText: text, allowMultipleLinks: false, store: store, date: date)
    let second = orchestrator.process(clipboardText: text, allowMultipleLinks: false, store: store, date: date)

    #expect(first.appendedCount == 1)
    #expect(first.clonedCount == 1)
    #expect(second.appendedCount == 0)
    #expect(second.skippedCount == 1)
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
    let disabled = orchestrator.process(clipboardText: text, allowMultipleLinks: false, store: store)
    let enabled = orchestrator.process(clipboardText: text, allowMultipleLinks: true, store: store)

    #expect(disabled.totalCandidates == 0)
    #expect(enabled.totalCandidates == 2)
    #expect(enabled.appendedCount == 2)
    #expect(runner.calls == 2)
}
