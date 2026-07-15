import Foundation

public enum CaptureFeedbackKind: String, Equatable, Sendable {
    case none
    case cloned
    case captured
    case duplicate
    case blocked
    case failed
}

public struct CaptureProcessResult: Sendable {
    public var totalCandidates: Int
    public var appendedCount: Int
    public var attachmentCount: Int
    public var clonedCount: Int
    public var skippedCount: Int
    public var duplicateCount: Int
    public var blockedCount: Int
    public var errors: [String]

    public init(
        totalCandidates: Int,
        appendedCount: Int,
        attachmentCount: Int,
        clonedCount: Int,
        skippedCount: Int,
        duplicateCount: Int = 0,
        blockedCount: Int = 0,
        errors: [String]
    ) {
        self.totalCandidates = totalCandidates
        self.appendedCount = appendedCount
        self.attachmentCount = attachmentCount
        self.clonedCount = clonedCount
        self.skippedCount = skippedCount
        self.duplicateCount = duplicateCount
        self.blockedCount = blockedCount
        self.errors = errors
    }

    public var feedbackKind: CaptureFeedbackKind {
        if !errors.isEmpty, clonedCount == 0 {
            return .failed
        }
        if clonedCount > 0 {
            return .cloned
        }
        if appendedCount > 0 || attachmentCount > 0 {
            return .captured
        }
        if duplicateCount > 0 {
            return .duplicate
        }
        if blockedCount > 0 {
            return .blocked
        }
        return .none
    }

    public static let empty = CaptureProcessResult(
        totalCandidates: 0,
        appendedCount: 0,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 0,
        errors: []
    )
}

public final class ClipboardCaptureOrchestrator: @unchecked Sendable {
    private let logger: (any Logging)?
    private let cloneExecutor: GitC1CloneExecutor
    private let metadataFetcher: any LinkMetadataFetching
    private let attachmentDownloader: any AttachmentDownloading

    public init(
        cloneExecutor: GitC1CloneExecutor = GitC1CloneExecutor(),
        logger: (any Logging)? = nil,
        metadataFetcher: any LinkMetadataFetching = HTTPLinkMetadataFetcher(),
        attachmentDownloader: any AttachmentDownloading = HTTPAttachmentDownloader()
    ) {
        self.cloneExecutor = cloneExecutor
        self.logger = logger
        self.metadataFetcher = metadataFetcher
        self.attachmentDownloader = attachmentDownloader
    }

    public func process(
        clipboardText: String,
        allowMultipleLinks: Bool,
        repositoryDomains: Set<String>,
        metadataAllowedDomains: Set<String> = [],
        cloneCommandTemplate: String = AppSettings.defaultCloneCommandTemplate,
        cloneDirectoryPath: String? = nil,
        store: DailyMarkdownStore,
        date: Date = Date()
    ) -> CaptureProcessResult {
        let captures = ClipboardContentProcessor.extractCaptures(
            from: clipboardText,
            allowMultipleLinks: allowMultipleLinks,
            repositoryDomains: repositoryDomains,
            metadataAllowedDomains: metadataAllowedDomains,
            metadataFetcher: metadataFetcher
        )
        guard !captures.isEmpty else {
            return .empty
        }

        var result = CaptureProcessResult(
            totalCandidates: captures.count,
            appendedCount: 0,
            attachmentCount: 0,
            clonedCount: 0,
            skippedCount: 0,
            errors: []
        )

        let attachmentStore = AttachmentLibraryStore(
            baseDirectoryPath: store.baseDirectory.path(percentEncoded: false),
            downloader: attachmentDownloader
        )

        for capture in captures {
            do {
                switch capture {
                case .link(let link):
                    let appended = try store.appendIfNeeded(
                        label: link.label,
                        linkURL: link.markdownURL,
                        annotation: link.annotation,
                        dedupKey: link.dedupKey,
                        date: date
                    )
                    if appended {
                        result.appendedCount += 1
                        let filePath = store.fileURL(for: date).path(percentEncoded: false)
                        logger?.log(.info, "Appended markdown entry: \(filePath) [\(link.markdownURL)]")

                        if let repository = link.repository {
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
                            logger?.log(.info, "Skip clone for non-repository link: \(link.url)")
                        }
                    } else {
                        result.skippedCount += 1
                        result.duplicateCount += 1
                        logger?.log(.info, "Skip duplicate for day: \(link.dedupKey)")
                    }
                case .attachment(let attachment):
                    do {
                        let saveResult = try attachmentStore.save(from: attachment, now: date)
                        if saveResult.wasCreated {
                            result.attachmentCount += 1
                            logger?.log(.info, "Saved attachment: \(attachment.sourceURL) -> \(attachmentStore.fileURL(for: saveResult.attachment).path(percentEncoded: false))")
                        } else {
                            result.skippedCount += 1
                            result.duplicateCount += 1
                            logger?.log(.info, "Skip duplicate attachment: \(attachment.sourceURL)")
                        }
                    } catch AttachmentLibraryError.blacklisted {
                        result.skippedCount += 1
                        result.blockedCount += 1
                        logger?.log(.info, "Skip blacklisted attachment: \(attachment.sourceURL)")
                    } catch {
                        throw error
                    }
                }
            } catch {
                result.errors.append(error.localizedDescription)
                logger?.log(.error, "Process error: \(error.localizedDescription)")
            }
        }

        return result
    }
}
