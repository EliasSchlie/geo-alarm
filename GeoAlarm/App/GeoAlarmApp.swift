import SwiftUI
import SwiftData

@main
struct GeoAlarmApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var coordinator: AlarmCoordinator

    init() {
        let locMgr = LocationManager()
        let notifMgr = NotificationManager()
        let coord = AlarmCoordinator(locationManager: locMgr, notificationManager: notifMgr)

        _locationManager = StateObject(wrappedValue: locMgr)
        _notificationManager = StateObject(wrappedValue: notifMgr)
        _coordinator = StateObject(wrappedValue: coord)
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(coordinator)
        }
        .modelContainer(for: Alarm.self)
    }
}
