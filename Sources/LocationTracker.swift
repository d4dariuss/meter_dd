//
//  LocationTracker.swift
//  Meter
//
//  Wraps CLLocationManager and accumulates driven distance with basic
//  noise/drift filtering. Reports miles, GPS accuracy, speed, and tracking
//  state back out through the `onUpdate` callback (wired to JavaScript in WebView).
//
//  Honest limits (see README): GPS path distance is an estimate, not a
//  tax-grade number on its own. Keep using the odometer log in the app as the
//  audit-proof record and treat this as a convenience cross-check.
//

import Foundation
import CoreLocation

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    @Published var meters: Double = 0          // accumulated distance, current session
    @Published var isTracking: Bool = false
    @Published var lastAccuracy: Double = -1    // meters; -1 = unknown
    @Published var lastSpeedMph: Double = 0
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    // miles, accuracyMeters, speedMph, tracking
    var onUpdate: ((Double, Double, Double, Bool) -> Void)?

    // True only when the Info.plist actually declares the "location" background mode.
    // Setting allowsBackgroundLocationUpdates without it crashes at runtime.
    private let backgroundLocationAvailable: Bool = {
        (Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String])?.contains("location") ?? false
    }()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 10            // meters between callbacks; trims jitter
        manager.pausesLocationUpdatesAutomatically = false  // keep tracking at red lights
        authStatus = manager.authorizationStatus
    }

    // MARK: - Permission

    func requestWhenInUse() { manager.requestWhenInUseAuthorization() }
    func requestAlways()    { manager.requestAlwaysAuthorization() }

    // MARK: - Control

    func start() {
        lastLocation = nil
        meters = 0
        isTracking = true
        if authStatus == .authorizedAlways && backgroundLocationAvailable {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
        emit()
    }

    func stop() {
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        emit()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authStatus = m.authorizationStatus
        // If we were asked to track before permission landed, begin now.
        if isTracking,
           authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            if authStatus == .authorizedAlways && backgroundLocationAvailable {
                manager.allowsBackgroundLocationUpdates = true
            }
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        for loc in locs {
            // Drop poor-accuracy and stale points to limit indoor / urban drift.
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 25 else { continue }
            if abs(loc.timestamp.timeIntervalSinceNow) > 5 { continue }

            lastAccuracy = loc.horizontalAccuracy
            lastSpeedMph = max(0, loc.speed) * 2.2369363   // m/s -> mph

            if let last = lastLocation {
                let d = loc.distance(from: last)
                // Ignore sub-5m jitter and physically impossible jumps.
                if d >= 5, d < 2000 { meters += d }
            }
            lastLocation = loc
        }
        emit()
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal. You could surface this to the UI if desired.
    }

    // MARK: - Output

    private func emit() {
        let miles = meters / 1609.344
        onUpdate?(miles, lastAccuracy, lastSpeedMph, isTracking)
    }
}
