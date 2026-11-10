import Foundation

// MARK: - Übungskatalog (aus Resources/catalog.json)

struct ExerciseVariant: Codable, Hashable {
    let name: String?
    let equipment: String?
    let steps: [String]?
    let mistakes: String?
}

struct AnimRef: Codable, Hashable {
    let a: String
    let b: String
    let hop: Double
    let period: Double
}

struct Exercise: Codable, Hashable {
    let name: String
    let equipment: String
    let steps: [String]
    let mistakes: String
    let why: String
    let sets: Int
    let reps: Int
    /// "reps", "s" (Sekunden) oder "min"
    let unit: String
    let prop: String
    let gym: ExerciseVariant?
    let home: String?
    let photo: String?
    let photoGym: String?
    let anim: AnimRef?
}

struct SessionType: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let label: String
    let icon: String
    let colors: [String]
    let category: String
    let exercises: [String]
    let info: String
    let gymExtra: [String]
}

struct Goal: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let info: String
    let priority: [String]
    let test: String
}

struct TestDef: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let unit: String
    let higherIsBetter: Bool
    let hint: String
}

struct Catalog: Codable {
    let exercises: [String: Exercise]
    let sessions: [SessionType]
    let goals: [Goal]
    let tests: [TestDef]
    let poses: [String: [Double]]

    static let shared: Catalog = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cat = try? JSONDecoder().decode(Catalog.self, from: data) else {
            fatalError("catalog.json fehlt oder ist ungültig")
        }
        return cat
    }()

    func session(_ id: String) -> SessionType? { sessions.first { $0.id == id } }
    func goal(_ id: String?) -> Goal? { guard let id else { return nil }; return goals.first { $0.id == id } }
    func test(_ id: String) -> TestDef? { tests.first { $0.id == id } }

    /// Reihenfolge für die Kategorie-Zuordnung (wie in der Web-App)
    static let categoryOrder = ["kraftA", "kraftB", "explo", "react", "mob", "run", "hiit", "gymA", "gymB", "gymC"]
    static let categories = ["Alle", "Gym", "Kraft", "Explosiv", "Reaktion", "Beweglichkeit", "Ausdauer"]
}

// MARK: - Gespeicherte Daten

struct SetEntry: Codable, Hashable {
    var kg: Double
    var reps: Int
}

struct WorkoutLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var session: String
    var date: Date
    var minutes: Int
    var sets: [String: [SetEntry]]
    var rpe: Int?
    var volume: Double
    // nur bei übernommenen Trainings (Strava, Garmin …)
    var title: String?
    var source: String?
    var healthID: String?
    var kcal: Int?
    var avgHR: Int?
}

struct RunCoordinate: Codable, Hashable {
    var lat: Double
    var lon: Double
}

struct RunLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var km: Double
    var minutes: Int
    var kcal: Int
    var type: String          // wr, easy, long, int, free oder FreeActivity.rawValue
    var title: String
    var route: [RunCoordinate] = []
    var avgHR: Int?
    var maxHR: Int?
    var healthID: String?        // UUID des Trainings in Apple Health (bei Import)
    var source: String?          // z. B. "Strava", "Garmin Connect"
    var paceMinPerKm: Double? { km > 0.2 ? Double(minutes) / km : nil }
}

struct ProgramRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var goal: String
    var start: Date
    var end: Date
    var weeks: Int
    var units: Int
    var adherence: Int
    var completed: Bool
    var testFrom: Double?
    var testTo: Double?
}

/// Selbst erfasstes Essen (Foto + KI-Schätzung oder von Hand), zusätzlich zum Essensplan
struct FoodEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var day: String          // "yyyy-MM-dd"
    var date: Date
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var note: String?
}

/// Gespeicherte Video-Technikanalyse
struct TechniqueLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var exercise: String
    var date: Date
    var text: String
}

struct TestEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var test: String
    var value: Double
    var date: Date
}

struct ChatMessage: Codable, Identifiable, Hashable {
    var id = UUID()
    var role: String   // "user" oder "assistant"
    var text: String
}

struct Readiness: Codable, Hashable {
    var sleep: Int?
    var legs: Int?
    var energy: Int?
    var score: Double? {
        guard let a = sleep, let b = legs, let c = energy else { return nil }
        return Double(a + b + c) / 3
    }
}

