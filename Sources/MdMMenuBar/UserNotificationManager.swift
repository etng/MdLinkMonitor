import Foundation
@preconcurrency import UserNotifications

protocol UserNotifying {
    func notify(title: String, body: String)
}

final class UserNotificationManager: UserNotifying {
    init() {}

    func notify(title: String, body: String) {
        guard Self.canUseSystemNotifications else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Self.enqueue(center: center, title: title, body: body)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    Self.enqueue(center: center, title: title, body: body)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private static var canUseSystemNotifications: Bool {
        let url = Bundle.main.bundleURL
        return url.pathExtension.lowercased() == "app" && Bundle.main.bundleIdentifier != nil
    }

    private static func enqueue(center: UNUserNotificationCenter, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
