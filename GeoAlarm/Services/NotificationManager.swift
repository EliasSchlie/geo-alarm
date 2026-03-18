import Foundation
import UserNotifications
import os

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.elias.geoalarm", category: "Notifications")

    static let snoozeActionId = "SNOOZE_ACTION"
    static let dismissActionId = "DISMISS_ACTION"
    static let alarmCategoryId = "ALARM_CATEGORY"

    @Published var isAuthorized = false
    @Published var activeAlarmLabel: String?
    @Published var activeAlarmSound: String?

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
        checkCurrentAuthorization()
    }

    private func checkCurrentAuthorization() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            logger.info("Notification permission: \(granted)")
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
        }
    }

    private func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "Snooze (5 min)",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: Self.dismissActionId,
            title: "Dismiss",
            options: .destructive
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategoryId,
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func scheduleAlarm(_ alarm: Alarm) {
        guard alarm.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "GeoAlarm" : alarm.label
        content.body = "📍 \(alarm.locationName.isEmpty ? "Location alarm" : alarm.locationName)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: alarm.soundFilename))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryId
        // Store sound info for the ringing UI
        content.userInfo = [
            "soundFile": alarm.soundFilename,
            "label": alarm.label
        ]

        if alarm.repeatDays.isEmpty {
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

    func dismissActiveAlarm() {
        activeAlarmLabel = nil
        activeAlarmSound = nil
    }

    func snoozeActiveAlarm() {
        let label = activeAlarmLabel ?? "GeoAlarm"
        let soundFile = activeAlarmSound ?? "classic_30s.caf"

        // Schedule a new notification in 5 minutes
        let content = UNMutableNotificationContent()
        content.title = label
        content.body = "⏰ Snoozed alarm"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFile))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryId
        content.userInfo = ["soundFile": soundFile, "label": label]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        let request = UNNotificationRequest(identifier: "snooze-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        addRequest(request, label: "Snooze: \(label)")

        dismissActiveAlarm()
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        DispatchQueue.main.async {
            self.activeAlarmLabel = userInfo["label"] as? String ?? notification.request.content.title
            self.activeAlarmSound = userInfo["soundFile"] as? String
        }
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap → show alarm UI
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case Self.snoozeActionId:
            DispatchQueue.main.async {
                self.activeAlarmSound = userInfo["soundFile"] as? String
                self.activeAlarmLabel = userInfo["label"] as? String
                self.snoozeActiveAlarm()
            }
        case Self.dismissActionId, UNNotificationDismissActionIdentifier:
            DispatchQueue.main.async { self.dismissActiveAlarm() }
        default:
            // Tapped the notification → show ringing UI
            DispatchQueue.main.async {
                self.activeAlarmLabel = userInfo["label"] as? String ?? response.notification.request.content.title
                self.activeAlarmSound = userInfo["soundFile"] as? String
            }
        }
        completionHandler()
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
