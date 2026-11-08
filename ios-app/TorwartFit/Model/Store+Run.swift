import Foundation

/// Ein geplanter Lauf (aus der Logik des Fitness-Coach übernommen)
struct PlannedRun: Identifiable, Hashable {
    var id: String { key }
    let key: String           // yyyy-MM-dd
    let date: Date
    let type: String          // wr = Lauf-Geh, easy, long, int
    let title: String
    let km: Double
    let minutes: Int
    let kcal: Int
    let details: [String]
    let timeHint: String
}

/// Starten eines GPS-Laufs (für fullScreenCover)
struct RunLaunch: Identifiable, Hashable {
    let id = UUID()
    let plan: PlannedRun?
}

extension Store {
    /// Ø-Tempo in min/km aus den letzten Läufen (sonst 6:20 aus Strava)
    var paceMinPerKm: Double {
        let r = s.runs.filter { $0.km > 3 && $0.minutes > 0 }.suffix(6)
        guard !r.isEmpty else { return 6.33 }
        return r.map { Double($0.minutes) / $0.km }.reduce(0, +) / Double(r.count)
    }

    static func pace(_ minPerKm: Double) -> String {
        let s = Int((minPerKm * 60).rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func runWeekNumber(_ monday: Date) -> Int {
        DateUtil.days(from: DateUtil.weekStart(s.runPlanStart), to: monday) / 7 + 1
    }

    /// Läufe der Woche, in der `date` liegt
    func runPlan(weekOf date: Date) -> [PlannedRun] {
        let monday = DateUtil.weekStart(date)
        let w = runWeekNumber(monday)
        guard s.runsPerWeek > 0, w >= 1 else { return [] }
        let deload = w % 4 == 0
        let f = deload ? 0.75 : 1.0

        struct Cand { let i: Int; let date: Date; let kind: String; let score: Double }
        var cands: [Cand] = []
        for i in 0..<7 {
            guard let d = DateUtil.calendar.date(byAdding: .day, value: i, to: monday) else { continue }
            if s.gameDay >= 0 {
                let o = (i - s.gameDay + 7) % 7
                if o == 0 || o == 6 { continue }          // kein Lauf am Spieltag und am Tag davor
            }
            let kind = dayKind(d)
            var score: Double = kind == "F" ? 3 : kind == "F1" ? 2 : kind == "D" ? 1.5 : 0.5
            if let p = plan(for: i), p != "game", let se = catalog.session(p) {
                score -= (se.category == "Explosiv" || se.category == "Gym") ? 2.5 : 1.5
            }
            cands.append(Cand(i: i, date: d, kind: kind, score: score))
        }
        let n = min(s.runsPerWeek, cands.count)
        let chosenByScore = Array(cands.sorted { $0.score != $1.score ? $0.score > $1.score : $0.i < $1.i }.prefix(n))
        let pace = paceMinPerKm, kg = currentKg
        let easyLo = Store.pace(pace * 1.06), easyHi = Store.pace(pace * 1.16)
        var out: [PlannedRun] = []
        var usedInt = false
        for (rank, c) in chosenByScore.enumerated() {
            var type = rank == 0 && n >= 2 ? "long" : "easy"
            if type == "easy" && c.kind == "F" && w >= 5 && w % 2 == 1 && !deload && !usedInt { type = "int"; usedInt = true }
            if w <= 2 { type = "wr" }
            let hint: String = ["N": "Zwischen Früh- und Nachtdienst (ca. 13:30–15:30), kurz halten.",
                                "F1": "Nach dem Nachtdienst erst ausschlafen, Lauf am späten Nachmittag.",
                                "D": "Vor dem Spätdienst, z. B. 8:00–10:00.", "F": ""][c.kind] ?? ""
            let key = DateUtil.dayKey(c.date)
            switch type {
            case "wr":
                let a = w == 1 ? 1.0 : 2.0, b = 2.0, reps = w == 1 ? 8 : 6
                let minutes = 10 + Int(Double(reps) * (a + b))
                let kmJog = a * Double(reps) / (pace * 1.05), kmWalk = b * Double(reps) / 11 + 10.0 / 11
                out.append(PlannedRun(key: key, date: c.date, type: type, title: "Lauf-Geh-Intervalle",
                                      km: ((kmJog + kmWalk) * 10).rounded() / 10, minutes: minutes,
                                      kcal: Int(0.92 * kg * kmJog + 0.5 * kg * kmWalk),
                                      details: ["5 Min. zügig gehen zum Aufwärmen.",
                                                "\(reps) × (\(Int(a)) Min. locker traben / \(Int(b)) Min. gehen).",
                                                "Traben heißt: so langsam, dass du dich noch unterhalten kannst. Das Gehen gehört dazu.",
                                                "5 Min. gehen zum Auslaufen.",
                                                "Bei Schmerzen in Knie, Hüfte oder Schienbein sofort auf Gehen wechseln."],
                                      timeHint: hint))
            case "long":
                let km = (min(14, 5 + 0.6 * Double(max(0, w - 3))) * f * 2).rounded() / 2
                out.append(PlannedRun(key: key, date: c.date, type: type, title: "Langer Lauf", km: km,
                                      minutes: Int(km * pace * 1.1), kcal: Int(0.92 * kg * km),
                                      details: ["Ruhig und gleichmäßig, Tempo ca. \(easyLo)–\(easyHi) /km.",
                                                "Ab ca. 10 km Trinken mitnehmen.",
                                                "Dein größter Kalorienverbrenner der Woche."], timeHint: hint))
            case "int":
                let reps = min(8, 4 + w / 3), minutes = 20 + 4 * reps
                let km = (Double(minutes) / 6.6 * 2).rounded() / 2
                out.append(PlannedRun(key: key, date: c.date, type: type, title: "Intervall-Lauf", km: km,
                                      minutes: minutes, kcal: Int(0.97 * kg * km),
                                      details: ["10 Min. locker einlaufen.", "\(reps) × (2 Min. zügig / 2 Min. Trab).",
                                                "Zügig = Tempo, bei dem nur kurze Sätze gehen.", "10 Min. locker auslaufen."],
                                      timeHint: hint))
            default:
                var km = (min(8, 4 + 0.5 * Double(max(0, w - 3))) * f * (c.kind == "F1" ? 0.85 : 1) * 2).rounded() / 2
                if c.kind == "N" { km = min(km, 4) }
                out.append(PlannedRun(key: key, date: c.date, type: "easy", title: "Lockerer Lauf", km: km,
                                      minutes: Int(km * pace * 1.1), kcal: Int(0.92 * kg * km),
                                      details: ["Locker laufen, Tempo ca. \(easyLo)–\(easyHi) /km.",
                                                "Du musst dabei noch in ganzen Sätzen sprechen können.",
                                                "Gehpausen sind erlaubt – lieber langsam als Gelenke überlasten."],
                                      timeHint: hint))
            }
        }
        return out.sorted { $0.date < $1.date }
    }

    func plannedRun(on date: Date) -> PlannedRun? {
        runPlan(weekOf: date).first { DateUtil.calendar.isDate($0.date, inSameDayAs: date) }
    }

    func runDone(on date: Date) -> Bool {
        s.runs.contains { DateUtil.calendar.isDate($0.date, inSameDayAs: date) }
    }

    func startRun(_ plan: PlannedRun?) { runLaunch = RunLaunch(plan: plan) }

    func saveRun(plan: PlannedRun?, start: Date, km: Double, seconds: Double, route: [RunCoordinate], avgHR: Int? = nil, maxHR: Int? = nil) {
        let minutes = max(1, Int(seconds / 60))
        let kg = currentKg
        let kcal = km > 0.2 ? Int(0.92 * kg * km) : Int(8.5 * kg * seconds / 3600)
        s.runs.append(RunLog(date: start, km: (km * 100).rounded() / 100, minutes: minutes, kcal: kcal,
                             type: plan?.type ?? "free", title: plan?.title ?? "Freier Lauf", route: route,
                             avgHR: avgHR, maxHR: maxHR))
        s.runs.sort { $0.date < $1.date }
        if s.healthEnabled {
            Task { await HealthService.shared.saveRun(start: start, end: start.addingTimeInterval(seconds), km: km, kcal: Double(kcal)) }
        }
    }

    var runKmThisWeek: Double {
        let ws = DateUtil.weekStart(Date())
        return s.runs.filter { $0.date >= ws }.reduce(0) { $0 + $1.km }
    }
}
