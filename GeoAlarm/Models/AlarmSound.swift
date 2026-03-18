import Foundation

enum AlarmSoundType: String, Codable, CaseIterable, Identifiable {
    case gentle = "Gentle"
    case soft = "Soft"
    case chime = "Chime"
    case classic = "Classic"
    case radar = "Radar"
    case urgent = "Urgent"

    var id: String { rawValue }
}

enum AlarmSoundDuration: Int, Codable, CaseIterable, Identifiable {
    case three = 3
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    var id: Int { rawValue }

    var label: String { "\(rawValue)s" }
}

struct AlarmSoundSettings {
    static let defaultsKeyType = "defaultAlarmSoundType"
    static let defaultsKeyDuration = "defaultAlarmSoundDuration"

    static var defaultType: AlarmSoundType {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKeyType),
                  let val = AlarmSoundType(rawValue: raw) else { return .classic }
            return val
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKeyType) }
    }

    static var defaultDuration: AlarmSoundDuration {
        get {
            let raw = UserDefaults.standard.integer(forKey: defaultsKeyDuration)
            return AlarmSoundDuration(rawValue: raw) ?? .thirty
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKeyDuration) }
    }

    /// Filename without path (e.g. "classic_30s.caf")
    static func filename(type: AlarmSoundType, duration: AlarmSoundDuration) -> String {
        "\(type.rawValue.lowercased())_\(duration.rawValue)s.caf"
    }

    /// Path relative to bundle root for UNNotificationSound (e.g. "Sounds/classic_30s.caf")
    static func notificationSoundPath(type: AlarmSoundType, duration: AlarmSoundDuration) -> String {
        "Sounds/\(filename(type: type, duration: duration))"
    }

    /// Get the bundle URL for a sound file
    static func bundleURL(type: AlarmSoundType, duration: AlarmSoundDuration) -> URL? {
        let name = "\(type.rawValue.lowercased())_\(duration.rawValue)s"
        return Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Sounds")
    }
}
