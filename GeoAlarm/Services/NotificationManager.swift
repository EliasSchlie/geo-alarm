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
    @Published var activeAlarmSoundType: AlarmSoundType?
    @Published var activeAlarmSoundDuration: AlarmSoundDuration?

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
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: alarm.notificationSoundPath))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryId
        content.userInfo = [
            "soundType": alarm.soundTypeRaw,
            "soundDuration": alarm.soundDurationRaw,
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
        let ids = notificationIds(for: alarm)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        logger.info("Cancelled notifications for alarm: \(alarm.label)")
    }

    func cancelNotifications(forRegion regionId: String) {
        let suffixes = ["once"] + (1...7).map { "day\($0)" }
        let ids = suffixes.map { "\(regionId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        logger.info("Cancelled notifications for region: \(regionId)")
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        logger.info("Cancelled all notifications")
    }

    func dismissActiveAlarm() {
        activeAlarmLabel = nil
        activeAlarmSoundType = nil
        activeAlarmSoundDuration = nil
    }

    func snoozeActiveAlarm() {
        let label = activeAlarmLabel ?? "GeoAlarm"
        let sType = activeAlarmSoundType ?? .classic
        let sDur = activeAlarmSoundDuration ?? .thirty
        let soundPath = AlarmSoundSettings.notificationSoundPath(type: sType, duration: sDur)

        let content = UNMutableNotificationContent()
        content.title = label
        content.body = "⏰ Snoozed alarm"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundPath))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryId
        content.userInfo = [
            "soundType": sType.rawValue,
            "soundDuration": sDur.rawValue,
            "label": label
        ]

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
            self.extractAlarmInfo(from: userInfo, fallbackTitle: notification.request.content.title)
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case Self.snoozeActionId:
            DispatchQueue.main.async {
                self.extractAlarmInfo(from: userInfo, fallbackTitle: nil)
                self.snoozeActiveAlarm()
            }
        case Self.dismissActionId, UNNotificationDismissActionIdentifier:
            DispatchQueue.main.async { self.dismissActiveAlarm() }
        default:
            DispatchQueue.main.async {
                self.extractAlarmInfo(from: userInfo, fallbackTitle: response.notification.request.content.title)
            }
        }
        completionHandler()
    }

    private func extractAlarmInfo(from userInfo: [AnyHashable: Any], fallbackTitle: String?) {
        activeAlarmLabel = userInfo["label"] as? String ?? fallbackTitle ?? "Alarm"
        if let typeRaw = userInfo["soundType"] as? String {
            activeAlarmSoundType = AlarmSoundType(rawValue: typeRaw)
        }
        if let durRaw = userInfo["soundDuration"] as? Int {
            activeAlarmSoundDuration = AlarmSoundDuration(rawValue: durRaw)
        }
    }

    private func notificationIds(for alarm: Alarm) -> [String] {
        var ids = [notificationId(for: alarm, weekday: nil)]
        for weekday in 1...7 {
            ids.append(notificationId(for: alarm, weekday: weekday))
        }
        return ids
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
