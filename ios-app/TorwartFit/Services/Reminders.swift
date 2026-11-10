import Foundation
import UserNotifications

/// Wöchentliche Erinnerungen an den Trainingstagen.
enum Reminders {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard store.s.remindersEnabled else { return }
        for day in 0..<7 {
            guard let t = store.plan(for: day), t != "game", let se = store.catalog.session(t) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(se.icon) \(se.name) steht an"
            content.body = "\(se.label) · ca. \(store.minutes(t)) Minuten. Los geht's!"
            content.sound = .default
            var dc = DateComponents()
            dc.weekday = (day + 1) % 7 + 1   // 1 = Sonntag, 2 = Montag …
            dc.hour = store.s.reminderHour
            dc.minute = store.s.reminderMinute
            let req = UNNotificationRequest(identifier: "train-\(day)", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
            center.add(req)
        }
        // Sonntag 18:30: Wochenrückblick
        let review = UNMutableNotificationContent()
        review.title = "📋 Dein Wochenrückblick ist bereit"
        review.body = "Der Coach wertet deine Woche aus und plant die nächste – in der App auf „Heute“."
        review.sound = .default
        var rc = DateComponents()
        rc.weekday = 1
        rc.hour = 18
        rc.minute = 30
        center.add(UNNotificationRequest(identifier: "weekly-review", content: review,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: rc, repeats: true)))
    }
}
