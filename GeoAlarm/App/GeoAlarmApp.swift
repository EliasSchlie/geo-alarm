import SwiftUI
import SwiftData
import os

@main
struct GeoAlarmApp: App {
    @StateObject private var locationManager: LocationManager
    @StateObject private var notificationManager: NotificationManager
    @StateObject private var coordinator: AlarmCoordinator
    let modelContainer: ModelContainer

    init() {
        let locMgr = LocationManager()
        let notifMgr = NotificationManager()
        let coord = AlarmCoordinator(locationManager: locMgr, notificationManager: notifMgr)

        _locationManager = StateObject(wrappedValue: locMgr)
        _notificationManager = StateObject(wrappedValue: notifMgr)
        _coordinator = StateObject(wrappedValue: coord)

        // Handle schema migration: if model changed, delete old store and start fresh
        let schema = Schema([Alarm.self])
        let config = ModelConfiguration(schema: schema)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger(subsystem: "com.elias.geoalarm", category: "App")
                .error("Failed to load database, resetting: \(error.localizedDescription)")
            // Delete corrupted store and retry
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AlarmListView()
                    .environmentObject(locationManager)
                    .environmentObject(notificationManager)
                    .environmentObject(coordinator)

                // Full-screen alarm ringing overlay
                if notificationManager.activeAlarmLabel != nil {
                    AlarmRingingView()
                        .environmentObject(notificationManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: notificationManager.activeAlarmLabel != nil)
        }
        .modelContainer(modelContainer)
    }
}
