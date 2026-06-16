import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func postUsageAlert(threshold: Int, usedPercent: Int, resetText: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Cursor usage at \(usedPercent)%"
        if threshold >= 90 {
            content.subtitle = "Almost at your limit"
            content.body = resetText.map { "You've used most of this billing period. \($0)." }
                ?? "You've used most of this billing period."
        } else {
            content.subtitle = "Getting close"
            content.body = resetText.map { "Past 70% for this cycle. \($0)." }
                ?? "Past 70% for this billing cycle."
        }
        deliver(content, identifier: "usage-alert-\(threshold)")
    }

    static func postEvolution(name: String, stageName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Cursor Gotchi evolved!"
        content.subtitle = stageName
        content.body = "\(name) reached \(stageName)"
        deliver(content, identifier: "evolution-\(UUID().uuidString)")
    }

    private static func deliver(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
