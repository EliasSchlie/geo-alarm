import Foundation
import SwiftData
import CoreLocation
import os

/// Coordinates geofence monitoring and notification scheduling.
/// When user enters a region → schedule that region's alarms.
/// When user exits → cancel them.
final class AlarmCoordinator: ObservableObject {
    let locationManager: LocationManager
    let notificationManager: NotificationManager
    private let logger = Logger(subsystem: "com.elias.geoalarm", category: "Coordinator")
    private var modelContext: ModelContext?

    init(locationManager: LocationManager, notificationManager: NotificationManager) {
        self.locationManager = locationManager
        self.notificationManager = notificationManager

        locationManager.onRegionEnter = { [weak self] regionId in
            self?.handleRegionEnter(regionId)
        }

        locationManager.onRegionExit = { [weak self] regionId in
            self?.handleRegionExit(regionId)
        }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Sync monitored regions with current enabled alarms
    func syncRegions() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.isEnabled && $0.latitude != 0 })
        guard let alarms = try? context.fetch(descriptor) else { return }

        // Stop monitoring regions that no longer have active alarms
        let activeIds = Set(alarms.map(\.regionIdentifier))
        for regionId in locationManager.monitoredRegionIds {
            if !activeIds.contains(regionId) {
                locationManager.stopMonitoringRegion(identifier: regionId)
            }
        }

        // Start monitoring each alarm's region
        for alarm in alarms {
            locationManager.startMonitoringRegion(
                identifier: alarm.regionIdentifier,
                center: alarm.coordinate,
                radius: alarm.radiusMeters
            )
        }

        logger.info("Synced \(alarms.count) alarm regions")
    }

    private func handleRegionEnter(_ regionId: String) {
        logger.info("Region enter: \(regionId) — scheduling alarms")
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.isEnabled })
        guard let alarms = try? context.fetch(descriptor) else { return }

        for alarm in alarms where alarm.regionIdentifier == regionId {
            notificationManager.scheduleAlarm(alarm)
        }
    }

    private func handleRegionExit(_ regionId: String) {
        logger.info("Region exit: \(regionId) — cancelling alarms")
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Alarm>(predicate: #Predicate { $0.isEnabled })
        guard let alarms = try? context.fetch(descriptor) else { return }

        for alarm in alarms where alarm.regionIdentifier == regionId {
            notificationManager.cancelAlarm(alarm)
        }
    }
}
