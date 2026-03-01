import AppKit
import CBMCore
import SwiftUI

@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    private var aboutWindow: NSWindow?
    private var previewWindow: NSWindow?

    func showAbout(language: AppLanguage) {
        let title = language == .zhHans ? "关于 CBM" : "About CBM"
        let root = AnyView(AboutView(language: language))

        if let window = aboutWindow,
           let hosting = window.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = root
            window.title = title
            activateAndShow(window)
            return
        }

        let window = makeWindow(title: title, size: NSSize(width: 420, height: 220), rootView: root)
        aboutWindow = window
        activateAndShow(window)
    }

    func showPreview(initialFilePath: String, outputDirectoryPath: String, language: AppLanguage) {
        let title = language == .zhHans ? "Markdown 预览" : "Markdown Preview"
        let root = AnyView(
            MarkdownPreviewView(
                initialFilePath: initialFilePath,
                outputDirectoryPath: outputDirectoryPath,
                language: language
            )
        )

        if let window = previewWindow,
           let hosting = window.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = root
            window.title = title
            activateAndShow(window)
            return
        }

        let window = makeWindow(title: title, size: NSSize(width: 860, height: 620), rootView: root)
        previewWindow = window
        activateAndShow(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing == aboutWindow {
            aboutWindow = nil
        }
        if closing == previewWindow {
            previewWindow = nil
        }
    }

    private func makeWindow(title: String, size: NSSize, rootView: AnyView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: rootView)
        return window
    }

    private func activateAndShow(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
