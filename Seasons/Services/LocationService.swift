import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var region: GrowingRegion = .northeast
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var hasLocation = false

    private static let manualRegionKey = "manualRegion"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        if let raw = UserDefaults.standard.string(forKey: Self.manualRegionKey),
           let saved = GrowingRegion(rawValue: raw) {
            region = saved
            hasLocation = true
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func setManualRegion(_ region: GrowingRegion) {
        self.region = region
        self.hasLocation = true
        UserDefaults.standard.set(region.rawValue, forKey: Self.manualRegionKey)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate else { return }
        region = GrowingRegion.from(coordinate: coordinate)
        hasLocation = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fall back to manual region selection on location failure
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        default:
            break
        }
    }
}
