import Foundation

enum AlarmSoundType: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic"
    case radar = "Radar"
    case chime = "Chime"
    case urgent = "Urgent"

    var id: String { rawValue }
}

enum AlarmSoundDuration: Int, Codable, CaseIterable, Identifiable {
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

    static func filename(type: AlarmSoundType, duration: AlarmSoundDuration) -> String {
        "\(type.rawValue.lowercased())_\(duration.rawValue)s.caf"
    }
}
