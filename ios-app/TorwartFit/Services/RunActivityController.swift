import ActivityKit
import Foundation

/// Startet, aktualisiert und beendet die Live-Aktivität auf dem Sperrbildschirm.
/// Aktualisiert sofort bei Abschnittswechsel/Pause, sonst höchstens alle 15 Sekunden
/// (die Uhren laufen auf dem Sperrbildschirm von selbst weiter).
final class RunActivityController {
    private var activity: Activity<RunActivityAttributes>?
    private var lastPush = Date.distantPast
    private var lastKey = ""

    func start(title: String, icon: String, usesGPS: Bool, state: RunActivityAttributes.ContentState) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RunActivityAttributes(title: title, icon: icon, usesGPS: usesGPS)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
        lastPush = Date()
        lastKey = key(state)
    }

    func update(_ state: RunActivityAttributes.ContentState) {
        guard let a = activity else { return }
        let k = key(state)
        guard k != lastKey || Date().timeIntervalSince(lastPush) >= 15 else { return }
        lastKey = k
        lastPush = Date()
        Task { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let a = activity else { return }
        activity = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }

    private func key(_ s: RunActivityAttributes.ContentState) -> String {
        "\(s.phase)|\(s.pausedElapsed == nil)|\(s.next ?? "")"
    }
}
