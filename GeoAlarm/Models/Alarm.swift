import Foundation
import SwiftData
import CoreLocation

@Model
final class Alarm {
    var label: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var repeatDays: Set<Int> // 1=Sunday, 2=Monday, ..., 7=Saturday (Calendar weekday)

    // Location
    var locationName: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double

    // Sound
    var soundTypeRaw: String
    var soundDurationRaw: Int

    var createdAt: Date

    init(
        label: String = "Alarm",
        hour: Int = 8,
        minute: Int = 0,
        isEnabled: Bool = true,
        repeatDays: Set<Int> = [],
        locationName: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        radiusMeters: Double = 200,
        soundType: AlarmSoundType? = nil,
        soundDuration: AlarmSoundDuration? = nil
    ) {
        self.label = label
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.soundTypeRaw = (soundType ?? AlarmSoundSettings.defaultType).rawValue
        self.soundDurationRaw = (soundDuration ?? AlarmSoundSettings.defaultDuration).rawValue
        self.createdAt = Date()
    }

    var soundType: AlarmSoundType {
        get { AlarmSoundType(rawValue: soundTypeRaw) ?? .classic }
        set { soundTypeRaw = newValue.rawValue }
    }

    var soundDuration: AlarmSoundDuration {
        get { AlarmSoundDuration(rawValue: soundDurationRaw) ?? .thirty }
        set { soundDurationRaw = newValue.rawValue }
    }

    var soundFilename: String {
        AlarmSoundSettings.filename(type: soundType, duration: soundDuration)
    }

    var notificationSoundPath: String {
        AlarmSoundSettings.notificationSoundPath(type: soundType, duration: soundDuration)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let components = DateComponents(hour: hour, minute: minute)
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):\(String(format: "%02d", minute))"
    }

    var repeatDescription: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }

        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
        let sorted = repeatDays.sorted()
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        let weekend: Set<Int> = [1, 7]

        if repeatDays == weekdays { return "Weekdays" }
        if repeatDays == weekend { return "Weekends" }

        return sorted.map { weekdaySymbols[$0 - 1] }.joined(separator: " ")
    }

    var regionIdentifier: String {
        guard let id = persistentModelID.storeIdentifier else {
            return "alarm-\(createdAt.timeIntervalSince1970)"
        }
        return "alarm-\(id)"
    }

    var hasLocation: Bool {
        latitude != 0 || longitude != 0
    }
}
