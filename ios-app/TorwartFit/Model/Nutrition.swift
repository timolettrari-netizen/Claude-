import Foundation

// MARK: - Ernährungsdaten (Resources/nutrition.json, aus dem Fitness-Coach übernommen)

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
}

struct MealSlot: Codable, Hashable {
    let name: String
    let time: String
    let tag: String
    let share: Double
    let late: Bool
}

struct Snack: Codable, Hashable { let name: String; let info: String }

struct ShiftPattern: Codable { let anchor: String; let cycle: [String] }

struct NutritionData: Codable {
    let recipes: [Recipe]
    let slots: [String: [MealSlot]]
    let kindNames: [String: String]
    let tips: [String: String]
    let snacks: [Snack]
    let shiftPattern: ShiftPattern

    static let shared: NutritionData = {
        guard let url = Bundle.main.url(forResource: "nutrition", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let n = try? JSONDecoder().decode(NutritionData.self, from: data) else {
            fatalError("nutrition.json fehlt oder ist ungültig")
        }
        return n
    }()
}

/// Eine geplante Mahlzeit, auf das Kalorienziel skaliert
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
    var ingredients: [(name: String, qty: Double, unit: String)] {
        recipe.ingredients.map { i in (i.name, i.qty > 0 ? Nutrition.scale(i.qty, unit: i.unit, factor: factor, whole: i.whole) : 0, i.unit) }
    }
}

enum Nutrition {
    static func scale(_ q: Double, unit: String, factor: Double, whole: Bool) -> Double {
        let v = q * factor
        if unit == "g" || unit == "ml" { return v < 10 ? v.rounded() : (v / 5).rounded() * 5 }
        if whole { return max(1, v.rounded()) }
        return max(0.5, (v * 2).rounded() / 2)
    }

    static func format(_ q: Double, _ unit: String) -> String {
        if unit == "g" && q >= 1000 { return String(format: "%.1f kg", q / 1000).replacingOccurrences(of: ".", with: ",") }
        let n = q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.1f", q).replacingOccurrences(of: ".", with: ",")
        return "\(n) \(unit)"
    }

    /// Schichtart des Tages: F = frei, F1 = frei nach Nachtdienst, D = Spät, N = Früh/Nacht
    static let shiftNames = ["F": "Frei", "D": "Spätdienst", "N": "Früh/Nacht"]
    static let kindInfo = [
        "F": "Zeit für Training und Erholung",
        "F1": "Erst ausschlafen, Training am Abend",
        "D": "12:30–18:30 · Training am Vormittag",
        "N": "5:30–12:30 und 18:30–5:30",
    ]
}

// MARK: - Körper & Gewicht

struct BodyProfile: Codable, Hashable {
    var heightCm = 189.0
    var age = 33
    var startKg = 115.0
    var startDate = DateUtil.parse("2026-08-23")
    var goalKg = 100.0
    var goalDate = DateUtil.parse("2027-03-31")
    var stepGoal = 10000
    var calorieAdjust = 0
}

struct WeightEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var kg: Double
}

extension DateUtil {
    static func parse(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
    static func days(from a: Date, to b: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }
}
