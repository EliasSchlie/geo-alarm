import Foundation
import CoreLocation
import os

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: "com.elias.geoalarm", category: "Location")

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var monitoredRegionIds: Set<String> = []

    var onRegionEnter: ((String) -> Void)?
    var onRegionExit: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        updateMonitoredSet()
    }

    func requestPermission() {
        logger.info("Requesting location permission")
        manager.requestAlwaysAuthorization()
    }

    func requestCurrentLocation() {
        manager.requestLocation()
    }

    func startMonitoringRegion(identifier: String, center: CLLocationCoordinate2D, radius: Double) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            logger.error("Region monitoring not available")
            return
        }

        let clampedRadius = min(radius, manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true

        manager.startMonitoring(for: region)
        // Request initial state — triggers didDetermineState if already inside
        manager.requestState(for: region)
        logger.info("Started monitoring region: \(identifier), radius: \(clampedRadius)m")
        updateMonitoredSet()
    }

    func stopMonitoringRegion(identifier: String) {
        for region in manager.monitoredRegions {
            if region.identifier == identifier {
                manager.stopMonitoring(for: region)
                logger.info("Stopped monitoring region: \(identifier)")
            }
        }
        updateMonitoredSet()
    }

    func stopMonitoringAll() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        logger.info("Stopped monitoring all regions")
        updateMonitoredSet()
    }

    private func updateMonitoredSet() {
        monitoredRegionIds = Set(manager.monitoredRegions.map(\.identifier))
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.logger.info("Authorization changed: \(String(describing: status.rawValue))")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        logger.info("Entered region: \(region.identifier)")
        DispatchQueue.main.async {
            self.onRegionEnter?(region.identifier)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        logger.info("Exited region: \(region.identifier)")
        DispatchQueue.main.async {
            self.onRegionExit?(region.identifier)
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.error("Monitoring failed for \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        logger.info("Region \(region.identifier) state: \(state.rawValue)")
        if state == .inside {
            DispatchQueue.main.async {
                self.onRegionEnter?(region.identifier)
            }
        }
    }
}
