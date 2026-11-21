import Foundation
import SwiftUI

// MARK: - Einstellungen für den Plan

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case muscle, strength, fatLoss, fitness
    var id: String { rawValue }

    var title: String {
        switch self {
        case .muscle: return "Muskelaufbau"
        case .strength: return "Maximalkraft"
        case .fatLoss: return "Fettabbau"
        case .fitness: return "Fitness"
        }
    }

    var subtitle: String {
        switch self {
        case .muscle: return "6–12 Wdh., mehr Volumen"
        case .strength: return "4–6 Wdh., lange Pausen"
        case .fatLoss: return "10–15 Wdh., kurze Pausen"
        case .fitness: return "12–20 Wdh., Ausdauer"
        }
    }

    var icon: String {
        switch self {
        case .muscle: return "figure.strengthtraining.traditional"
        case .strength: return "scalemass.fill"
        case .fatLoss: return "flame.fill"
        case .fitness: return "heart.fill"
        }
    }
}

enum ExperienceLevel: Int, Codable, CaseIterable, Identifiable {
    case beginner = 0, intermediate = 1, advanced = 2
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Anfänger"
        case .intermediate: return "Fortgeschritten"
        case .advanced: return "Profi"
        }
    }
}

enum EquipmentSetup: String, Codable, CaseIterable, Identifiable {
    case gym, dumbbells, bodyweight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: return "Fitnessstudio"
        case .dumbbells: return "Kurzhanteln & Bank"
        case .bodyweight: return "Körpergewicht"
        }
    }

    var subtitle: String {
        switch self {
        case .gym: return "Langhantel, Maschinen, Kabelzug"
        case .dumbbells: return "Zuhause mit Hanteln"
        case .bodyweight: return "Ohne Geräte, evtl. Klimmzugstange"
        }
    }

    var icon: String {
        switch self {
        case .gym: return "building.2.fill"
        case .dumbbells: return "dumbbell.fill"
        case .bodyweight: return "figure.cooldown"
        }
    }

    var gear: Set<Gear> {
        switch self {
        case .gym: return Set(Gear.allCases)
        case .dumbbells: return [.dumbbell, .bodyweight, .bar]
        case .bodyweight: return [.bodyweight, .bar]
        }
    }
}

enum TrainingFocus: String, Codable, CaseIterable, Identifiable {
    case balanced, upper, legs, arms, back
    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "Ausgewogen"
        case .upper: return "Brust & Schultern"
        case .legs: return "Beine & Po"
        case .arms: return "Arme"
        case .back: return "Rücken & Haltung"
        }
    }

    /// Bewegungsmuster, die beim Schwerpunkt zusätzlich und mit einem Satz mehr trainiert werden.
    var patterns: [MovementPattern] {
        switch self {
        case .balanced: return []
        case .upper: return [.chestIso, .shoulderIso]
        case .legs: return [.glute, .lunge]
        case .arms: return [.biceps, .triceps]
        case .back: return [.horizontalPull, .rearDelt]
        }
    }
}

enum Limitation: String, Codable, CaseIterable, Identifiable {
    case knee, shoulder, lowerBack
    var id: String { rawValue }

    var title: String {
        switch self {
        case .knee: return "Knie"
        case .shoulder: return "Schulter"
        case .lowerBack: return "Unterer Rücken"
        }
    }
}

// MARK: - Übungen

enum Muscle: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .shoulders: return "Schultern"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .quads: return "Oberschenkel vorne"
        case .hamstrings: return "Oberschenkel hinten"
        case .glutes: return "Po"
        case .calves: return "Waden"
        case .core: return "Bauch & Rumpf"
        }
    }

    var color: Color {
        switch self {
        case .chest: return .red
        case .back: return .blue
        case .shoulders: return .orange
        case .biceps: return .purple
        case .triceps: return .pink
        case .quads: return .green
        case .hamstrings: return .teal
        case .glutes: return .mint
        case .calves: return .cyan
        case .core: return .yellow
        }
    }
}

enum MovementPattern: String, Codable, CaseIterable {
    case squat, hinge, lunge
    case horizontalPush, verticalPush, horizontalPull, verticalPull
    case chestIso, shoulderIso, rearDelt, biceps, triceps
    case quadIso, hamIso, glute, calves, core

