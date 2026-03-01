import AppKit
import Foundation

public protocol ClipboardTextProviding {
    var changeCount: Int { get }
    func readString() -> String?
}

public struct SystemClipboardProvider: ClipboardTextProviding {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public func readString() -> String? {
        pasteboard.string(forType: .string)
    }
}

public final class ClipboardMonitor {
    private let provider: any ClipboardTextProviding
    private let interval: TimeInterval
    private let onClipboardText: (String) -> Void

    private var timer: Timer?
    private var lastChangeCount: Int

    public var isEnabled = false

    public init(
        provider: any ClipboardTextProviding = SystemClipboardProvider(),
        interval: TimeInterval = 0.8,
        onClipboardText: @escaping (String) -> Void
    ) {
        self.provider = provider
        self.interval = interval
        self.onClipboardText = onClipboardText
        self.lastChangeCount = provider.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    public func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func tick() {
        guard isEnabled else {
            return
        }

        let current = provider.changeCount
        guard current != lastChangeCount else {
            return
        }

        lastChangeCount = current
        guard let text = provider.readString(), !text.isEmpty else {
            return
        }

        onClipboardText(text)
    }
}