struct AppState: Codable {
    var name = "Timo"
    var goal: String? = nil
    var days = 3
    /// 0 = Montag … 6 = Sonntag, -1 = kein fester Spieltag
    var gameDay = 6
    /// "gym" oder "home"
    var place = "gym"
    var shortMode = false
    var blockStart = DateUtil.weekStart(Date())
    var logs: [WorkoutLog] = []
    var tests: [TestEntry] = []
    var readiness: [String: Readiness] = [:]
    var chat: [ChatMessage] = []
    var healthEnabled = false
    var remindersEnabled = false
    var reminderHour = 17
    var reminderMinute = 0
    // Stufe 2: Dienstplan, Abnehmen, Ernährung
    var shifts: [String: String] = [:]       // manuelle Änderungen am Dienstplan ("yyyy-MM-dd" → F/D/N/"-")
    var body = BodyProfile()
    var weights: [WeightEntry] = [WeightEntry(date: DateUtil.parse("2026-08-23"), kg: 115), WeightEntry(date: DateUtil.parse("2026-10-04"), kg: 118)]
    var eaten: Set<String> = []
    var mealPicks: [String: String] = [:]     // "yyyy-MM-dd|slot" → Rezept-ID
    var stepsLog: [String: Int] = [:]
    // Laufplan
    var runsPerWeek = 2
    var runPlanStart = DateUtil.weekStart(Date())
    var runs: [RunLog] = []
    // Lauf-Coach
    var coachVoice = true
    var hrSource = "none"        // none, ble, watch
    var maxHR = 0                // 0 = automatisch (208 − 0,7 × Alter)
    // Pläne: Ziel mit Dauer, jederzeit beendbar
    var programStart: Date?
    var programWeeks = 8         // 0 = offen
    var programs: [ProgramRecord] = []
    var savedRunsPerWeek = 2
    // Freies Training & Technik-Analyse
    var intervals: [IntervalProgram] = []
    var analyses: [TechniqueLog] = []
    var foodLog: [FoodEntry] = []

    init() {}

    // Tolerantes Dekodieren: fehlende Felder bekommen Standardwerte (für spätere Versionen).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        goal = try c.decodeIfPresent(String.self, forKey: .goal)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? d.days
        gameDay = try c.decodeIfPresent(Int.self, forKey: .gameDay) ?? d.gameDay
        place = try c.decodeIfPresent(String.self, forKey: .place) ?? d.place
        shortMode = try c.decodeIfPresent(Bool.self, forKey: .shortMode) ?? d.shortMode
        blockStart = try c.decodeIfPresent(Date.self, forKey: .blockStart) ?? d.blockStart
        logs = try c.decodeIfPresent([WorkoutLog].self, forKey: .logs) ?? []
        tests = try c.decodeIfPresent([TestEntry].self, forKey: .tests) ?? []
        readiness = try c.decodeIfPresent([String: Readiness].self, forKey: .readiness) ?? [:]
        chat = try c.decodeIfPresent([ChatMessage].self, forKey: .chat) ?? []
        healthEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthEnabled) ?? false
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? d.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? d.reminderMinute
        shifts = try c.decodeIfPresent([String: String].self, forKey: .shifts) ?? [:]
        body = try c.decodeIfPresent(BodyProfile.self, forKey: .body) ?? d.body
        weights = try c.decodeIfPresent([WeightEntry].self, forKey: .weights) ?? d.weights
        eaten = try c.decodeIfPresent(Set<String>.self, forKey: .eaten) ?? []
        mealPicks = try c.decodeIfPresent([String: String].self, forKey: .mealPicks) ?? [:]
        stepsLog = try c.decodeIfPresent([String: Int].self, forKey: .stepsLog) ?? [:]
        runsPerWeek = try c.decodeIfPresent(Int.self, forKey: .runsPerWeek) ?? d.runsPerWeek
        runPlanStart = try c.decodeIfPresent(Date.self, forKey: .runPlanStart) ?? d.runPlanStart
        runs = try c.decodeIfPresent([RunLog].self, forKey: .runs) ?? []
        coachVoice = try c.decodeIfPresent(Bool.self, forKey: .coachVoice) ?? true
        hrSource = try c.decodeIfPresent(String.self, forKey: .hrSource) ?? "none"
        maxHR = try c.decodeIfPresent(Int.self, forKey: .maxHR) ?? 0
        programStart = try c.decodeIfPresent(Date.self, forKey: .programStart)
        programWeeks = try c.decodeIfPresent(Int.self, forKey: .programWeeks) ?? 0
        programs = try c.decodeIfPresent([ProgramRecord].self, forKey: .programs) ?? []
        savedRunsPerWeek = try c.decodeIfPresent(Int.self, forKey: .savedRunsPerWeek) ?? 2
        intervals = try c.decodeIfPresent([IntervalProgram].self, forKey: .intervals) ?? []
        analyses = try c.decodeIfPresent([TechniqueLog].self, forKey: .analyses) ?? []
        foodLog = try c.decodeIfPresent([FoodEntry].self, forKey: .foodLog) ?? []
        if goal != nil && programStart == nil { programStart = blockStart }   // älterer Stand ohne Plan-Daten
    }
}

// MARK: - Datum (Woche beginnt Montag)

enum DateUtil {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        c.locale = Locale(identifier: "de_DE")
        return c
    }()

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// 0 = Montag … 6 = Sonntag
    static func dayIndex(_ date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date) // 1 = Sonntag
        return (wd + 5) % 7
    }

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    static let weekdaysShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    static func format(_ date: Date, _ template: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: date)
    }
}
