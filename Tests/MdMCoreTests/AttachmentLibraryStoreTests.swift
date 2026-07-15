import Foundation
import Testing
@testable import MdMCore

private struct MockAttachmentDownloader: AttachmentDownloading {
    let response: DownloadedAttachment?

    func download(url: URL) -> DownloadedAttachment? {
        response
    }
}

@Test
func attachmentSaveStoresMD5AndBlacklistSkipsRedownload() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
    let store = AttachmentLibraryStore(
        baseDirectoryPath: tempRoot.path(percentEncoded: false),
        downloader: MockAttachmentDownloader(response: DownloadedAttachment(data: imageData, contentType: "image/jpeg"))
    )
    let capture = AttachmentCapture(sourceURL: "https://mmbiz.qpic.cn/sz_mmbiz_jpg/example/640?wx_fmt=jpeg", label: "图片")

    let first = try store.save(from: capture, now: Date(timeIntervalSince1970: 1_700_000_000))
    #expect(first.wasCreated)
    #expect(first.attachment.md5.count == 32)

    try store.blacklistURL(for: first.attachment)

    #expect(throws: AttachmentLibraryError.blacklisted) {
        _ = try store.save(from: capture, now: Date(timeIntervalSince1970: 1_700_000_001))
    }
}

@Test
func attachmentStoreFindsExternalResourceMatchesByMD5() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let resourcesRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
        try? FileManager.default.removeItem(at: resourcesRoot)
    }

    let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
    let store = AttachmentLibraryStore(
        baseDirectoryPath: tempRoot.path(percentEncoded: false),
        downloader: MockAttachmentDownloader(response: DownloadedAttachment(data: imageData, contentType: "image/jpeg"))
    )
    let capture = AttachmentCapture(sourceURL: "https://mmbiz.qpic.cn/sz_mmbiz_jpg/example/640?wx_fmt=jpeg", label: "图片")
    let saved = try store.save(from: capture)

    let nested = resourcesRoot.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let matchURL = nested.appendingPathComponent("\(saved.attachment.md5)_MD.jpg")
    try Data("x".utf8).write(to: matchURL)

    let matches = store.findExternalResourceMatches(
        for: saved.attachment,
        resourceDirectoryPath: resourcesRoot.path(percentEncoded: false)
    )

    #expect(matches == ["nested/\(saved.attachment.md5)_MD.jpg"])
}

@Test
func attachmentStoreFindsExternalResourceMatchesByObsidianLocalImagesPlusSignature() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let resourcesRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
        try? FileManager.default.removeItem(at: resourcesRoot)
    }

    let imageData = Data("RIFF-webp-like-demo".utf8)
    let store = AttachmentLibraryStore(
        baseDirectoryPath: tempRoot.path(percentEncoded: false),
        downloader: MockAttachmentDownloader(response: DownloadedAttachment(data: imageData, contentType: "image/webp"))
    )
    let capture = AttachmentCapture(sourceURL: "https://mmbiz.qpic.cn/example/demo.webp", label: "图片")
    let saved = try store.save(from: capture)

    let signature = AttachmentExternalResourceNaming.obsidianLocalImagesPlusSignature(for: imageData)
    let nested = resourcesRoot.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let matchURL = nested.appendingPathComponent("\(signature)_MD5.webp")
    try Data("x".utf8).write(to: matchURL)

    let matches = store.findExternalResourceMatches(
        for: saved.attachment,
        resourceDirectoryPath: resourcesRoot.path(percentEncoded: false)
    )

    #expect(matches == ["nested/\(signature)_MD5.webp"])
}
