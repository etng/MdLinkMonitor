import AppKit
import Foundation
@preconcurrency import ApplicationServices

public final class AutoMergeWindowsManager: @unchecked Sendable {
    private let workspaceCenter = NSWorkspace.shared.notificationCenter
    private let logger: @Sendable (String) -> Void
    private let subscribeAXCreatedNotification: Bool

    private var workspaceObservers: [NSObjectProtocol] = []
    private var axObservers: [pid_t: AXObserver] = [:]
    private var pendingMergeAttempts: [pid_t: DispatchWorkItem] = [:]
    private var configuration = Configuration()
    private var hasLoggedAccessibilityDisabled = false

    private let windowMenuTitles = ["Window", "窗口"]
    private let mergeMenuTitles = ["Merge All Windows", "合并所有窗口"]

    public init(
        subscribeAXCreatedNotification: Bool = true,
        logger: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.subscribeAXCreatedNotification = subscribeAXCreatedNotification
        self.logger = logger
    }

    public func apply(enabled: Bool, targetBundleIDs: [String]) {
        let next = Configuration(enabled: enabled, targetBundleIDs: targetBundleIDs)
        guard next != configuration else {
            return
        }

        configuration = next
        stopRuntime()

        guard configuration.enabled else {
            return
        }

        ensureAccessibilityPermissionPrompted()
        registerWorkspaceNotifications()
        attachObserversToRunningApps()

        if let app = NSWorkspace.shared.frontmostApplication, shouldObserve(app) {
            scheduleMergeAttempt(for: app.processIdentifier, reason: "configuration")
        }

        if configuration.targetBundleIDs.isEmpty {
            log("Auto-merge enabled, bundleIds=<all>")
        } else {
            let joined = configuration.targetBundleIDs.sorted().joined(separator: ",")
            log("Auto-merge enabled, bundleIds=\(joined)")
        }
    }

    public func stop() {
        stopRuntime()
    }

    private func stopRuntime() {
        workspaceObservers.forEach { workspaceCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        hasLoggedAccessibilityDisabled = false

        pendingMergeAttempts.values.forEach { $0.cancel() }
        pendingMergeAttempts.removeAll()

        for observer in axObservers.values {
            let source = AXObserverGetRunLoopSource(observer)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        axObservers.removeAll()
    }

    private func ensureAccessibilityPermissionPrompted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        _ = guardAccessibilityAvailable(context: "startup")
    }

    private func registerWorkspaceNotifications() {
        let launchObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLifecycle(notification: notification, reason: "didLaunch")
        }

        let activateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLifecycle(notification: notification, reason: "didActivate")
        }

