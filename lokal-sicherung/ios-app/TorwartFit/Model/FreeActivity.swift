import Foundation
import HealthKit

/// Art eines freien Trainings (Button „Freies Training“)
enum FreeActivity: String, Codable, CaseIterable, Identifiable, Hashable {
    case run, interval, walk, hike, bike, keeper, gym, mobility

    var id: String { rawValue }

    var name: String {
        switch self {
        case .run: return "Lauf"
        case .interval: return "Intervalllauf"
        case .walk: return "Spaziergang"
        case .hike: return "Wandern"
        case .bike: return "Radfahren"
        case .keeper: return "Torwart frei"
        case .gym: return "Kraft frei"
        case .mobility: return "Dehnen & Mobilität"
        }
    }

    var icon: String {
        switch self {
        case .run: return "🏃"
        case .interval: return "⏱️"
        case .walk: return "🚶"
        case .hike: return "🥾"
        case .bike: return "🚴"
        case .keeper: return "🧤"
        case .gym: return "🏋️"
        case .mobility: return "🧘"
        }
    }

    var info: String {
        switch self {
        case .run: return "Freier Lauf mit GPS"
        case .interval: return "Vorlage oder eigene Intervalle"
        case .walk: return "Lockeres Gehen mit GPS"
        case .hike: return "Längere Tour mit GPS"
        case .bike: return "Radtour mit GPS"
        case .keeper: return "Stoppuhr, ohne GPS"
        case .gym: return "Stoppuhr, ohne GPS"
        case .mobility: return "Stoppuhr, ohne GPS"
        }
    }

    var colors: [String] {
        switch self {
        case .run: return ["#FF375F", "#D70F4A"]
        case .interval: return ["#FF9F0A", "#D9480F"]
        case .walk: return ["#30D158", "#1A8F3A"]
        case .hike: return ["#8D6E63", "#5D4037"]
        case .bike: return ["#0A84FF", "#0050B3"]
        case .keeper: return ["#BF5AF2", "#7B2CBF"]
        case .gym: return ["#64D2FF", "#1C7ED6"]
        case .mobility: return ["#5E5CE6", "#3A36B0"]
        }
    }

    var usesGPS: Bool { ![.keeper, .gym, .mobility].contains(self) }
    /// Zählt als Lauf (Laufplan, Tempo, „Gelaufen“)
    var isRun: Bool { self == .run || self == .interval }

    /// Höchstgeschwindigkeit in m/s, darüber gilt ein GPS-Punkt als Sprung
    var maxSpeed: Double { self == .bike ? 20 : 7 }

    /// MET-Wert für die Kalorien ohne Strecke
    var met: Double {
        switch self {
        case .run, .interval: return 9.8
        case .walk: return 3.5
        case .hike: return 6
        case .bike: return 7
        case .keeper: return 7
        case .gym: return 5
        case .mobility: return 2.5
        }
    }

    func kcal(kg: Double, km: Double, seconds: Double) -> Int {
        if isRun && km > 0.2 { return Int(0.92 * kg * km) }
        if self == .walk && km > 0.2 { return Int(0.5 * kg * km) }
        return Int(met * kg * seconds / 3600)
    }

    var healthType: HKWorkoutActivityType {
        switch self {
        case .run, .interval: return .running
        case .walk: return .walking
        case .hike: return .hiking
        case .bike: return .cycling
        case .keeper: return .soccer
        case .gym: return .traditionalStrengthTraining
        case .mobility: return .flexibility
        }
    }

    /// Aktivität zu einem gespeicherten RunLog-Typ
    static func from(logType: String) -> FreeActivity {
        if let a = FreeActivity(rawValue: logType) { return a }
        return logType == "int" || logType == "wr" ? .interval : .run
    }
}

// MARK: - Intervalle

struct IntervalStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var seconds: Int
    var hard: Bool
}

