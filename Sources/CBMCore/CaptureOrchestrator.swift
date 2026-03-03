import Foundation

public struct CaptureProcessResult: Sendable {
    public var totalCandidates: Int
    public var appendedCount: Int
    public var clonedCount: Int
    public var skippedCount: Int
    public var errors: [String]

    public init(totalCandidates: Int, appendedCount: Int, clonedCount: Int, skippedCount: Int, errors: [String]) {
        self.totalCandidates = totalCandidates
        self.appendedCount = appendedCount
        self.clonedCount = clonedCount
        self.skippedCount = skippedCount
        self.errors = errors
    }

    public static let empty = CaptureProcessResult(totalCandidates: 0, appendedCount: 0, clonedCount: 0, skippedCount: 0, errors: [])
}

public final class ClipboardCaptureOrchestrator: @unchecked Sendable {
    private let logger: (any Logging)?
    private let cloneExecutor: GitC1CloneExecutor

    public init(cloneExecutor: GitC1CloneExecutor = GitC1CloneExecutor(), logger: (any Logging)? = nil) {
        self.cloneExecutor = cloneExecutor
        self.logger = logger
    }

    public func process(
        clipboardText: String,
        allowMultipleLinks: Bool,
        repositoryDomains: Set<String>,
        cloneCommandTemplate: String = AppSettings.defaultCloneCommandTemplate,
        cloneDirectoryPath: String? = nil,
        store: DailyMarkdownStore,
        date: Date = Date()
    ) -> CaptureProcessResult {
        let captures = ClipboardContentProcessor.extractLinkCaptures(
            from: clipboardText,
            allowMultipleLinks: allowMultipleLinks,
            repositoryDomains: repositoryDomains
        )
        guard !captures.isEmpty else {
            return .empty
        }

        var result = CaptureProcessResult(
            totalCandidates: captures.count,
            appendedCount: 0,
            clonedCount: 0,
            skippedCount: 0,
            errors: []
        )

        for capture in captures {
            do {
                let appended = try store.appendIfNeeded(
                    label: capture.label,
                    linkURL: capture.markdownURL,
                    dedupKey: capture.dedupKey,
                    date: date
                )
                if appended {
                    result.appendedCount += 1
                    let filePath = store.fileURL(for: date).path(percentEncoded: false)
                    logger?.log(.info, "Appended markdown entry: \(filePath) [\(capture.markdownURL)]")

                    if let repository = capture.repository {
                        let cloneResult = cloneExecutor.clone(
                            repository: repository,
                            commandTemplate: cloneCommandTemplate,
                            cloneDirectoryPath: cloneDirectoryPath
                        )
                        if cloneResult.isSuccess {
                            result.clonedCount += 1
                        } else {
                            result.errors.append("Clone failed: \(repository.cloneURL)")
                        }
                    } else {
                        logger?.log(.info, "Skip clone for non-repository link: \(capture.url)")
                    }
                } else {
                    result.skippedCount += 1
                    logger?.log(.info, "Skip duplicate for day: \(capture.dedupKey)")
                }
            } catch {
                result.errors.append(error.localizedDescription)
                logger?.log(.error, "Process error: \(error.localizedDescription)")
            }
        }

        return result
    }
}
