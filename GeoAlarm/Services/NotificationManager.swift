import Foundation
import UserNotifications
import os

final class NotificationManager: ObservableObject {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.elias.geoalarm", category: "Notifications")

    @Published var isAuthorized = false

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            logger.info("Notification permission: \(granted)")
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
        }
    }

    /// Schedule notifications for an alarm (called when user enters the alarm's region)
    func scheduleAlarm(_ alarm: Alarm) {
        guard alarm.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "GeoAlarm" : alarm.label
        content.body = "📍 \(alarm.locationName.isEmpty ? "Location alarm" : alarm.locationName)"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        if alarm.repeatDays.isEmpty {
            // One-shot: schedule for this time today (or next occurrence)
            var dateComponents = DateComponents()
            dateComponents.hour = alarm.hour
            dateComponents.minute = alarm.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationId(for: alarm, weekday: nil),
                content: content,
                trigger: trigger
            )
            addRequest(request, label: alarm.label)
        } else {
            // Repeating: one notification per weekday
            for weekday in alarm.repeatDays {
                var dateComponents = DateComponents()
                dateComponents.hour = alarm.hour
                dateComponents.minute = alarm.minute
                dateComponents.weekday = weekday

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: notificationId(for: alarm, weekday: weekday),
                    content: content,
                    trigger: trigger
                )
                addRequest(request, label: "\(alarm.label) (day \(weekday))")
            }
        }
    }

    /// Cancel notifications for an alarm (called when user exits the alarm's region)
    func cancelAlarm(_ alarm: Alarm) {
        var ids = [notificationId(for: alarm, weekday: nil)]
        for weekday in 1...7 {
            ids.append(notificationId(for: alarm, weekday: weekday))
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        logger.info("Cancelled notifications for alarm: \(alarm.label)")
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        logger.info("Cancelled all notifications")
    }

    private func notificationId(for alarm: Alarm, weekday: Int?) -> String {
        if let weekday {
            return "\(alarm.regionIdentifier)-day\(weekday)"
        }
        return "\(alarm.regionIdentifier)-once"
    }

    private func addRequest(_ request: UNNotificationRequest, label: String) {
        center.add(request) { [logger] error in
            if let error {
                logger.error("Failed to schedule '\(label)': \(error.localizedDescription)")
            } else {
                logger.info("Scheduled notification: \(label)")
            }
        }
    }
}
