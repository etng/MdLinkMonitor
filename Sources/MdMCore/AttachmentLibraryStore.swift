import CryptoKit
import Dispatch
import Foundation
import UniformTypeIdentifiers

public enum AttachmentExternalResourceNaming {
    public static func obsidianLocalImagesPlusSignature(for data: Data) -> String {
        let midpoint = Int(round(Double(data.count) / 2.0))
        let chunk = 15_000
        let start = data.prefix(chunk)
        let middle = data.dropFirst(midpoint).prefix(chunk)
        let end = data.suffix(chunk)
        let signatureInput = [start, middle, end]
            .map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: ",")
        return Insecure.MD5.hash(data: Data(signatureInput.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct StoredAttachment: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let md5: String
    public let sourceURL: String
    public let label: String?
    public let contentType: String
    public let fileExtension: String
    public let createdAt: Date
    public let byteCount: Int

    public init(
        id: String,
        md5: String,
        sourceURL: String,
        label: String? = nil,
        contentType: String,
        fileExtension: String,
        createdAt: Date,
        byteCount: Int
    ) {
        self.id = id
        self.md5 = md5
        self.sourceURL = sourceURL
        self.label = label
        self.contentType = contentType
        self.fileExtension = fileExtension
        self.createdAt = createdAt
        self.byteCount = byteCount
    }
}

public struct DownloadedAttachment: Sendable {
    public let data: Data
    public let contentType: String?

    public init(data: Data, contentType: String?) {
        self.data = data
        self.contentType = contentType
    }
}

public protocol AttachmentDownloading: Sendable {
    func download(url: URL) -> DownloadedAttachment?
}

public struct HTTPAttachmentDownloader: AttachmentDownloading {
    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 8.0) {
        self.timeout = timeout
    }

    public func download(url: URL) -> DownloadedAttachment? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.setValue("MdMonitor/1.0", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = DownloadedAttachmentBox()

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard error == nil, let data, !data.isEmpty else {
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }

            let contentType = http.value(forHTTPHeaderField: "Content-Type")?
                .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            resultBox.value = DownloadedAttachment(data: data, contentType: contentType)
        }

        task.resume()

        let deadline = DispatchTime.now() + timeout + 0.5
        if semaphore.wait(timeout: deadline) == .timedOut {
            task.cancel()
        }

        return resultBox.value
    }
}

public struct AttachmentSaveResult: Equatable, Sendable {
    public let attachment: StoredAttachment
    public let wasCreated: Bool

    public init(attachment: StoredAttachment, wasCreated: Bool) {
        self.attachment = attachment
        self.wasCreated = wasCreated
    }
}

public enum AttachmentLibraryError: Error {
    case invalidURL
    case blacklisted
    case downloadFailed
    case unsupportedType
}

public struct AttachmentLibraryStore: @unchecked Sendable {
    private let baseDirectoryURL: URL
    private let fileManager: FileManager
    private let downloader: any AttachmentDownloading

    public init(
        baseDirectoryPath: String,
        fileManager: FileManager = .default,
        downloader: any AttachmentDownloading = HTTPAttachmentDownloader()
    ) {
        self.baseDirectoryURL = URL(filePath: NSString(string: baseDirectoryPath).expandingTildeInPath, directoryHint: .isDirectory)
        self.fileManager = fileManager
        self.downloader = downloader
    }

    public var attachmentsDirectoryURL: URL {
        baseDirectoryURL.appendingPathComponent("attachments", isDirectory: true)
    }

