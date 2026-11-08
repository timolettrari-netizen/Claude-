import Foundation
import CoreLocation

/// GPS-Aufzeichnung eines Laufs: Strecke, Zeit, Tempo, Route.
final class RunTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum GPS { case searching, ok, denied }

    @Published var distance: Double = 0          // Meter
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var running = false
    @Published var gps: GPS = .searching
    @Published var now = Date()

    let start = Date()
    /// (Zeitpunkt, Strecke in m) für das Tempo der letzten Minute
    private var samples: [(t: TimeInterval, d: Double)] = []
    @Published var hrSum = 0
    @Published var hrCount = 0
    @Published var hrMax = 0

    /// Tempo der letzten ~60 Sekunden (min/km)
    var rollingPace: Double? {
        guard let first = samples.first, let last = samples.last, last.t - first.t >= 30 else { return nil }
        let d = last.d - first.d
        guard d > 20 else { return nil }
        return (last.t - first.t) / 60 / (d / 1000)
    }

    func recordSecond(hr: Int?) {
        if running {
            let t = elapsed
            samples.append((t, distance))
            samples.removeAll { t - $0.t > 60 }
            if let hr { hrSum += hr; hrCount += 1; hrMax = max(hrMax, hr) }
        }
    }
    var avgHR: Int? { hrCount > 0 ? hrSum / hrCount : nil }
    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?
    private var last: CLLocation?
    private let manager = CLLocationManager()
    private var timer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        // Hintergrund nur, wenn der Hintergrundmodus "location" im Info.plist steht (sonst Absturz)
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
    }

    var elapsed: TimeInterval { accumulated + (resumedAt.map { now.timeIntervalSince($0) } ?? 0) }
    var km: Double { distance / 1000 }
    var paceMinPerKm: Double? { km > 0.05 ? elapsed / 60 / km : nil }

    func begin() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        resume()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.now = Date() }
    }

    func pause() {
        guard running else { return }
        accumulated += Date().timeIntervalSince(resumedAt ?? Date())
        resumedAt = nil
        running = false
        last = nil
    }

    func resume() {
        resumedAt = Date()
        running = true
    }

    func finish() {
        pause()
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        now = Date()
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .denied, .restricted: gps = .denied
        case .authorizedAlways, .authorizedWhenInUse: if gps == .denied { gps = .searching }
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 30 else { continue }
            if gps != .ok { gps = .ok }
            guard running else { continue }
            if let prev = last {
                let d = loc.distance(from: prev)
                let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
                // Sprünge und unrealistische Geschwindigkeiten (> 25 km/h) ignorieren
                guard dt > 0, d > 2, d / dt < 7 else { continue }
                distance += d
            }
            last = loc
            route.append(loc.coordinate)
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { gps = .denied }
    }
}