    var muscle: Muscle {
        switch self {
        case .squat, .lunge, .quadIso: return .quads
        case .hinge, .hamIso: return .hamstrings
        case .horizontalPush, .chestIso: return .chest
        case .verticalPush, .shoulderIso, .rearDelt: return .shoulders
        case .horizontalPull, .verticalPull: return .back
        case .biceps: return .biceps
        case .triceps: return .triceps
        case .glute: return .glutes
        case .calves: return .calves
        case .core: return .core
        }
    }
}

enum Gear: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight, bar

    var title: String {
        switch self {
        case .barbell: return "Langhantel"
        case .dumbbell: return "Kurzhantel"
        case .machine: return "Maschine"
        case .cable: return "Kabelzug"
        case .bodyweight: return "Körpergewicht"
        case .bar: return "Stange / Barren"
        }
    }
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let pattern: MovementPattern
    let gear: Gear
    let level: Int
    let compound: Bool
    let avoid: Set<Limitation>
    let timed: Bool
    let cues: [String]

    var muscle: Muscle { pattern.muscle }

    /// Gewichtssprung, wenn alle Wiederholungen geschafft wurden.
    var increment: Double {
        switch gear {
        case .barbell: return compound ? 2.5 : 1.25
        case .dumbbell: return 2
        case .machine, .cable: return 2.5
        case .bodyweight, .bar: return 2.5
        }
    }

    var repUnit: String { timed ? "Sek." : "Wdh." }
}

// MARK: - Plan

struct PlanSettings: Codable, Hashable {
    var goal: TrainingGoal
    var level: ExperienceLevel
    var weekdays: [Int]          // 1 = Montag … 7 = Sonntag
    var minutes: Int
    var equipment: EquipmentSetup
    var focus: TrainingFocus
    var limitations: Set<Limitation>
    var weeks: Int               // 0 = offen
}

struct PlanExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: Int
    var repLow: Int
    var repHigh: Int
    var rest: Int
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: String
    var weekday: Int?
    var exercises: [PlanExercise]
}

struct TrainingPlan: Codable, Identifiable {
    var id = UUID()
    var created: Date
    var title: String
    var split: String
    var settings: PlanSettings
    var days: [PlanDay]
}

// MARK: - Protokoll

struct SetLog: Codable, Hashable {
    var weight: Double
    var reps: Int
}

struct ExerciseLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: [SetLog]

    var volume: Double { sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) } }
}

struct WorkoutLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var duration: TimeInterval
    var dayName: String
    var exercises: [ExerciseLog]
    var prs: [String]

    var volume: Double { exercises.reduce(0.0) { $0 + $1.volume } }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
}

struct BodyEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kg: Double
}

// MARK: - Laufendes Training

struct ActiveSet: Codable, Identifiable, Hashable {
    var id: UUID
    var weight: String
    var reps: String
    var done: Bool
    var hintWeight: String
    var hintReps: String

    init(weight: String = "", reps: String = "", hintWeight: String, hintReps: String) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.done = false
        self.hintWeight = hintWeight
        self.hintReps = hintReps
    }
}

struct ActiveExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var repLow: Int
    var repHigh: Int
    var rest: Int
    var sets: [ActiveSet]
    var note: String?
}

struct ActiveWorkout: Codable, Hashable {
    var start: Date
    var dayName: String
    var planDayID: UUID?
    var exercises: [ActiveExercise]
    var restStart: Date?
    var restEnd: Date?

    static let placeholder = ActiveWorkout(start: .now, dayName: "", planDayID: nil, exercises: [])

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var doneSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.done).count } }
}

// MARK: - Formatierung

enum Fmt {
    static func kg(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(t)
    }

    static func volume(_ kg: Double) -> String {
        if kg >= 1000 {
            return (kg / 1000).formatted(.number.precision(.fractionLength(1))) + " t"
        }
        return kg.formatted(.number.precision(.fractionLength(0))) + " kg"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        if m >= 60 { return "\(m / 60) h \(m % 60) min" }
        return "\(m) min"
    }

    static let weekdayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let weekdayLong = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    static func weekdayName(_ index: Int, short: Bool = false) -> String {
        guard (1...7).contains(index) else { return "" }
        return short ? weekdayShort[index - 1] : weekdayLong[index - 1]
    }
}
