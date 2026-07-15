import AppKit
import MdMCore
import SwiftUI

@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {
    private var mainWindow: NSWindow?

    private struct PinStyle {
        let isPinned: Bool
        let pinnedOpacity: Double
        let clickThroughWhenPinned: Bool
    }

    private var currentPinStyle = PinStyle(
        isPinned: false,
        pinnedOpacity: AppSettings.defaultPinnedWindowOpacity,
        clickThroughWhenPinned: false
    )

    func showMainWindow(
        initialFilePath: String,
        model: MenuBarViewModel
    ) {
        let title = "Markdown Monitor"
        let root = AnyView(
            MainWindowView(
                initialFilePath: initialFilePath,
                model: model
            )
        )

        if let window = mainWindow,
           let hosting = window.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = root
            window.title = title
            applyPinStyle(to: window, style: currentPinStyle)
            activateAndShow(window)
            return
        }

        let window = makeWindow(title: title, size: NSSize(width: 860, height: 620), rootView: root)
        applyPinStyle(to: window, style: currentPinStyle)
        mainWindow = window
        activateAndShow(window)
    }

    func updateMainWindowPinState(
        isPinned: Bool,
        pinnedOpacity: Double,
        clickThroughWhenPinned: Bool
    ) {
        currentPinStyle = PinStyle(
            isPinned: isPinned,
            pinnedOpacity: max(0.40, min(pinnedOpacity, 1.00)),
            clickThroughWhenPinned: clickThroughWhenPinned
        )

        guard let window = mainWindow else { return }
        applyPinStyle(to: window, style: currentPinStyle)
    }

    func previewMainWindowPinState(
        isPinned: Bool,
        pinnedOpacity: Double,
        clickThroughWhenPinned: Bool
    ) {
        guard let window = mainWindow else { return }
        if window.styleMask.contains(.fullScreen) {
            applyFullScreenWindowStyle(window)
            return
        }

        let clampedOpacity = max(0.40, min(pinnedOpacity, 1.00))
        if isPinned {
            applyPinStyle(
                to: window,
                style: PinStyle(
                    isPinned: true,
                    pinnedOpacity: clampedOpacity,
                    clickThroughWhenPinned: clickThroughWhenPinned
                )
            )
            return
        }

        // Unpinned preview: keep normal level and interaction, only preview opacity.
        window.level = .normal
        window.alphaValue = clampedOpacity
        window.ignoresMouseEvents = false
        window.collectionBehavior.remove(.fullScreenAuxiliary)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing == mainWindow {
            mainWindow = nil
        }
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        applyFullScreenWindowStyle(window)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        applyFullScreenWindowStyle(window)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        applyPinStyle(to: window, style: currentPinStyle)
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
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: rootView)
        return window
    }

    private func applyPinStyle(to window: NSWindow, style: PinStyle) {
        if window.styleMask.contains(.fullScreen) {
            applyFullScreenWindowStyle(window)
            return
        }

        if style.isPinned {
            window.level = .floating
            window.alphaValue = style.pinnedOpacity
            window.ignoresMouseEvents = style.clickThroughWhenPinned
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        } else {
            window.level = .normal
            window.alphaValue = 1.0
            window.ignoresMouseEvents = false
            window.collectionBehavior.remove(.fullScreenAuxiliary)
        }
    }

    private func applyFullScreenWindowStyle(_ window: NSWindow) {
        window.level = .normal
        window.alphaValue = 1.0
        window.ignoresMouseEvents = false
        window.collectionBehavior.remove(.fullScreenAuxiliary)
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
