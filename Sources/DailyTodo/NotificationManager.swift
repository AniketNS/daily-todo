import AppKit
import UserNotifications

enum ReminderKind: String {
    case morning, evening, hourly
}

/// Thin wrapper around UNUserNotificationCenter for the "notification banners instead
/// of a blocking popup" preference. Posts a summary banner; clicking it opens the same
/// panel the blocking-popup mode would have shown, via the matching `onOpen*` callback.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var onOpenMorning: (() -> Void)?
    var onOpenEvening: (() -> Void)?
    var onOpenHourly: (() -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(kind: ReminderKind, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if PreferencesStore.shared.preferences.soundEnabled {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: "\(kind.rawValue)-\(UUID().uuidString)", content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        DispatchQueue.main.async { [weak self] in
            if id.hasPrefix(ReminderKind.morning.rawValue) {
                self?.onOpenMorning?()
            } else if id.hasPrefix(ReminderKind.evening.rawValue) {
                self?.onOpenEvening?()
            } else if id.hasPrefix(ReminderKind.hourly.rawValue) {
                self?.onOpenHourly?()
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
