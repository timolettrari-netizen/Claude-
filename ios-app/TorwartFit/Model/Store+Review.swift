import Foundation

/// Wochenrückblick: welche Woche fällig ist und welche Zahlen der Coach dafür bekommt.
extension Store {
    /// Montag der Woche, die ausgewertet wird: ab Sonntag 17 Uhr die laufende, sonst die letzte abgeschlossene.
    var reviewWeekStart: Date {
        let now = Date()
        let ws = DateUtil.weekStart(now)
        if isSundayEvening(now) { return ws }
        return DateUtil.calendar.date(byAdding: .day, value: -7, to: ws) ?? ws
    }

    private func isSundayEvening(_ d: Date) -> Bool {
        DateUtil.dayIndex(d) == 6 && DateUtil.calendar.component(.hour, from: d) >= 17
    }

    func review(for weekStart: Date) -> WeeklyReview? {
        s.reviews.last { DateUtil.calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
    }

    /// Zeitfenster für die Karte auf „Heute“: Sonntag ab 17 Uhr bis Mittwoch
    var reviewWindowOpen: Bool {
        let now = Date()
        return isSundayEvening(now) || (0...2).contains(DateUtil.dayIndex(now))
    }

    func saveReview(weekStart: Date, text: String) {
        s.reviews.removeAll { DateUtil.calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
        s.reviews.append(WeeklyReview(weekStart: weekStart, created: Date(), text: text))
        s.reviews.sort { $0.weekStart < $1.weekStart }
        if s.reviews.count > 52 { s.reviews.removeFirst(s.reviews.count - 52) }
    }

    func weekTitle(_ weekStart: Date) -> String {
        let end = DateUtil.calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let kw = DateUtil.calendar.component(.weekOfYear, from: weekStart)
        return "KW \(kw) · \(DateUtil.format(weekStart, "dMMM")) – \(DateUtil.format(end, "dMMM"))"
    }

    /// Zahlen der Woche als JSON für den Coach. `steps`: Schritte je Tag dieser Woche (aus Apple Health).
    func weekReport(_ ws: Date, steps: [(date: Date, steps: Int)]) -> String {
        let cal = DateUtil.calendar
        let end = cal.date(byAdding: .day, value: 7, to: ws) ?? ws
        let inWeek: (Date) -> Bool = { $0 >= ws && $0 < end }

        // Training
        let logs = s.logs.filter { inWeek($0.date) }
        let own = logs.filter { $0.healthID == nil }
        let ext = logs.filter { $0.healthID != nil }
        let ownNames: [String] = own.map { catalog.session($0.session)?.name ?? $0.session }
        let extNames: [String] = ext.map { $0.title ?? "Training" }
        let minutes = logs.reduce(0) { $0 + $1.minutes }
        let rpes = own.compactMap(\.rpe)
        let avgRPE: Double = rpes.isEmpty ? 0 : Double(rpes.reduce(0, +)) / Double(rpes.count)

        // Läufe & Touren
        let tours = s.runs.filter { inWeek($0.date) }
        let runs = tours.filter { FreeActivity.from(logType: $0.type).isRun }
        let others = tours.filter { !FreeActivity.from(logType: $0.type).isRun }
        let runKm = runs.reduce(0.0) { $0 + $1.km }
        let otherText: [String] = others.map { r -> String in
            "\(FreeActivity.from(logType: r.type).name) \(String(format: "%.1f", r.km)) km, \(r.minutes) min"
        }
        let plannedRuns = runPlan(weekOf: ws).count

        // Schritte
        let stepValues: [Int] = steps.map { $0.steps }
        let stepAvg = stepValues.isEmpty ? 0 : stepValues.reduce(0, +) / stepValues.count
        let stepGoalDays = stepValues.filter { $0 >= s.body.stepGoal }.count

        // Gewicht
        let wk = s.weights.filter { inWeek($0.date) }.sorted { $0.date < $1.date }
        let before = s.weights.filter { $0.date < ws }.max { $0.date < $1.date }
        let lastDay = cal.date(byAdding: .day, value: -1, to: end) ?? end
        var weight: [String: Any] = ["sollAmWochenende": (targetKg(on: lastDay) * 10).rounded() / 10,
                                     "zielKg": s.body.goalKg]
        if let a = wk.first ?? before, let b = wk.last {
            weight["start"] = a.kg
            weight["ende"] = b.kg
            weight["veraenderung"] = ((b.kg - a.kg) * 10).rounded() / 10
        }
        weight["wiegungen"] = wk.count
        weight["kalorienAutomatik"] = calorieAuto?.text ?? "keine Daten"

        // Essen
        var plannedMeals = 0, eatenMeals = 0, extraKcal = 0, extraCount = 0
        for i in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: i, to: ws), d <= Date() else { continue }
            let m = meals(on: d)
            plannedMeals += m.count
            eatenMeals += m.filter { s.eaten.contains($0.key) }.count
            let f = foods(on: d)
            extraCount += f.count
            extraKcal += f.reduce(0) { $0 + $1.kcal }
        }

        // Tagesform
        var sleep: [Int] = [], legs: [Int] = [], energy: [Int] = []
        for i in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: i, to: ws), let r = s.readiness[DateUtil.dayKey(d)] else { continue }
            if let v = r.sleep { sleep.append(v) }
            if let v = r.legs { legs.append(v) }
            if let v = r.energy { energy.append(v) }
        }
        func avg(_ a: [Int]) -> Double { a.isEmpty ? 0 : (Double(a.reduce(0, +)) / Double(a.count) * 10).rounded() / 10 }

        // Nächste Woche
        let nextMonday = end
        var nextWeek: [String] = []
        for i in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: i, to: nextMonday) else { continue }
            let p = plan(for: i)
            let train: String = p == "game" ? "Spiel" : (p.flatMap { catalog.session($0)?.name } ?? "frei")
            let shift = NutritionData.shared.kindNames[dayKind(d)] ?? ""
            nextWeek.append("\(DateUtil.weekdays[i]): \(shift), Training: \(train)")
        }
        let nextRuns: [String] = runPlan(weekOf: nextMonday).map { r -> String in
            "\(DateUtil.weekdays[DateUtil.dayIndex(r.date)]): \(r.title) \(fmtKg(r.km)) km"
        }

        let tests: [String] = s.tests.filter { inWeek($0.date) }.map { t -> String in
            "\(catalog.test(t.test)?.name ?? t.test): \(fmtKg(t.value)) \(catalog.test(t.test)?.unit ?? "")"
        }

        var planText = "kein aktiver Plan"
        if let p = program { planText = "\(p.goal.name), \(p.weekText), \(p.adherence) % erledigt" }

        let data: [String: Any] = [
            "woche": weekTitle(ws),
            "plan": planText,
            "einheitenGeplant": weeklyGoal,
            "eigeneEinheiten": ownNames,
            "importierteTrainings": extNames,
            "trainingsminutenGesamt": minutes,
            "anstrengungDurchschnitt": (avgRPE * 10).rounded() / 10,
            "laeufe": runs.count,
            "laeufeGeplant": plannedRuns,
            "laufKm": (runKm * 10).rounded() / 10,
            "weitereAktivitaeten": otherText,
            "schritteProTag": stepValues,
            "schritteDurchschnitt": stepAvg,
            "schrittZiel": s.body.stepGoal,
            "tageMitSchrittZiel": stepGoalDays,
            "gewicht": weight,
            "kalorienzielHeute": calorieTarget(on: Date()),
            "planMahlzeitenGegessen": "\(eatenMeals) von \(plannedMeals)",
            "zusaetzlichErfasstesEssen": "\(extraCount)× zusammen \(extraKcal) kcal",
            "tagesformDurchschnitt": ["schlaf": avg(sleep), "beine": avg(legs), "energie": avg(energy)],
            "leistungstests": tests,
            "naechsteWoche": nextWeek,
            "laufplanNaechsteWoche": nextRuns,
        ]
        let json = (try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys, .prettyPrinted]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return json
    }

    static let reviewSystemPrompt = """
    Du bist der persönliche Coach eines Amateur-Fußballtorwarts (Anfang 30, Schichtdienst mit Früh-/Spät-/Nachtdiensten), \
    der abnehmen will und Kraft, Sprungkraft und Beweglichkeit trainiert. Du schreibst ihm seinen Wochenrückblick.

    Regeln:
    - Deutsch, per Du, ehrlich und motivierend, wie ein Trainer im Gespräch. Höchstens ca. 250 Wörter.
    - Nutze nur die Zahlen aus den Daten. Erfinde nichts. Fehlen Daten (z. B. keine Wiegung), sag es kurz.
    - Berücksichtige Schichten und Spieltag bei den Vorschlägen für die nächste Woche.

    Aufbau (Markdown):
    **Bilanz** – 3–4 kurze Punkte mit den wichtigsten Zahlen (Training, Läufe/Schritte, Gewicht, Essen).
    **Stark** – 1–2 Dinge, die gut liefen.
    **Verbessern** – 1–2 Dinge, ehrlich und konkret.
    **Fokus nächste Woche** – genau 3 nummerierte, konkrete Vorhaben mit Wochentag, passend zu Diensten und Plan.
    Zum Schluss ein kurzer motivierender Satz.
    """
}
