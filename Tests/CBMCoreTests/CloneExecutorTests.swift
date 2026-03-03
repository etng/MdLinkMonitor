import Testing
@testable import CBMCore
import Foundation

private final class MockRunner: CommandRunning {
    var recordedCommand: String?
    var recordedArguments: [String] = []
    var result = CommandExecutionResult(exitCode: 0, standardOutput: "", standardError: "")

    func run(command: String, arguments: [String]) -> CommandExecutionResult {
        recordedCommand = command
        recordedArguments = arguments
        return result
    }
}

@Test
func cloneExecutorUsesDefaultTemplateWithCanonicalCloneURL() {
    let runner = MockRunner()
    let logger = InMemoryLogger()
    let executor = GitC1CloneExecutor(commandRunner: runner, logger: logger)
    let repo = GitHubRepository(owner: "owner", name: "repo")

    let result = executor.clone(repository: repo)

    #expect(result.isSuccess)
    #expect(runner.recordedCommand == "/bin/zsh")
    #expect(runner.recordedArguments == ["-lc", "git clone https://github.com/owner/repo.git"])
    #expect(logger.entries.count == 2)
    #expect(logger.entries[0].message.contains("Start clone"))
    #expect(logger.entries[1].message.contains("Clone success"))
}

@Test
func cloneExecutorSupportsCustomTemplate() {
    let runner = MockRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let repo = GitRepository(host: "gitlab.com", owner: "group", name: "project")

    let _ = executor.clone(
        repository: repo,
        commandTemplate: "git clone --depth 1 {repo}.git"
    )

    #expect(runner.recordedCommand == "/bin/zsh")
    #expect(runner.recordedArguments == ["-lc", "git clone --depth 1 https://gitlab.com/group/project.git"])
}

@Test
func cloneExecutorLogsFailure() {
    let runner = MockRunner()
    runner.result = CommandExecutionResult(exitCode: 1, standardOutput: "", standardError: "not found")

    let logger = InMemoryLogger()
    let executor = GitC1CloneExecutor(commandRunner: runner, logger: logger)
    let repo = GitHubRepository(owner: "owner", name: "repo")

    let result = executor.clone(repository: repo)

    #expect(!result.isSuccess)
    #expect(logger.entries.count == 3)
    #expect(logger.entries[1].level == .error)
    #expect(logger.entries[1].message.contains("Clone stderr"))
    #expect(logger.entries[1].message.contains("not found"))
    #expect(logger.entries[2].level == .error)
    #expect(logger.entries[2].message.contains("Clone failed"))
}

@Test
func cloneExecutorRunsFromConfiguredDirectory() {
    let runner = MockRunner()
    let executor = GitC1CloneExecutor(commandRunner: runner)
    let repo = GitRepository(host: "gitlab.com", owner: "group", name: "project")
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cbm-clone-\(UUID().uuidString)")
        .appendingPathComponent("with space")
    let path = root.path(percentEncoded: false)
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let _ = executor.clone(
        repository: repo,
        commandTemplate: "git clone {repo}.git",
        cloneDirectoryPath: path
    )

    #expect(runner.recordedCommand == "/bin/zsh")
    #expect(runner.recordedArguments == ["-lc", "cd '\(path)' && git clone https://gitlab.com/group/project.git"])
    #expect(FileManager.default.fileExists(atPath: path))
}

@Test
func cloneExecutorLogsCommandOutputLines() {
    let runner = MockRunner()
    runner.result = CommandExecutionResult(
        exitCode: 0,
        standardOutput: "line1\nline2\n",
        standardError: "warn1\n"
    )

    let logger = InMemoryLogger()
    let executor = GitC1CloneExecutor(commandRunner: runner, logger: logger)
    let repo = GitRepository(host: "gitlab.com", owner: "group", name: "project")

    let result = executor.clone(repository: repo)

    #expect(result.isSuccess)
    #expect(logger.entries.count == 5)
    #expect(logger.entries[1].message.contains("Clone stdout"))
    #expect(logger.entries[1].message.contains("line1"))
    #expect(logger.entries[2].message.contains("Clone stdout"))
    #expect(logger.entries[2].message.contains("line2"))
    #expect(logger.entries[3].message.contains("Clone stderr"))
    #expect(logger.entries[3].message.contains("warn1"))
    #expect(logger.entries[4].message.contains("Clone success"))
}