        let terminateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppTermination(notification: notification)
        }

        workspaceObservers = [launchObserver, activateObserver, terminateObserver]
    }

    private func attachObserversToRunningApps() {
        for app in NSWorkspace.shared.runningApplications where shouldObserve(app) {
            addAXObserverIfNeeded(for: app)
            scheduleMergeAttempt(for: app.processIdentifier, reason: "initialRunningApp")
        }
    }

    private func handleAppLifecycle(notification: Notification, reason: String) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            shouldObserve(app)
        else {
            return
        }

        addAXObserverIfNeeded(for: app)
        scheduleMergeAttempt(for: app.processIdentifier, reason: reason)
    }

    private func handleAppTermination(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        removeAXObserver(for: app.processIdentifier)
        pendingMergeAttempts[app.processIdentifier]?.cancel()
        pendingMergeAttempts[app.processIdentifier] = nil
    }

    private func shouldObserve(_ app: NSRunningApplication) -> Bool {
        guard configuration.enabled, app.processIdentifier > 0 else {
            return false
        }

        if configuration.targetBundleIDs.isEmpty {
            return true
        }

        guard let bundleID = app.bundleIdentifier else {
            return false
        }
        return configuration.targetBundleIDs.contains(bundleID)
    }

    private func addAXObserverIfNeeded(for app: NSRunningApplication) {
        guard guardAccessibilityAvailable(context: "observer setup") else {
            return
        }

        let pid = app.processIdentifier
        guard axObservers[pid] == nil else {
            return
        }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, Self.axObserverCallback, &observer)
        guard result == .success, let observer else {
            log("AXObserverCreate failed pid=\(pid) app=\(describe(app)) error=\(describe(result))")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [CFString] = subscribeAXCreatedNotification
            ? [kAXWindowCreatedNotification as CFString, kAXCreatedNotification as CFString]
            : [kAXWindowCreatedNotification as CFString]

        var subscribedAtLeastOne = false
        for notification in notifications {
            let addResult = AXObserverAddNotification(observer, appElement, notification, refcon)
            switch addResult {
            case .success, .notificationAlreadyRegistered:
                subscribedAtLeastOne = true
            default:
                log(
                    "AXObserverAddNotification failed pid=\(pid) app=\(describe(app)) notif=\(notification) error=\(describe(addResult))"
                )
            }
        }

        guard subscribedAtLeastOne else {
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        axObservers[pid] = observer
    }

    private func removeAXObserver(for pid: pid_t) {
        guard let observer = axObservers.removeValue(forKey: pid) else {
            return
        }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func scheduleMergeAttempt(for pid: pid_t, reason: String) {
        pendingMergeAttempts[pid]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.attemptMergeWithRetry(pid: pid, reason: reason)
        }

        pendingMergeAttempts[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func attemptMergeWithRetry(pid: pid_t, reason: String) {
        pendingMergeAttempts[pid] = nil

        guard let app = NSRunningApplication(processIdentifier: pid), shouldObserve(app) else {
            return
        }
        guard guardAccessibilityAvailable(context: "merge attempt") else {
            return
        }

        if executeMergeAllWindows(for: pid) {
            log("Merge triggered pid=\(pid) app=\(describe(app)) reason=\(reason)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else {
                return
            }
            guard let retryApp = NSRunningApplication(processIdentifier: pid), self.shouldObserve(retryApp) else {
                return
            }
            guard self.guardAccessibilityAvailable(context: "merge retry") else {
                return
            }
            if self.executeMergeAllWindows(for: pid) {
                self.log("Merge triggered on retry pid=\(pid) app=\(self.describe(retryApp)) reason=\(reason)")
            }
        }
    }

    private func executeMergeAllWindows(for pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(appElement, 1.5)

        guard let menuBar = copyElementAttribute(appElement, attribute: kAXMenuBarAttribute as CFString) else {
            return false
        }

        for menuBarItem in copyElementArrayAttribute(menuBar, attribute: kAXChildrenAttribute as CFString) {
            guard
                let title = copyStringAttribute(menuBarItem, attribute: kAXTitleAttribute as CFString),
                windowMenuTitles.contains(title)
            else {
                continue
            }

            guard let menu = extractMenuElement(from: menuBarItem) else {
                continue
            }

            if pressMergeItemIfEnabled(in: menu) {
                return true
            }
        }

        return false
    }

    private func guardAccessibilityAvailable(context: String) -> Bool {
        guard AXIsProcessTrusted() else {
            if !hasLoggedAccessibilityDisabled {
                log(
                    "Accessibility API disabled during \(context). Please allow the current process in System Settings -> Privacy & Security -> Accessibility"
                )
                hasLoggedAccessibilityDisabled = true
            }
            return false
        }

        hasLoggedAccessibilityDisabled = false
        return true
    }

    private func extractMenuElement(from menuBarItem: AXUIElement) -> AXUIElement? {
        for child in copyElementArrayAttribute(menuBarItem, attribute: kAXChildrenAttribute as CFString) {
            if let role = copyStringAttribute(child, attribute: kAXRoleAttribute as CFString), role == kAXMenuRole as String {
                return child
            }
        }
        return nil
    }

    private func pressMergeItemIfEnabled(in menu: AXUIElement) -> Bool {
        for item in copyElementArrayAttribute(menu, attribute: kAXChildrenAttribute as CFString) {
            guard
                let title = copyStringAttribute(item, attribute: kAXTitleAttribute as CFString),
                mergeMenuTitles.contains(title)
            else {
                continue
            }

            guard copyBoolAttribute(item, attribute: kAXEnabledAttribute as CFString) else {
                return false
            }

            return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
        }

        return false
    }

    private func copyElementAttribute(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyElementArrayAttribute(_ element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let elements = value as? [AXUIElement] else {
            return []
        }
        return elements
    }

    private func copyStringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private func copyBoolAttribute(_ element: AXUIElement, attribute: CFString) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    private func log(_ message: String) {
        logger("[auto-merge] \(message)")
    }

    private func describe(_ app: NSRunningApplication) -> String {
        let bundleID = app.bundleIdentifier ?? "<unknown>"
        let name = app.localizedName ?? "<unknown>"
        return "\(name) (\(bundleID))"
    }

    private func describe(_ error: AXError) -> String {
        switch error {
        case .success:
            return "success(0)"
        case .failure:
            return "failure(-25200)"
        case .illegalArgument:
            return "illegalArgument(-25201)"
        case .invalidUIElement:
            return "invalidUIElement(-25202)"
        case .invalidUIElementObserver:
            return "invalidUIElementObserver(-25203)"
        case .cannotComplete:
            return "cannotComplete(-25204)"
        case .attributeUnsupported:
            return "attributeUnsupported(-25205)"
        case .actionUnsupported:
            return "actionUnsupported(-25206)"
        case .notificationUnsupported:
            return "notificationUnsupported(-25207)"
        case .notImplemented:
            return "notImplemented(-25208)"
        case .notificationAlreadyRegistered:
            return "notificationAlreadyRegistered(-25209)"
        case .notificationNotRegistered:
            return "notificationNotRegistered(-25210)"
        case .apiDisabled:
            return "apiDisabled(-25211)"
        case .noValue:
            return "noValue(-25212)"
        case .parameterizedAttributeUnsupported:
            return "parameterizedAttributeUnsupported(-25213)"
        case .notEnoughPrecision:
            return "notEnoughPrecision(-25214)"
        @unknown default:
            return "unknown(\(error.rawValue))"
        }
    }

    private static let axObserverCallback: AXObserverCallback = { _, element, notification, refcon in
        guard let refcon else {
            return
        }

        let manager = Unmanaged<AutoMergeWindowsManager>.fromOpaque(refcon).takeUnretainedValue()
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) != .success {
            return
        }

        manager.scheduleMergeAttempt(for: pid, reason: notification as String)
    }
}

private struct Configuration: Equatable {
    var enabled: Bool = false
    var targetBundleIDs: Set<String> = []

    init(enabled: Bool = false, targetBundleIDs: [String] = []) {
        self.enabled = enabled
        self.targetBundleIDs = Set(
            targetBundleIDs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
