import Foundation

// MARK: - Rezepte (Resources/recipes.json, Gerichte aus TorwartFit plus neue)

struct Ingredient: Codable, Hashable {
    let name: String
    let qty: Double
    let unit: String
    let whole: Bool
}

struct Recipe: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let emoji: [String]
    let tags: [String]
    let minutes: Int
    let devices: [String]
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let ingredients: [Ingredient]
    let steps: [String]

    var isCarb: Bool { tags.contains("carb") }
    var imageName: String { "food_" + id }
}

struct Snack: Codable, Hashable {
    let name: String
    let info: String
}

struct RecipeBook: Codable {
    let recipes: [Recipe]
    let snacks: [Snack]

    static let shared: RecipeBook = {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(RecipeBook.self, from: data) else {
            return RecipeBook(recipes: [], snacks: [])
        }
        return book
    }()
}

// MARK: - Tagesplan

enum DayType {
    case training, rest

    var title: String { self == .training ? "Trainingstag" : "Ruhetag" }
    var icon: String { self == .training ? "dumbbell.fill" : "leaf.fill" }
}

struct MealSlot: Hashable {
    let name: String
    let time: String
    let tag: String
    let share: Double

    static let training: [MealSlot] = [
        MealSlot(name: "Frühstück", time: "7:30", tag: "b", share: 0.25),
        MealSlot(name: "Mittag", time: "12:30", tag: "l", share: 0.30),
        MealSlot(name: "Nach dem Training", time: "17:30", tag: "snack", share: 0.15),
        MealSlot(name: "Abend", time: "19:30", tag: "d", share: 0.30),
    ]

    static let rest: [MealSlot] = [
        MealSlot(name: "Frühstück", time: "8:00", tag: "b", share: 0.27),
        MealSlot(name: "Mittag", time: "12:30", tag: "l", share: 0.33),
        MealSlot(name: "Snack", time: "15:30", tag: "snack", share: 0.10),
        MealSlot(name: "Abend", time: "18:30", tag: "d", share: 0.30),
    ]
}

/// Eine geplante Mahlzeit, auf das Kalorienziel des Tages skaliert.
struct PlannedMeal: Identifiable, Hashable {
    var id: String { key }
    let key: String          // "yyyy-MM-dd|slotIndex"
    let slotIndex: Int
    let slot: MealSlot
    let recipe: Recipe
    let factor: Double

    var kcal: Int { Int((Double(recipe.kcal) * factor).rounded()) }
    var protein: Int { Int((Double(recipe.protein) * factor).rounded()) }
    var carbs: Int { Int((Double(recipe.carbs) * factor).rounded()) }
    var fat: Int { Int((Double(recipe.fat) * factor).rounded()) }

    var ingredients: [ScaledIngredient] {
        recipe.ingredients.map { i in
            ScaledIngredient(name: i.name,
                             qty: i.qty > 0 ? NutritionMath.scale(i.qty, unit: i.unit, factor: factor, whole: i.whole) : 0,
                             unit: i.unit)
        }
    }
}

struct ScaledIngredient: Hashable {
    let name: String
    let qty: Double
    let unit: String

    var text: String { qty > 0 ? NutritionMath.format(qty, unit) : "nach Geschmack" }
}

/// Selbst erfasstes Essen (z. B. auswärts gegessen).
struct FoodEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var name: String
    var kcal: Int
    var protein: Int
}

struct ShoppingItem: Identifiable, Hashable {
    let name: String
    let text: String
    var id: String { name + "|" + text }
}

enum NutritionMath {
    static func scale(_ q: Double, unit: String, factor: Double, whole: Bool) -> Double {
        let v = q * factor
        if unit == "g" || unit == "ml" { return v < 10 ? v.rounded() : (v / 5).rounded() * 5 }
        if whole { return max(1, v.rounded()) }
        return max(0.5, (v * 2).rounded() / 2)
    }

    static func format(_ q: Double, _ unit: String) -> String {
        if unit == "g" && q >= 1000 { return (q / 1000).formatted(.number.precision(.fractionLength(0...1))) + " kg" }
        if unit == "ml" && q >= 1000 { return (q / 1000).formatted(.number.precision(.fractionLength(0...1))) + " l" }
        return q.formatted(.number.precision(.fractionLength(0...1))) + (unit.isEmpty ? "" : " \(unit)")
    }
}

