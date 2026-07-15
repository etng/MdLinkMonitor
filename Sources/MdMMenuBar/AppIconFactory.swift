import AppKit
import MdMCore

enum AppIconFactory {
    private enum Style {
        case menuBar
        case dock
        case menuBarCloned
        case menuBarCaptured
        case menuBarDuplicate
        case menuBarBlocked
        case menuBarFailed
    }

    private static let dockCached = makeIcon(size: 512, style: .dock)
    private static let menuCached = makeIcon(size: 20, style: .menuBar)
    private static let menuClonedCached = makeIcon(size: 20, style: .menuBarCloned)
    private static let menuCapturedCached = makeIcon(size: 20, style: .menuBarCaptured)
    private static let menuDuplicateCached = makeIcon(size: 20, style: .menuBarDuplicate)
    private static let menuBlockedCached = makeIcon(size: 20, style: .menuBarBlocked)
    private static let menuFailedCached = makeIcon(size: 20, style: .menuBarFailed)

    static func dockIcon() -> NSImage {
        dockCached
    }

    static func menuBarIcon(feedback: CaptureFeedbackKind = .none) -> NSImage {
        switch feedback {
        case .none:
            return menuCached
        case .cloned:
            return menuClonedCached
        case .captured:
            return menuCapturedCached
        case .duplicate:
            return menuDuplicateCached
        case .blocked:
            return menuBlockedCached
        case .failed:
            return menuFailedCached
        }
    }

    static func menuBarFeedbackColor(for feedback: CaptureFeedbackKind) -> NSColor? {
        switch feedback {
        case .none:
            return nil
        case .cloned:
            return NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.42, alpha: 1.0)
        case .captured:
            return NSColor(calibratedRed: 0.14, green: 0.48, blue: 0.84, alpha: 1.0)
        case .duplicate:
            return NSColor(calibratedRed: 0.88, green: 0.56, blue: 0.16, alpha: 1.0)
        case .blocked:
            return NSColor(calibratedRed: 0.58, green: 0.54, blue: 0.44, alpha: 1.0)
        case .failed:
            return NSColor(calibratedRed: 0.80, green: 0.31, blue: 0.28, alpha: 1.0)
        }
    }

    private static func makeIcon(size: CGFloat, style: Style) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let fullRect = NSRect(x: 0, y: 0, width: size, height: size)

        if style == .dock {
            let bgRect = fullRect.insetBy(dx: size * 0.04, dy: size * 0.04)
            let bg = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.20, yRadius: size * 0.20)
            NSColor(calibratedRed: 0.15, green: 0.48, blue: 0.87, alpha: 1.0).setFill()
            bg.fill()
        }

        let strokeColor: NSColor
        let fillColor: NSColor
        let detailColor: NSColor

        if let feedback = feedbackKind(for: style),
           let accentColor = menuBarFeedbackColor(for: feedback) {
            strokeColor = accentColor
            fillColor = accentColor.withAlphaComponent(menuBarFeedbackFillAlpha(for: feedback))
            detailColor = accentColor
        } else {
            switch style {
            case .dock:
                strokeColor = NSColor(calibratedWhite: 0.96, alpha: 1.0)
                fillColor = NSColor(calibratedWhite: 0.98, alpha: 0.95)
                detailColor = NSColor(calibratedRed: 0.10, green: 0.33, blue: 0.66, alpha: 1.0)
            case .menuBar:
                strokeColor = .labelColor
                fillColor = .clear
                detailColor = .labelColor
            case .menuBarCloned, .menuBarCaptured, .menuBarDuplicate, .menuBarBlocked, .menuBarFailed:
                preconditionFailure("Feedback styles must resolve through feedbackKind(for:)")
            }
        }

        let boardRect = NSRect(
            x: size * 0.20,
            y: size * 0.16,
            width: size * 0.60,
            height: size * 0.70
        )
        let boardPath = NSBezierPath(roundedRect: boardRect, xRadius: size * 0.09, yRadius: size * 0.09)
        boardPath.lineWidth = max(1, size * 0.045)
        fillColor.setFill()
        boardPath.fill()
        strokeColor.setStroke()
        boardPath.stroke()

        let clipRect = NSRect(
            x: size * 0.36,
            y: size * 0.80,
            width: size * 0.28,
            height: size * 0.14
        )
        let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: size * 0.06, yRadius: size * 0.06)
        clipPath.lineWidth = max(1, size * 0.045)
        fillColor.setFill()
        clipPath.fill()
        strokeColor.setStroke()
        clipPath.stroke()

        // Markdown signal: stylized "M" + rule lines inside clipboard.
        let m = NSBezierPath()
        m.lineCapStyle = .round
        m.lineJoinStyle = .round
        m.lineWidth = max(1, size * 0.06)
        m.move(to: NSPoint(x: size * 0.29, y: size * 0.36))
        m.line(to: NSPoint(x: size * 0.33, y: size * 0.58))
        m.line(to: NSPoint(x: size * 0.40, y: size * 0.44))
        m.line(to: NSPoint(x: size * 0.47, y: size * 0.58))
        m.line(to: NSPoint(x: size * 0.52, y: size * 0.36))
        detailColor.setStroke()
        m.stroke()

        let line1 = NSBezierPath()
        line1.lineCapStyle = .round
        line1.lineWidth = max(1, size * 0.040)
        line1.move(to: NSPoint(x: size * 0.56, y: size * 0.56))
        line1.line(to: NSPoint(x: size * 0.72, y: size * 0.56))
        detailColor.setStroke()
        line1.stroke()

        let line2 = NSBezierPath()
        line2.lineCapStyle = .round
        line2.lineWidth = max(1, size * 0.040)
        line2.move(to: NSPoint(x: size * 0.56, y: size * 0.43))
        line2.line(to: NSPoint(x: size * 0.69, y: size * 0.43))
        detailColor.setStroke()
        line2.stroke()

        image.isTemplate = (style == .menuBar)
        return image
    }

    private static func feedbackKind(for style: Style) -> CaptureFeedbackKind? {
        switch style {
        case .menuBarCloned:
            return .cloned
        case .menuBarCaptured:
            return .captured
        case .menuBarDuplicate:
            return .duplicate
        case .menuBarBlocked:
            return .blocked
        case .menuBarFailed:
            return .failed
        case .dock, .menuBar:
            return nil
        }
    }

    private static func menuBarFeedbackFillAlpha(for feedback: CaptureFeedbackKind) -> CGFloat {
        switch feedback {
        case .duplicate:
            return 0.14
        case .blocked:
            return 0.13
        case .cloned, .captured, .failed:
            return 0.12
        case .none:
            return 0.0
        }
    }
}
