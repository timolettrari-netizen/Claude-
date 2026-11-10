import Foundation

/// Stufe 2: Dienstplan, Abnehmen und Ernährung (Logik aus dem Fitness-Coach)
extension Store {
    var nutrition: NutritionData { NutritionData.shared }

    // MARK: Dienstplan

    /// F = frei, D = Spät, N = Früh/Nacht, nil = nicht eingetragen
    func shift(on date: Date) -> String? {
        let key = DateUtil.dayKey(date)
        if let manual = s.shifts[key] { return manual == "-" ? nil : manual }
        let p = nutrition.shiftPattern
        let n = DateUtil.days(from: DateUtil.parse(p.anchor), to: date)
        guard n >= 0 else { return nil }
        return p.cycle[n % p.cycle.count]
    }

    /// Wie der Tag für Essen/Training zählt: F, F1 (frei nach Nacht), D, N
    func dayKind(_ date: Date) -> String {
        let sh = shift(on: date)
        if sh == "N" { return "N" }
        if sh == "D" { return "D" }
        if let prev = DateUtil.calendar.date(byAdding: .day, value: -1, to: date), shift(on: prev) == "N" { return "F1" }
        return "F"
    }

    func cycleShift(_ date: Date) {
        let order: [String?] = [nil, "F", "D", "N"]
        let cur = shift(on: date)
        let i = (order.firstIndex(of: cur) ?? 0) + 1
        s.shifts[DateUtil.dayKey(date)] = order[i % order.count] ?? "-"
    }

    func date(forWeekday i: Int) -> Date {
        DateUtil.calendar.date(byAdding: .day, value: i, to: DateUtil.weekStart(Date())) ?? Date()
    }

    // MARK: Gewicht & Kalorien

    var currentKg: Double {
        let last = s.weights.max { $0.date < $1.date }
        if let w = weight, s.healthEnabled { return w }
        return last?.kg ?? s.body.startKg
    }

    var bmr: Double { 10 * currentKg + 6.25 * s.body.heightCm - 5 * Double(s.body.age) + 5 }

    var deficit: (left: Double, days: Int, perDay: Int, perWeek: Double, need: Double) {
        let left = currentKg - s.body.goalKg
        let days = max(1, DateUtil.days(from: Date(), to: s.body.goalDate))
        let need = left * 7700 / Double(days)
        let d = left <= 0 ? 0 : min(900, max(400, Int((need / 50).rounded()) * 50))
        return (left, days, d, Double(d) * 7 / 7700, need)
    }

    func targetKg(on date: Date) -> Double {
        let total = max(1, DateUtil.days(from: s.body.startDate, to: s.body.goalDate))
        let t = min(1, max(0, Double(DateUtil.days(from: s.body.startDate, to: date)) / Double(total)))
        return s.body.startKg + (s.body.goalKg - s.body.startKg) * t
    }

    var baseIntake: Int {
        let stepK = max(0, Double(s.body.stepGoal - 3000)) * currentKg * 0.0004
        let raw = Int(((bmr * 1.2 + stepK - Double(deficit.perDay)) / 50).rounded()) * 50
            + s.body.calorieAdjust + (calorieAuto?.adjust ?? 0)
        return max(1800, raw)
    }

    // MARK: Automatische Kalorienanpassung

    struct CalorieAuto {
        /// kcal pro Tag (negativ = weniger essen)
        let adjust: Int
        /// tatsächliche Abnahme in kg pro Woche (negativ = zugenommen)
        let actualPerWeek: Double
        let plannedPerWeek: Double
        let weighIns: Int

        var text: String {
            func f(_ v: Double) -> String { String(format: "%.1f", abs(v)).replacingOccurrences(of: ".", with: ",") }
            let trend = actualPerWeek >= 0 ? "\(f(actualPerWeek)) kg/Woche abgenommen" : "\(f(actualPerWeek)) kg/Woche zugenommen"
            let plan = "Plan: \(f(plannedPerWeek)) kg/Woche"
            if adjust == 0 { return "Automatik: zuletzt \(trend) (\(plan)) – passt, Ziel bleibt." }
            if adjust < 0 { return "Automatik: \(adjust) kcal/Tag, weil du zuletzt \(trend) hast (\(plan))." }
            return "Automatik: +\(adjust) kcal/Tag – zuletzt \(trend), schneller als geplant (\(plan)). Das schont die Muskeln."
        }
    }