// MARK: - Körper & Gewichtsziel

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var title: String { self == .male ? "Mann" : "Frau" }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low, light, active, veryActive
    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Wenig Bewegung"
        case .light: return "Leicht aktiv"
        case .active: return "Aktiv"
        case .veryActive: return "Sehr aktiv"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Bürojob, unter 5.000 Schritte"
        case .light: return "Etwa 5.000–8.000 Schritte"
        case .active: return "Viel auf den Beinen, ca. 10.000 Schritte"
        case .veryActive: return "Körperliche Arbeit"
        }
    }

    /// Faktor auf den Grundumsatz – ohne das Krafttraining, das kommt an Trainingstagen dazu.
    var factor: Double {
        switch self {
        case .low: return 1.2
        case .light: return 1.3
        case .active: return 1.42
        case .veryActive: return 1.6
        }
    }
}

struct BodyProfile: Codable, Hashable {
    var configured = false
    var sex: Sex = .male
    var heightCm = 189.0
    var age = 33
    var activity: ActivityLevel = .active
    var startKg = 115.0
    var startDate = BodyProfile.date("2026-08-23")
    var goalKg = 100.0
    var goalDate = BodyProfile.date("2027-03-31")
    var autoCalories = true
    var calorieAdjust = 0

    static func date(_ s: String) -> Date {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return Store.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .now
    }
}

enum GoalDirection {
    case lose, keep, gain
}

struct GoalNumbers {
    let currentKg: Double
    let direction: GoalDirection
    let bmr: Double
    let maintenance: Double
    /// Geplantes Defizit pro Tag in kcal (negativ = Überschuss)
    let deficit: Int
    /// Geplantes Tempo in kg pro Woche (positiv = abnehmen)
    let perWeek: Double
    let auto: CalorieAuto?
    /// Kalorienziel an Ruhetagen
    let restDay: Int
    /// Zusätzlich an Trainingstagen
    let trainingBonus: Int
    let protein: Int
    /// Rechnerisch läge das Ziel unter dem Minimum (Zieldatum zu knapp)
    let belowMinimum: Bool
}

struct CalorieAuto {
    /// kcal pro Tag (negativ = weniger essen)
    let adjust: Int
    /// tatsächliche Abnahme in kg pro Woche (negativ = zugenommen)
    let actualPerWeek: Double
    let plannedPerWeek: Double

    var text: String {
        func f(_ v: Double) -> String { abs(v).formatted(.number.precision(.fractionLength(1))) }
        let trend = actualPerWeek >= 0 ? "\(f(actualPerWeek)) kg/Woche abgenommen" : "\(f(actualPerWeek)) kg/Woche zugenommen"
        let planText = plannedPerWeek >= 0 ? "Plan: −\(f(plannedPerWeek)) kg/Woche" : "Plan: +\(f(plannedPerWeek)) kg/Woche"
        if adjust == 0 { return "Automatik: zuletzt \(trend) (\(planText)) – passt, das Ziel bleibt." }
        if adjust < 0 { return "Automatik: \(adjust) kcal/Tag, weil du zuletzt \(trend) hast (\(planText))." }
        return "Automatik: +\(adjust) kcal/Tag – zuletzt \(trend) (\(planText)). Das schont die Muskeln."
    }
}

// MARK: - Logik im Store

extension Store {
    var recipeBook: RecipeBook { RecipeBook.shared }

