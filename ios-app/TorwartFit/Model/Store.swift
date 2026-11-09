import Foundation
import SwiftUI

struct Dose: Hashable {
    var sets: Int
    var reps: Int
    var unit: String
    var timed: Bool { unit == "s" || unit == "min" }
    var seconds: Int { unit == "min" ? reps * 60 : unit == "s" ? reps : 0 }
    var text: String {
        switch unit {
        case "s": return "\(sets) × \(reps) s"
        case "min": return "\(sets) × \(reps) min"
        default: return "\(sets) × \(reps)"
        }
    }
    var targetText: String {
        switch unit {
        case "s": return "\(reps) s"
        case "min": return "\(reps) min"
        default: return "\(reps) Wdh."
        }
    }
}

struct BlockWeek {
    let name: String
    let setDelta: Int
    let repDelta: Int
    static let all = [
        BlockWeek(name: "Einstieg", setDelta: 0, repDelta: 0),
        BlockWeek(name: "Mehr Volumen", setDelta: 1, repDelta: 0),
        BlockWeek(name: "Mehr Intensität", setDelta: 1, repDelta: 2),
        BlockWeek(name: "Entlastung", setDelta: -1, repDelta: -2),
    ]
}

/// Starten eines geführten Trainings (für fullScreenCover)
struct Launch: Identifiable, Hashable {
    let id = UUID()
    let session: String
    let short: Bool
}

final class Store: ObservableObject {
    let catalog = Catalog.shared

    @Published var s: AppState { didSet { scheduleSave() } }
    @Published var launch: Launch?
    @Published var runLaunch: RunLaunch?
    @Published var steps: Double = 0
    @Published var weight: Double?

