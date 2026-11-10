import ActivityKit
import Foundation

/// Daten der Live-Aktivität (Sperrbildschirm / Dynamic Island) während eines Laufs oder Trainings.
/// WICHTIG: Diese Datei gibt es identisch auch in der App (TorwartFit/Services/RunActivityAttributes.swift).
/// Änderungen immer in beiden Dateien machen.
struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Aktueller Abschnitt, z. B. „Zügig“, „Gehen“ – oder die Aktivität („Lauf“)
        var phase: String
        /// Belastungsabschnitt (orange) statt Erholung (blau)
        var hard: Bool
        /// Ende des Abschnitts für den Countdown (nil = kein Abschnitt oder pausiert)
        var phaseEnd: Date?
        /// Rechnerischer Startzeitpunkt für die laufende Gesamtzeit (Pausen herausgerechnet)
        var startedAt: Date
        /// Gesamtzeit in Sekunden, wenn pausiert
        var pausedElapsed: Double?
        var km: Double
        /// „5:42 /km“, „18,4 km/h“ oder leer
        var pace: String
        var hr: Int?
        /// Nächster Abschnitt, z. B. „Trab · 2 Min.“
        var next: String?
    }

    var title: String
    var icon: String
    var usesGPS: Bool
}