    static func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func days(from a: Date, to b: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    // MARK: Gewicht

    /// Aktuelles Gewicht: letzter Eintrag, sonst das Startgewicht des Profils
    func currentKg(for p: BodyProfile) -> Double { bodyWeights.last?.kg ?? p.startKg }
    var currentKg: Double { currentKg(for: profile) }

    /// Alle Zielwerte für ein Profil – auch für einen noch nicht gespeicherten Entwurf (Vorschau).
    func goalNumbers(for p: BodyProfile, includeAuto: Bool = true) -> GoalNumbers {
        let kg = currentKg(for: p)
        let diff = p.goalKg - kg
        let direction: GoalDirection = abs(diff) < 0.5 ? .keep : (diff < 0 ? .lose : .gain)

        // Grundumsatz nach Mifflin-St Jeor
        let base = 10 * kg + 6.25 * p.heightCm - 5 * Double(p.age)
        let bmr = p.sex == .male ? base + 5 : base - 161
        let maintenance = bmr * p.activity.factor

        let deficit: Int
        switch direction {
        case .keep:
            deficit = 0
        case .gain:
            deficit = -300
        case .lose:
            let days = max(7, Self.days(from: .now, to: p.goalDate))
            let need = (kg - p.goalKg) * 7700 / Double(days)
            deficit = min(900, max(300, Int((need / 50).rounded()) * 50))
        }
        let perWeek = Double(deficit) * 7 / 7700

        var auto: CalorieAuto?
        if includeAuto && p.autoCalories && direction != .keep,
           let actual = weightTrend(before: Self.startOfWeek()) {
            var adj = -(perWeek - actual) * 7700 / 7 * 0.5
            if direction == .lose && actual > kg * 0.01 { adj = max(adj, 100) }
            let a = max(-300, min(300, Int((adj / 50).rounded()) * 50))
            auto = CalorieAuto(adjust: a, actualPerWeek: actual, plannedPerWeek: perWeek)
        }

        let minimum = p.sex == .male ? 1800 : 1500
        let raw = Int(((maintenance - Double(deficit)) / 50).rounded()) * 50 + p.calorieAdjust + (auto?.adjust ?? 0)
        let minutes = Double(plan?.settings.minutes ?? 60)
        let bonus = Int((5.0 * kg * minutes / 60 * 0.5 / 10).rounded()) * 10
        let reference = direction == .lose ? p.goalKg : kg
        let protein = Int((reference * 1.8 / 5).rounded()) * 5

        return GoalNumbers(currentKg: kg, direction: direction, bmr: bmr, maintenance: maintenance,
                           deficit: deficit, perWeek: perWeek, auto: auto, restDay: max(minimum, raw),
                           trainingBonus: bonus, protein: protein, belowMinimum: raw < minimum)
    }

    var goals: GoalNumbers { goalNumbers(for: profile) }
    var goalDirection: GoalDirection { goals.direction }
    var baseIntake: Int { goals.restDay }
    var trainingBonus: Int { goals.trainingBonus }
    var proteinTarget: Int { goals.protein }
    var calorieAuto: CalorieAuto? { goals.auto }

    /// Soll-Gewicht an einem Tag (Linie von Start zu Ziel)
    func targetKg(on date: Date) -> Double {
        let total = max(1, Self.days(from: profile.startDate, to: profile.goalDate))
        let t = min(1, max(0, Double(Self.days(from: profile.startDate, to: date)) / Double(total)))
        return profile.startKg + (profile.goalKg - profile.startKg) * t
    }

    /// Fortschritt von Start zu Ziel (0…1)
    var goalProgress: Double {
        let total = profile.startKg - profile.goalKg
        guard abs(total) > 0.1 else { return 1 }
        return min(1, max(0, (profile.startKg - currentKg) / total))
    }

    /// Trend per linearer Regression: kg pro Woche (positiv = abgenommen)
    func weightTrend(days: Int = 28, before end: Date = .now) -> Double? {
        guard let from = Self.calendar.date(byAdding: .day, value: -days, to: end) else { return nil }
        let pts = bodyWeights.filter { $0.date >= from && $0.date <= end }
        guard pts.count >= 3, let first = pts.first, let last = pts.last,
              last.date.timeIntervalSince(first.date) >= 10 * 86400 else { return nil }
        let xs = pts.map { $0.date.timeIntervalSince(first.date) / 86400 }
        let ys = pts.map(\.kg)
        let n = Double(pts.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for i in 0..<pts.count {
            num += (xs[i] - mx) * (ys[i] - my)
            den += (xs[i] - mx) * (xs[i] - mx)
        }
        guard den > 0 else { return nil }
        return -num / den * 7
    }

    /// Voraussichtliches Datum, an dem das Ziel beim aktuellen Tempo erreicht ist
    var goalForecast: Date? {
        guard goalDirection != .keep, let trend = weightTrend(), abs(trend) > 0.05 else { return nil }
        let left = currentKg - profile.goalKg
        guard left / trend > 0 else { return nil }
        let weeks = left / trend
        guard weeks < 260 else { return nil }
        return Self.calendar.date(byAdding: .day, value: Int(weeks * 7), to: .now)
    }

    func dayType(_ date: Date) -> DayType {
        guard let plan else { return .rest }
        let wd = Self.weekdayIndex(date)
        if plan.days.contains(where: { $0.weekday == wd }) { return .training }
        // An Tagen mit gespeichertem Training zählt es auch als Trainingstag
        return trained(on: date) ? .training : .rest
    }

    func calorieTarget(on date: Date) -> Int {
        baseIntake + (dayType(date) == .training ? trainingBonus : 0)
    }

    // MARK: Mahlzeiten

    func meals(on date: Date) -> [PlannedMeal] {
        let type = dayType(date)
        let slots = type == .training ? MealSlot.training : MealSlot.rest
        let target = Double(calorieTarget(on: date))
        let dayNo = max(0, Self.days(from: BodyProfile.date("2026-01-01"), to: date))
        let key = Self.dayKey(date)
        var used: [String] = []
        var out: [PlannedMeal] = []

        for (si, slot) in slots.enumerated() {
            let pool = recipePool(slot: slot, type: type)
            guard !pool.isEmpty else { continue }
            var idx = (dayNo + si * 3) % pool.count
            var k = 0
            while k < pool.count && used.contains(pool[idx].id) {
                idx = (idx + 1) % pool.count
                k += 1
            }
            var recipe = pool[idx]
            if let pick = mealPicks["\(key)|\(si)"],
               let picked = recipeBook.recipes.first(where: { $0.id == pick }) {
                recipe = picked
            }
            used.append(recipe.id)
            let factor = (min(1.7, max(0.6, target * slot.share / Double(max(1, recipe.kcal)))) * 20).rounded() / 20
            out.append(PlannedMeal(key: "\(key)|\(si)", slotIndex: si, slot: slot, recipe: recipe, factor: factor))
        }
        return out
    }

    /// Passende Gerichte für eine Mahlzeit. Beim Abnehmen gibt es an Ruhetagen nur kohlenhydratarme Gerichte,
    /// nach dem Training bevorzugt etwas mit Kohlenhydraten.
    func recipePool(slot: MealSlot, type: DayType) -> [Recipe] {
        let all = recipeBook.recipes.filter { $0.tags.contains(slot.tag) }
        if type == .rest && goalDirection == .lose {
            let low = all.filter { !$0.isCarb }
            return low.isEmpty ? all : low
        }
        if type == .training && slot.tag == "snack" {
            let post = all.filter { $0.isCarb || $0.id == "shake" }
            return post.isEmpty ? all : post
        }
        return all
    }

    func swapOptions(for meal: PlannedMeal) -> [Recipe] {
        recipeBook.recipes.filter { $0.tags.contains(meal.slot.tag) }
    }

    func pickRecipe(_ recipeID: String, for meal: PlannedMeal) {
        mealPicks[meal.key] = recipeID
        save()
    }

    func isEaten(_ meal: PlannedMeal) -> Bool { eaten.contains(meal.key) }

    func toggleEaten(_ meal: PlannedMeal) {
        if eaten.contains(meal.key) { eaten.remove(meal.key) } else { eaten.insert(meal.key) }
        save()
    }

    func foods(on date: Date) -> [FoodEntry] {
        foodLog.filter { Self.calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }

    func addFood(_ entry: FoodEntry) {
        foodLog.append(entry)
        if let cut = Self.calendar.date(byAdding: .day, value: -120, to: .now) {
            foodLog.removeAll { $0.date < cut }
        }
        save()
    }

    func deleteFood(_ id: UUID) {
        foodLog.removeAll { $0.id == id }
        save()
    }

    func eatenTotals(on date: Date) -> (kcal: Int, protein: Int, carbs: Int) {
        let m = meals(on: date).filter { eaten.contains($0.key) }
        let f = foods(on: date)
        let kcal = m.reduce(0) { $0 + $1.kcal } + f.reduce(0) { $0 + $1.kcal }
        let protein = m.reduce(0) { $0 + $1.protein } + f.reduce(0) { $0 + $1.protein }
        let carbs = m.reduce(0) { $0 + $1.carbs }
        return (kcal, protein, carbs)
    }

    func shoppingList(from start: Date, days: Int) -> [ShoppingItem] {
        var sums: [String: Double] = [:]
        for i in 0..<days {
            guard let d = Self.calendar.date(byAdding: .day, value: i, to: start) else { continue }
            for meal in meals(on: d) {
                for ing in meal.ingredients where ing.qty > 0 {
                    sums["\(ing.name)|\(ing.unit)", default: 0] += ing.qty
                }
            }
        }
        return sums.map { key, qty -> ShoppingItem in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            return ShoppingItem(name: parts[0], text: NutritionMath.format(qty, parts.count > 1 ? parts[1] : ""))
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

// Fehlertolerantes Laden: fehlende Felder (z. B. aus älteren Versionen) bekommen den Standardwert.
extension BodyProfile {
    private enum CodingKeys: String, CodingKey {
        case configured, sex, heightCm, age, activity, startKg, startDate, goalKg, goalDate, autoCalories, calorieAdjust
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configured = try c.decodeIfPresent(Bool.self, forKey: .configured) ?? configured
        sex = try c.decodeIfPresent(Sex.self, forKey: .sex) ?? sex
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm) ?? heightCm
        age = try c.decodeIfPresent(Int.self, forKey: .age) ?? age
        activity = try c.decodeIfPresent(ActivityLevel.self, forKey: .activity) ?? activity
        startKg = try c.decodeIfPresent(Double.self, forKey: .startKg) ?? startKg
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? startDate
        goalKg = try c.decodeIfPresent(Double.self, forKey: .goalKg) ?? goalKg
        goalDate = try c.decodeIfPresent(Date.self, forKey: .goalDate) ?? goalDate
        autoCalories = try c.decodeIfPresent(Bool.self, forKey: .autoCalories) ?? autoCalories
        calorieAdjust = try c.decodeIfPresent(Int.self, forKey: .calorieAdjust) ?? calorieAdjust
    }
}
