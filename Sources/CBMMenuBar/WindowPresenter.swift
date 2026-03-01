import AppKit
import CBMCore
import SwiftUI

@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    private var previewWindow: NSWindow?

    func showPreview(
        initialFilePath: String,
        model: MenuBarViewModel,
        initialPanel: PreviewPanelDestination = .preview
    ) {
        let title = "Markdown Monitor"
        let root = AnyView(
            MarkdownPreviewView(
                initialFilePath: initialFilePath,
                model: model,
                initialPanel: initialPanel
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
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        if !window.isVisible {
            window.orderFront(nil)
        }
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}