    /// Wird einmal pro Woche (Stand Montag) aus den Wiegungen der letzten 4 Wochen berechnet.
    /// Ausgleich nur zur Hälfte (Wasser schwankt), zwischen −300 und +200 kcal/Tag.
    var calorieAuto: CalorieAuto? {
        guard s.autoCalories else { return nil }
        let monday = DateUtil.weekStart(Date())
        guard let from = DateUtil.calendar.date(byAdding: .day, value: -28, to: monday) else { return nil }
        let pts = s.weights.filter { $0.date >= from && $0.date < monday }.sorted { $0.date < $1.date }
        guard pts.count >= 3, let first = pts.first, let last = pts.last,
              last.date.timeIntervalSince(first.date) >= 10 * 86400 else { return nil }
        // Trend per linearer Regression (kg über Tage)
        let xs: [Double] = pts.map { $0.date.timeIntervalSince(first.date) / 86400 }
        let ys: [Double] = pts.map { $0.kg }
        let n = Double(pts.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in 0..<pts.count {
            num += (xs[i] - mx) * (ys[i] - my)
            den += (xs[i] - mx) * (xs[i] - mx)
        }
        guard den > 0 else { return nil }
        let actual = -num / den * 7
        let planned = deficit.perWeek
        let gap = planned - actual                       // > 0: langsamer als geplant
        var adj = -gap * 7700 / 7 * 0.5
        if actual > currentKg * 0.01 { adj = max(adj, 100) }   // mehr als 1 % pro Woche ist zu schnell
        let a = max(-300, min(200, Int((adj / 50).rounded()) * 50))
        return CalorieAuto(adjust: a, actualPerWeek: actual, plannedPerWeek: planned, weighIns: pts.count)
    }

    /// Übernimmt Gewichte aus Apple Health (z. B. Garmin-Waage) in den Verlauf – je Tag ein Wert,
    /// selbst eingetragene Werte haben Vorrang.
    func mergeHealthWeights(_ samples: [(date: Date, kg: Double)]) {
        var w = s.weights
        var changed = false
        for smp in samples {
            let kg = (smp.kg * 10).rounded() / 10
            if let i = w.firstIndex(where: { DateUtil.calendar.isDate($0.date, inSameDayAs: smp.date) }) {
                if w[i].source == "health" && w[i].kg != kg && smp.date > w[i].date {
                    w[i].kg = kg
                    w[i].date = smp.date
                    changed = true
                }
            } else {
                w.append(WeightEntry(date: smp.date, kg: kg, source: "health"))
                changed = true
            }
        }
        if changed { s.weights = w.sorted { $0.date < $1.date } }
    }

    /// Geschätzter Verbrauch einer Einheit (kcal)
    func sessionKcal(_ session: String, short: Bool = false) -> Int {
        Int(5.0 * currentKg * Double(minutes(session, short: short)) / 60)
    }

    /// Kalorienziel des Tages: Grundziel + die Hälfte des geplanten Trainingsverbrauchs
    func calorieTarget(on date: Date) -> Int {
        var training = 0
        if let p = plan(for: DateUtil.dayIndex(date)), p != "game", catalog.session(p) != nil { training += sessionKcal(p) }
        if let r = plannedRun(on: date) { training += r.kcal }
        return baseIntake + Int((Double(training) * 0.5 / 10).rounded()) * 10
    }

    var proteinTarget: Int { Int((s.body.goalKg * 1.6 / 5).rounded()) * 5 }

    func addWeight(_ kg: Double) {
        let today = DateUtil.calendar.startOfDay(for: Date())
        s.weights.removeAll { DateUtil.calendar.isDate($0.date, inSameDayAs: today) }
        s.weights.append(WeightEntry(date: today, kg: (kg * 10).rounded() / 10))
        s.weights.sort { $0.date < $1.date }
    }

    // MARK: Ernährung

    func meals(on date: Date) -> [PlannedMeal] {
        let kind = dayKind(date)
        let slots = nutrition.slots[kind] ?? nutrition.slots["F"] ?? []
        let target = Double(calorieTarget(on: date))
        let dayNo = max(0, DateUtil.days(from: DateUtil.parse("2026-01-01"), to: date))
        let key = DateUtil.dayKey(date)
        var used: [String] = []
        var out: [PlannedMeal] = []
        for (si, slot) in slots.enumerated() {
            let pool = nutrition.recipes.filter { $0.tags.contains(slot.tag) }
            guard !pool.isEmpty else { continue }
            var idx = (dayNo + si * 2) % pool.count
            var k = 0
            while k < pool.count && used.contains(pool[idx].id) { idx = (idx + 1) % pool.count; k += 1 }
            var r = pool[idx]
            if let pick = s.mealPicks["\(key)|\(si)"], let pr = pool.first(where: { $0.id == pick }) { r = pr }
            used.append(r.id)
            let f = (min(1.7, max(0.7, target * slot.share / Double(r.kcal))) * 20).rounded() / 20
            out.append(PlannedMeal(key: "\(key)|\(si)", slotIndex: si, slot: slot, recipe: r, factor: f))
        }
        return out
    }

    func pool(for meal: PlannedMeal) -> [Recipe] { nutrition.recipes.filter { $0.tags.contains(meal.slot.tag) } }

    func toggleEaten(_ meal: PlannedMeal) {
        if s.eaten.contains(meal.key) { s.eaten.remove(meal.key) } else { s.eaten.insert(meal.key) }
    }

    /// Gegessen an einem Tag: abgehakte Plan-Mahlzeiten plus selbst erfasstes Essen
    func eatenKcal(on date: Date) -> (kcal: Int, protein: Int, carbs: Int) {
        let m = meals(on: date).filter { s.eaten.contains($0.key) }
        let f = foods(on: date)
        let kcal = m.reduce(0) { $0 + $1.kcal } + f.reduce(0) { $0 + $1.kcal }
        let protein = m.reduce(0) { $0 + $1.protein } + f.reduce(0) { $0 + $1.protein }
        let carbs = m.reduce(0) { $0 + $1.carbs } + f.reduce(0) { $0 + $1.carbs }
        return (kcal, protein, carbs)
    }

    // MARK: Selbst erfasstes Essen

    func foods(on date: Date) -> [FoodEntry] {
        let key = DateUtil.dayKey(date)
        return s.foodLog.filter { $0.day == key }.sorted { $0.date < $1.date }
    }

    func addFood(_ e: FoodEntry) {
        s.foodLog.append(e)
        // nur die letzten 120 Tage behalten
        if let cut = DateUtil.calendar.date(byAdding: .day, value: -120, to: Date()) {
            s.foodLog.removeAll { $0.date < cut }
        }
    }

    func deleteFood(_ e: FoodEntry) { s.foodLog.removeAll { $0.id == e.id } }

    /// Einkaufsliste für `days` Tage ab `from`
    func shoppingList(from: Date, days: Int = 7) -> [ShoppingItem] {
        var sums: [String: Double] = [:]
        for i in 0..<days {
            guard let d = DateUtil.calendar.date(byAdding: .day, value: i, to: from) else { continue }
            for m in meals(on: d) {
                for ing in m.ingredients where ing.qty > 0 { sums["\(ing.name)|\(ing.unit)", default: 0] += ing.qty }
            }
        }
        return sums.map { key, q -> ShoppingItem in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            return ShoppingItem(name: parts[0], text: Nutrition.format(q, parts.count > 1 ? parts[1] : ""))
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

struct ShoppingItem: Identifiable, Hashable {
    let name: String
    let text: String
    var id: String { name + "|" + text }
}