    public func save(from capture: AttachmentCapture, now: Date = Date()) throws -> AttachmentSaveResult {
        guard let normalizedURL = AbsoluteWebURL.normalize(capture.sourceURL),
              let url = URL(string: normalizedURL) else {
            throw AttachmentLibraryError.invalidURL
        }

        let blacklistStore = AttachmentBlacklistStore(baseDirectoryPath: baseDirectoryURL.path(percentEncoded: false))
        if blacklistStore.contains(sourceURL: normalizedURL) {
            throw AttachmentLibraryError.blacklisted
        }

        guard let downloaded = downloader.download(url: url) else {
            throw AttachmentLibraryError.downloadFailed
        }

        let sha1 = Insecure.SHA1.hash(data: downloaded.data).map { String(format: "%02x", $0) }.joined()
        let md5 = Insecure.MD5.hash(data: downloaded.data).map { String(format: "%02x", $0) }.joined()
        let fileExtension = detectFileExtension(contentType: downloaded.contentType, data: downloaded.data)
        let contentType = normalizedContentType(contentType: downloaded.contentType, fileExtension: fileExtension)
        guard let fileExtension else {
            throw AttachmentLibraryError.unsupportedType
        }

        try ensureBaseDirectoryExists()

        let fileURL = attachmentsDirectoryURL.appendingPathComponent("\(sha1).\(fileExtension)")
        let metadataURL = attachmentsDirectoryURL.appendingPathComponent("\(sha1).json")
        let wasCreated = !fileManager.fileExists(atPath: fileURL.path(percentEncoded: false))

        if !wasCreated,
           let existingData = try? Data(contentsOf: metadataURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let existing = try? decoder.decode(StoredAttachment.self, from: existingData) {
                return AttachmentSaveResult(attachment: existing, wasCreated: false)
            }
        }

        if wasCreated {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try downloaded.data.write(to: tempURL, options: .atomic)
            try? fileManager.removeItem(at: fileURL)
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }

        let attachment = StoredAttachment(
            id: sha1,
            md5: md5,
            sourceURL: normalizedURL,
            label: capture.label,
            contentType: contentType,
            fileExtension: fileExtension,
            createdAt: now,
            byteCount: downloaded.data.count
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadataData = try encoder.encode(attachment)
        try metadataData.write(to: metadataURL, options: .atomic)

        return AttachmentSaveResult(attachment: attachment, wasCreated: wasCreated)
    }

    public func listAttachments() -> [StoredAttachment] {
        guard fileManager.fileExists(atPath: attachmentsDirectoryURL.path(percentEncoded: false)),
              let files = try? fileManager.contentsOfDirectory(at: attachmentsDirectoryURL, includingPropertiesForKeys: nil)
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return try? decoder.decode(StoredAttachment.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func fileURL(for attachment: StoredAttachment) -> URL {
        attachmentsDirectoryURL.appendingPathComponent("\(attachment.id).\(attachment.fileExtension)")
    }

    public func blacklistURL(for attachment: StoredAttachment, note: String? = nil) throws {
        try AttachmentBlacklistStore(baseDirectoryPath: baseDirectoryURL.path(percentEncoded: false)).add(
            entry: AttachmentBlacklistEntry(
                sourceURL: attachment.sourceURL,
                md5: attachment.md5,
                addedAt: Date(),
                note: note ?? "deleted from attachment library"
            )
        )
    }

    public func delete(_ attachment: StoredAttachment) {
        try? fileManager.removeItem(at: fileURL(for: attachment))
        try? fileManager.removeItem(at: attachmentsDirectoryURL.appendingPathComponent("\(attachment.id).json"))
    }

    public func findExternalResourceMatches(for attachment: StoredAttachment, resourceDirectoryPath: String) -> [String] {
        let trimmed = resourceDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let rootURL = URL(filePath: NSString(string: trimmed).expandingTildeInPath, directoryHint: .isDirectory)
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        let targetPrefixes = externalResourceNamePrefixes(for: attachment)
        var matches: [String] = []
        let rootComponents = rootURL.resolvingSymlinksInPath().pathComponents

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent.lowercased()
            guard targetPrefixes.contains(where: { fileName.hasPrefix($0) }) else {
                continue
            }
            let fileComponents = fileURL.resolvingSymlinksInPath().pathComponents
            let relativeComponents: ArraySlice<String>
            if fileComponents.starts(with: rootComponents) {
                relativeComponents = fileComponents.dropFirst(rootComponents.count)
            } else {
                relativeComponents = [fileURL.lastPathComponent][...]
            }
            let relative = relativeComponents.joined(separator: "/")
            matches.append(relative)
        }

        return matches.sorted()
    }

    public func externalResourceNamePrefixes(for attachment: StoredAttachment) -> [String] {
        var prefixes = ["\(attachment.md5.lowercased())_md."]
        let attachmentURL = fileURL(for: attachment)
        if let data = try? Data(contentsOf: attachmentURL) {
            let obsidianSig = AttachmentExternalResourceNaming
                .obsidianLocalImagesPlusSignature(for: data)
                .lowercased()
            prefixes.append("\(obsidianSig)_md5.")
        }
        return Array(Set(prefixes)).sorted()
    }

    public func deleteExternalResources(relativePaths: [String], resourceDirectoryPath: String) {
        let trimmed = resourceDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let rootURL = URL(filePath: NSString(string: trimmed).expandingTildeInPath, directoryHint: .isDirectory)
        for relativePath in relativePaths {
            let normalized = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            try? fileManager.removeItem(at: rootURL.appendingPathComponent(normalized))
        }
    }

    private func ensureBaseDirectoryExists() throws {
        try fileManager.createDirectory(at: attachmentsDirectoryURL, withIntermediateDirectories: true)
    }

    private func detectFileExtension(contentType: String?, data: Data) -> String? {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "gif" }
        if data.starts(with: Data("RIFF".utf8)), data.dropFirst(8).starts(with: Data("WEBP".utf8)) { return "webp" }
        if data.starts(with: Data("%PDF".utf8)) { return "pdf" }

        if let contentType,
           let utType = UTType(mimeType: contentType),
           let preferred = utType.preferredFilenameExtension {
            return preferred
        }

        return nil
    }

    private func normalizedContentType(contentType: String?, fileExtension: String?) -> String {
        if let contentType, !contentType.isEmpty {
            return contentType
        }
        if let fileExtension, let utType = UTType(filenameExtension: fileExtension), let mime = utType.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}

private final class DownloadedAttachmentBox: @unchecked Sendable {
    var value: DownloadedAttachment?
}