    private var saveWork: DispatchWorkItem?
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("state.json")
    }()

    init() {
        if let data = try? Data(contentsOf: Store.fileURL),
           let st = try? Store.decoder.decode(AppState.self, from: data) {
            s = st
        } else {
            s = AppState()
        }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = s
        let url = Store.fileURL
        let w = DispatchWorkItem {
            if let data = try? Store.encoder.encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
        saveWork = w
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: w)
    }

    // MARK: Block & Plan

    var weekIndex: Int {
        let a = DateUtil.weekStart(s.blockStart), b = DateUtil.weekStart(Date())
        let weeks = Int((b.timeIntervalSince(a) / (7 * 86400)).rounded(.down))
        return ((weeks % 4) + 4) % 4
    }
    var blockWeek: BlockWeek { BlockWeek.all[weekIndex] }
    func setWeekIndex(_ i: Int) {
        s.blockStart = DateUtil.calendar.date(byAdding: .day, value: -7 * i, to: DateUtil.weekStart(Date())) ?? Date()
    }

    var goal: Goal? { catalog.goal(s.goal) }

    /// Plan für einen Wochentag (0 = Mo). "game" = Spiel, nil = frei.
    func plan(for day: Int) -> String? {
        let pri = Array((goal ?? catalog.goal("sprung")!).priority.prefix(s.days))
        if s.gameDay < 0 {
            let slots = Array([0, 4, 2, 5, 1].prefix(s.days))
            guard let k = slots.firstIndex(of: day), k < pri.count else { return nil }
            return pri[k]
        }
        let o = (day - s.gameDay + 7) % 7
        if o == 0 { return "game" }
        if o == 6 { return "mobS" }
        let slots = Array([2, 4, 3, 1, 5].prefix(s.days))
        guard let k = slots.firstIndex(of: o), k < pri.count else { return nil }
        return pri[k]
    }

    var todayIndex: Int { DateUtil.dayIndex(Date()) }

    func done(_ session: String, on day: Int) -> Bool {
        let ws = DateUtil.weekStart(Date())
        return s.logs.contains { $0.session == session && $0.date >= ws && DateUtil.dayIndex($0.date) == day }
    }

    var weeklyGoal: Int { s.days + (s.gameDay < 0 ? 0 : 1) }

    // MARK: Übungen

    func ex(_ id: String) -> Exercise? { catalog.exercises[id] }

    func name(_ id: String) -> String {
        guard let e = ex(id) else { return id }
        if s.place == "gym", let n = e.gym?.name { return n }
        if s.place == "home", let h = e.home { return h }
        return e.name
    }
    func equipment(_ id: String) -> String {
        guard let e = ex(id) else { return "" }
        if s.place == "gym", let q = e.gym?.equipment { return q }
        return e.equipment
    }
    func steps(_ id: String) -> [String] {
        guard let e = ex(id) else { return [] }
        if s.place == "gym", let st = e.gym?.steps { return st }
        return e.steps
    }
    func mistakes(_ id: String) -> String {
        guard let e = ex(id) else { return "" }
        if s.place == "gym", let m = e.gym?.mistakes { return m }
        return e.mistakes
    }
    func photo(_ id: String) -> String? {
        guard let e = ex(id) else { return nil }
        if s.place == "gym", let p = e.photoGym { return p }
        return e.photo
    }

    func category(_ id: String) -> String {
        for sid in Catalog.categoryOrder {
            if let se = catalog.session(sid), se.exercises.contains(id) || se.gymExtra.contains(id) { return se.category }
        }
        return "Kraft"
    }

    func dose(_ id: String, short: Bool = false) -> Dose {
        guard let e = ex(id) else { return Dose(sets: 3, reps: 10, unit: "reps") }
        var sets = e.sets, reps = e.reps
        let unit = e.unit, cat = category(id)
        if s.goal == "kraft" && cat == "Kraft" && unit == "reps" { sets += 1; reps = max(5, reps - 3) }
        if (s.goal == "sprung" || s.goal == "speed") && (cat == "Explosiv" || cat == "Reaktion") { sets += 1 }
        if s.goal == "mobil" && cat == "Beweglichkeit" && unit == "s" { reps += 15 }
        if s.goal == "praev" && ["nord", "cop", "side", "ytw", "pall", "calf"].contains(id) { sets += 1 }
        if unit != "min" {
            let w = blockWeek
            sets = max(1, sets + w.setDelta - (short ? 1 : 0))
            reps = max(1, reps + (unit == "s" ? w.repDelta * 5 : w.repDelta))
        }
        return Dose(sets: sets, reps: reps, unit: unit)
    }

    func exercises(of session: String, short: Bool = false) -> [String] {
        guard let se = catalog.session(session) else { return [] }
        var list = se.exercises
        if s.place == "gym" && !se.gymExtra.isEmpty { list.insert(contentsOf: se.gymExtra, at: min(1, list.count)) }
        if short { list = Array(list.prefix(Int((Double(list.count) * 0.6).rounded(.up)))) }
        return list
    }

    func rest(_ id: String) -> Int {
        guard let e = ex(id) else { return 60 }
        let c = category(id)
        if e.unit == "min" { return 0 }
        if c == "Beweglichkeit" { return 15 }
        if e.unit == "s" { return 30 }
        switch c { case "Explosiv", "Gym": return 90; case "Reaktion": return 45; default: return 75 }
    }

    func isLoaded(_ id: String) -> Bool {
        guard let e = ex(id) else { return false }
        let c = category(id)
        return e.unit == "reps" && (c == "Kraft" || c == "Gym")
    }

    func minutes(_ session: String, short: Bool = false) -> Int {
        let total = exercises(of: session, short: short).reduce(0.0) { m, id in
            let d = dose(id, short: short)
            if d.unit == "min" { return m + Double(d.sets * d.reps) }
            let work = d.seconds > 0 ? Double(d.seconds) : 40
            return m + Double(d.sets) * (work + Double(rest(id))) / 60
        }
        return max(5, Int((total / 5).rounded()) * 5)
    }

    // MARK: Fortschritt

    func lastSets(_ id: String) -> [SetEntry]? {
        for log in s.logs.reversed() { if let st = log.sets[id], !st.isEmpty { return st } }
        return nil
    }
    func bestKg(_ id: String) -> Double {
        s.logs.flatMap { $0.sets[id] ?? [] }.map(\.kg).max() ?? 0
    }
    /// Text zur letzten Leistung + Vorschlag für mehr Gewicht
    func progression(_ id: String, short: Bool = false) -> (text: String, up: Double?)? {
        guard isLoaded(id), let last = lastSets(id) else { return nil }
        let d = dose(id, short: short)
        let kg = last.map(\.kg).max() ?? 0
        let hit = last.count >= d.sets && last.allSatisfy { $0.reps >= d.reps }
        let text = "Letztes Mal: " + last.map { ($0.kg > 0 ? "\(fmtKg($0.kg)) kg × " : "") + "\($0.reps)" }.joined(separator: ", ")
        let up: Double? = (hit && kg > 0) ? ((kg * 1.05) / 1.25).rounded() * 1.25 : nil
        return (text, up)
    }

    var todayReadiness: Readiness { s.readiness[DateUtil.dayKey()] ?? Readiness() }
    var isTired: Bool { (todayReadiness.score ?? 5) < 2.7 }

    var streak: Int {
        let ws = DateUtil.weekStart(Date())
        var n = 0
        for w in 0..<300 {
            guard let a = DateUtil.calendar.date(byAdding: .day, value: -7 * w, to: ws),
                  let b = DateUtil.calendar.date(byAdding: .day, value: 7, to: a) else { break }
            if s.logs.contains(where: { $0.date >= a && $0.date < b }) { n += 1 } else if w > 0 { break }
        }
        return n
    }
    var logsThisWeek: [WorkoutLog] { let ws = DateUtil.weekStart(Date()); return s.logs.filter { $0.date >= ws } }

    var adherence: Int {
        guard let from = DateUtil.calendar.date(byAdding: .day, value: -21, to: DateUtil.weekStart(Date())) else { return 0 }
        let done = s.logs.filter { $0.date >= from }.count
        return min(100, Int(Double(done) / Double(max(1, s.days * 4)) * 100))
    }

    // MARK: Aktionen

    func start(_ session: String, short: Bool) { launch = Launch(session: session, short: short) }

    func saveWorkout(session: String, start: Date, sets: [String: [SetEntry]], rpe: Int?) {
        let minutes = max(1, Int(Date().timeIntervalSince(start) / 60))
        let vol = sets.values.flatMap { $0 }.reduce(0) { $0 + $1.kg * Double($1.reps) }
        s.logs.append(WorkoutLog(session: session, date: Date(), minutes: minutes, sets: sets, rpe: rpe, volume: vol))
        if s.healthEnabled {
            let kcal = 5.0 * currentKg * Double(minutes) / 60
            Task { await HealthService.shared.saveWorkout(start: start, end: Date(), kcal: kcal) }
        }
    }

    func setReadiness(_ key: WritableKeyPath<Readiness, Int?>, _ v: Int) {
        var r = todayReadiness
        r[keyPath: key] = v
        s.readiness[DateUtil.dayKey()] = r
    }

    func refreshHealth() async {
        guard s.healthEnabled else { return }
        let st = await HealthService.shared.stepsToday()
        let w = await HealthService.shared.latestWeight()
        await MainActor.run { self.steps = st; self.weight = w }
        await importHealthRuns()
    }

    // MARK: Backup

    func exportFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TorwartFit-Backup-\(DateUtil.dayKey()).json")
        if let data = try? Store.encoder.encode(s) { try? data.write(to: url) }
        return url
    }

    /// Importiert ein Backup dieser App oder der Web-App (Torwart Training).
    func importBackup(_ data: Data) -> Bool {
        if let st = try? Store.decoder.decode(AppState.self, from: data), !st.logs.isEmpty || st.goal != nil {
            s = st
            return true
        }
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        var st = s
        if let n = o["name"] as? String { st.name = n }
        if let g = o["goal"] as? String { st.goal = g }
        if let d = o["days"] as? Int { st.days = d }
        if let g = o["game"] as? Int { st.gameDay = g }
        if let e = o["eq"] as? String { st.place = e }
        if let logs = o["log"] as? [[String: Any]] {
            for l in logs {
                guard let t = l["t"] as? String, let ts = l["ts"] as? Double else { continue }
                var sets: [String: [SetEntry]] = [:]
                if let raw = l["sets"] as? [String: [[Double]]] {
                    for (k, v) in raw { sets[k] = v.map { SetEntry(kg: $0.first ?? 0, reps: Int($0.count > 1 ? $0[1] : 0)) } }
                }
                let date = Date(timeIntervalSince1970: ts / 1000)
                if st.logs.contains(where: { abs($0.date.timeIntervalSince(date)) < 1 && $0.session == t }) { continue }
                st.logs.append(WorkoutLog(session: t, date: date, minutes: l["dur"] as? Int ?? 30, sets: sets,
                                          rpe: l["rpe"] as? Int, volume: l["vol"] as? Double ?? 0))
            }
            st.logs.sort { $0.date < $1.date }
        }
        if let tests = o["tests"] as? [[String: Any]] {
            for t in tests {
                guard let k = t["k"] as? String, let v = t["v"] as? Double, let ts = t["ts"] as? Double else { continue }
                st.tests.append(TestEntry(test: k, value: v, date: Date(timeIntervalSince1970: ts / 1000)))
            }
        }
        s = st
        return true
    }
}

func fmtKg(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
}