struct IntervalProgram: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var warmup: Int = 600          // Sekunden
    var steps: [IntervalStep]
    var repeats: Int = 5
    var cooldown: Int = 300
    var activity: FreeActivity = .interval

    /// Ein Abschnitt in der fertigen Zeitleiste
    struct Segment: Hashable {
        let name: String
        let seconds: Int
        let hard: Bool
        let round: Int?          // 1 … repeats, nil bei Ein-/Auslaufen
        let start: Int           // Sekunde ab Start
    }

    var timeline: [Segment] {
        var out: [Segment] = []
        var t = 0
        func add(_ n: String, _ s: Int, _ h: Bool, _ r: Int?) {
            guard s > 0 else { return }
            out.append(Segment(name: n, seconds: s, hard: h, round: r, start: t))
            t += s
        }
        add("Einlaufen", warmup, false, nil)
        for r in 1...max(1, repeats) { for st in steps { add(st.name, st.seconds, st.hard, r) } }
        add("Auslaufen", cooldown, false, nil)
        return out
    }

    var totalSeconds: Int { warmup + cooldown + max(1, repeats) * steps.reduce(0) { $0 + $1.seconds } }

    var summary: String {
        let block = steps.map { "\(IntervalProgram.dur($0.seconds)) \($0.name)" }.joined(separator: " / ")
        return "\(max(1, repeats)) × (\(block))"
    }

    static func dur(_ s: Int) -> String {
        if s < 60 { return "\(s) s" }
        if s % 60 == 0 { return "\(s / 60) Min." }
        return String(format: "%d:%02d Min.", s / 60, s % 60)
    }

    static func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    static let presets: [IntervalProgram] = [
        IntervalProgram(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, name: "Lauf-Geh 1/2",
                        warmup: 300, steps: [IntervalStep(name: "Traben", seconds: 60, hard: true),
                                             IntervalStep(name: "Gehen", seconds: 120, hard: false)],
                        repeats: 8, cooldown: 300),
        IntervalProgram(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!, name: "Lauf-Geh 3/1",
                        warmup: 300, steps: [IntervalStep(name: "Traben", seconds: 180, hard: true),
                                             IntervalStep(name: "Gehen", seconds: 60, hard: false)],
                        repeats: 6, cooldown: 300),
        IntervalProgram(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!, name: "30/30 Torwart-Speed",
                        warmup: 600, steps: [IntervalStep(name: "Schnell", seconds: 30, hard: true),
                                             IntervalStep(name: "Locker", seconds: 30, hard: false)],
                        repeats: 10, cooldown: 300),
        IntervalProgram(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!, name: "2/2 Klassiker",
                        warmup: 600, steps: [IntervalStep(name: "Zügig", seconds: 120, hard: true),
                                             IntervalStep(name: "Trab", seconds: 120, hard: false)],
                        repeats: 6, cooldown: 600),
        IntervalProgram(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!, name: "Pyramide 1-2-3-2-1",
                        warmup: 600, steps: [IntervalStep(name: "Zügig", seconds: 60, hard: true), IntervalStep(name: "Trab", seconds: 60, hard: false),
                                             IntervalStep(name: "Zügig", seconds: 120, hard: true), IntervalStep(name: "Trab", seconds: 90, hard: false),
                                             IntervalStep(name: "Zügig", seconds: 180, hard: true), IntervalStep(name: "Trab", seconds: 120, hard: false),
                                             IntervalStep(name: "Zügig", seconds: 120, hard: true), IntervalStep(name: "Trab", seconds: 90, hard: false),
                                             IntervalStep(name: "Zügig", seconds: 60, hard: true), IntervalStep(name: "Trab", seconds: 60, hard: false)],
                        repeats: 1, cooldown: 600),
    ]

    static var blank: IntervalProgram {
        IntervalProgram(name: "Mein Intervall", warmup: 600,
                        steps: [IntervalStep(name: "Schnell", seconds: 60, hard: true),
                                IntervalStep(name: "Locker", seconds: 90, hard: false)],
                        repeats: 6, cooldown: 300)
    }
}

extension Store {
    func startFree(_ a: FreeActivity, program: IntervalProgram? = nil) {
        runLaunch = RunLaunch(plan: nil, activity: program == nil ? a : .interval, program: program)
    }

    func saveInterval(_ p: IntervalProgram) {
        if let i = s.intervals.firstIndex(where: { $0.id == p.id }) { s.intervals[i] = p } else { s.intervals.append(p) }
    }

    func deleteInterval(_ p: IntervalProgram) { s.intervals.removeAll { $0.id == p.id } }

    /// Nur echte Läufe (für Laufplan, Tempo und „Gelaufen“)
    var runOnly: [RunLog] { s.runs.filter { FreeActivity.from(logType: $0.type).isRun } }
}
