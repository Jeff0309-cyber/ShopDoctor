import CoreLocation
import MapKit

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// One-shot current location; nil if denied or unavailable.
    func current() async -> CLLocationCoordinate2D? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return await withCheckedContinuation { continuation in
            pending?.resume(returning: nil)
            pending = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in self.finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        pending?.resume(returning: coordinate)
        pending = nil
    }

    /// Address search biased to Hong Kong.
    static func search(_ query: String) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: .hongKong, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        return (try? await MKLocalSearch(request: request).start().mapItems) ?? []
    }
}

extension CLLocationCoordinate2D {
    static let hongKong = CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)
}
