import Foundation

/// Erstellt aus Ziel, Erfahrung, Trainingstagen, Zeit, Ausrüstung, Schwerpunkt und Einschränkungen einen Trainingsplan.
enum PlanGenerator {

    enum DayKind {
        case full, upper, lower, push, pull, legs

        var title: String {
            switch self {
            case .full: return "Ganzkörper"
            case .upper: return "Oberkörper"
            case .lower: return "Unterkörper"
            case .push: return "Drücken"
            case .pull: return "Ziehen"
            case .legs: return "Beine"
            }
        }

        var allowed: Set<MovementPattern> {
            switch self {
            case .full: return Set(MovementPattern.allCases)
            case .upper: return [.horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .chestIso, .shoulderIso, .rearDelt, .biceps, .triceps]
            case .lower, .legs: return [.squat, .hinge, .lunge, .quadIso, .hamIso, .glute, .calves, .core]
            case .push: return [.horizontalPush, .verticalPush, .chestIso, .shoulderIso, .triceps]
            case .pull: return [.horizontalPull, .verticalPull, .rearDelt, .biceps]
            }
        }
    }

    struct DayTemplate {
        let name: String
        let kind: DayKind
        let slots: [MovementPattern]
        let variant: Int
    }

    struct Scheme {
        var sets: Int
        var low: Int
        var high: Int
        var rest: Int
    }

    static let warmupMinutes = 8.0
    static let workSeconds = 40.0

    // MARK: Vorlagen

    private static let fullA: [MovementPattern] = [.squat, .horizontalPush, .horizontalPull, .hinge, .verticalPush, .core, .biceps, .triceps, .calves]
    private static let fullB: [MovementPattern] = [.hinge, .verticalPull, .horizontalPush, .lunge, .shoulderIso, .core, .triceps, .biceps, .glute]
    private static let fullC: [MovementPattern] = [.lunge, .verticalPush, .horizontalPull, .glute, .chestIso, .hamIso, .core, .biceps, .rearDelt]
    private static let upperA: [MovementPattern] = [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .chestIso, .shoulderIso, .biceps, .triceps, .rearDelt]
    private static let upperB: [MovementPattern] = [.verticalPull, .horizontalPush, .horizontalPull, .verticalPush, .rearDelt, .shoulderIso, .triceps, .biceps, .chestIso]
    private static let lowerA: [MovementPattern] = [.squat, .hinge, .lunge, .quadIso, .hamIso, .glute, .calves, .core]
    private static let lowerB: [MovementPattern] = [.hinge, .squat, .glute, .hamIso, .lunge, .quadIso, .core, .calves]
    private static let pushSlots: [MovementPattern] = [.horizontalPush, .verticalPush, .horizontalPush, .chestIso, .shoulderIso, .triceps, .triceps]
    private static let pullSlots: [MovementPattern] = [.verticalPull, .horizontalPull, .horizontalPull, .rearDelt, .biceps, .biceps, .core]

    static func splitName(days: Int, level: ExperienceLevel) -> String {
        switch days {
        case ...2: return "Ganzkörper"
        case 3: return level == .beginner ? "Ganzkörper A/B/C" : "Drücken/Ziehen/Beine"
        case 4: return "Oberkörper/Unterkörper"
        case 5: return "Drücken/Ziehen/Beine + Ober/Unter"
        default: return "Drücken/Ziehen/Beine ×2"
        }
    }

    static func templates(days: Int, level: ExperienceLevel) -> [DayTemplate] {
        switch days {
        case ...1:
            return [DayTemplate(name: "Ganzkörper", kind: .full, slots: fullA, variant: 0)]
        case 2:
            return [DayTemplate(name: "Ganzkörper A", kind: .full, slots: fullA, variant: 0),
                    DayTemplate(name: "Ganzkörper B", kind: .full, slots: fullB, variant: 0)]
        case 3 where level == .beginner:
            return [DayTemplate(name: "Ganzkörper A", kind: .full, slots: fullA, variant: 0),
                    DayTemplate(name: "Ganzkörper B", kind: .full, slots: fullB, variant: 0),
                    DayTemplate(name: "Ganzkörper C", kind: .full, slots: fullC, variant: 1)]
        case 3:
            return [DayTemplate(name: "Push", kind: .push, slots: pushSlots, variant: 0),
                    DayTemplate(name: "Pull", kind: .pull, slots: pullSlots, variant: 0),
                    DayTemplate(name: "Beine", kind: .legs, slots: lowerA, variant: 0)]
        case 4:
            return [DayTemplate(name: "Oberkörper A", kind: .upper, slots: upperA, variant: 0),
                    DayTemplate(name: "Unterkörper A", kind: .lower, slots: lowerA, variant: 0),
                    DayTemplate(name: "Oberkörper B", kind: .upper, slots: upperB, variant: 1),
                    DayTemplate(name: "Unterkörper B", kind: .lower, slots: lowerB, variant: 1)]
        case 5:
            return [DayTemplate(name: "Push", kind: .push, slots: pushSlots, variant: 0),
                    DayTemplate(name: "Pull", kind: .pull, slots: pullSlots, variant: 0),
                    DayTemplate(name: "Beine", kind: .legs, slots: lowerA, variant: 0),
                    DayTemplate(name: "Oberkörper", kind: .upper, slots: upperB, variant: 1),
                    DayTemplate(name: "Unterkörper", kind: .lower, slots: lowerB, variant: 1)]
        default:
            return [DayTemplate(name: "Push A", kind: .push, slots: pushSlots, variant: 0),
                    DayTemplate(name: "Pull A", kind: .pull, slots: pullSlots, variant: 0),
                    DayTemplate(name: "Beine A", kind: .legs, slots: lowerA, variant: 0),
                    DayTemplate(name: "Push B", kind: .push, slots: pushSlots, variant: 1),
                    DayTemplate(name: "Pull B", kind: .pull, slots: pullSlots, variant: 1),
                    DayTemplate(name: "Beine B", kind: .legs, slots: lowerB, variant: 1)]
        }
    }

    // MARK: Plan erstellen

    static func make(_ settings: PlanSettings) -> TrainingPlan {
        let weekdays = settings.weekdays.sorted()
        let temps = templates(days: min(weekdays.count, 6), level: settings.level)
        var days: [PlanDay] = []

        for (index, template) in temps.enumerated() {
            let emphasized = settings.focus.patterns.filter { template.kind.allowed.contains($0) }
            var slots = template.slots
            for pattern in emphasized.reversed() {
                slots.insert(pattern, at: min(3, slots.count))
            }

            var used = Set<String>()
            var items: [PlanExercise] = []
            var minutes = warmupMinutes
            var totalSets = 0
            let maxSets = maxSetsPerSession(settings.level)

            for pattern in slots {
                if items.count >= 9 { break }
                let options = candidates(pattern, settings).filter { !used.contains($0.id) }
                guard !options.isEmpty else { continue }
                let exercise = options[template.variant % options.count]
                let s = scheme(goal: settings.goal, level: settings.level, exercise: exercise,
                               emphasized: emphasized.contains(pattern))
                let cost = Double(s.sets) * (workSeconds + Double(s.rest)) / 60
                if items.count >= 3 && minutes + cost > Double(settings.minutes) { continue }
                if items.count >= 3 && totalSets + s.sets > maxSets { continue }
                minutes += cost
                totalSets += s.sets
                used.insert(exercise.id)
                items.append(PlanExercise(exerciseID: exercise.id, sets: s.sets, repLow: s.low, repHigh: s.high, rest: s.rest))
            }

            days.append(PlanDay(name: template.name,
                                kind: template.kind.title,
                                weekday: index < weekdays.count ? weekdays[index] : nil,
                                exercises: items))
        }

        let split = splitName(days: weekdays.count, level: settings.level)
        return TrainingPlan(created: Calendar.current.startOfDay(for: .now),
                            title: settings.goal.title,
                            split: split,
                            settings: settings,
                            days: days)
    }

    /// Passende Übungen für ein Bewegungsmuster – gefiltert nach Ausrüstung, Erfahrung und Einschränkungen.
    static func candidates(_ pattern: MovementPattern, _ settings: PlanSettings) -> [Exercise] {
        let gear = settings.equipment.gear
        let indexed = ExerciseLibrary.all.enumerated().filter {
            $0.element.pattern == pattern
                && gear.contains($0.element.gear)
                && $0.element.level <= settings.level.rawValue
                && $0.element.avoid.isDisjoint(with: settings.limitations)
        }
        let sorted = indexed.sorted { a, b in
            let ra = rank(a.element, settings.level)
            let rb = rank(b.element, settings.level)
            if ra != rb { return ra < rb }
            return a.offset < b.offset
        }
        return sorted.map { $0.element }
    }

    /// Alternativen zum Tauschen: gleiches Muster, passende Ausrüstung zuerst.
    static func alternatives(for exerciseID: String, settings: PlanSettings?) -> [Exercise] {
        guard let current = ExerciseLibrary.exercise(exerciseID) else { return [] }
        let gear = settings?.equipment.gear ?? Set(Gear.allCases)
        let limits = settings?.limitations ?? []
        let same = ExerciseLibrary.all.filter { $0.pattern == current.pattern && $0.id != current.id }
        let fitting = same.filter { gear.contains($0.gear) && $0.avoid.isDisjoint(with: limits) }
        let rest = same.filter { !fitting.contains($0) }
        return fitting + rest
    }

    /// Obergrenze an Arbeitssätzen pro Einheit, damit die Erholung passt.
    private static func maxSetsPerSession(_ level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 20
        case .intermediate: return 24
        case .advanced: return 28
        }
    }

    private static func rank(_ e: Exercise, _ level: ExperienceLevel) -> Int {
        guard level == .beginner else { return 0 }
        switch e.gear {
        case .machine: return 0
        case .cable, .dumbbell: return 1
        case .bodyweight, .bar: return 2
        case .barbell: return 3
        }
    }

    // MARK: Sätze, Wiederholungen, Pausen

    static func scheme(goal: TrainingGoal, level: ExperienceLevel, exercise e: Exercise, emphasized: Bool) -> Scheme {
        var s: Scheme
        if e.timed {
            s = goal == .fitness ? Scheme(sets: 3, low: 40, high: 60, rest: 45) : Scheme(sets: 3, low: 30, high: 45, rest: 60)
        } else {
            switch (goal, e.compound) {
            case (.strength, true): s = Scheme(sets: 4, low: 4, high: 6, rest: 180)
            case (.strength, false): s = Scheme(sets: 3, low: 8, high: 10, rest: 90)
            case (.muscle, true): s = Scheme(sets: 4, low: 6, high: 10, rest: 120)
            case (.muscle, false): s = Scheme(sets: 3, low: 10, high: 15, rest: 75)
            case (.fatLoss, true): s = Scheme(sets: 3, low: 10, high: 12, rest: 75)
            case (.fatLoss, false): s = Scheme(sets: 3, low: 12, high: 15, rest: 45)
            case (.fitness, true): s = Scheme(sets: 3, low: 12, high: 15, rest: 60)
            case (.fitness, false): s = Scheme(sets: 2, low: 15, high: 20, rest: 45)
            }
            if e.gear == .bodyweight {
                s.low = max(s.low, 8)
                s.high = max(s.high, 15)
            }
        }

        switch level {
        case .beginner:
            s.sets = min(s.sets, 3)
            if goal == .strength && e.compound && !e.timed {
                s.low = 5
                s.high = 8
            }
        case .advanced:
            if e.compound && goal != .fitness { s.sets += 1 }
        case .intermediate:
            break
        }

        if emphasized { s.sets = min(s.sets + 1, 5) }
        return s
    }

    static func minutes(of day: PlanDay) -> Int {
        let work = day.exercises.reduce(0.0) { total, e in
            total + Double(e.sets) * (workSeconds + Double(e.rest)) / 60
        }
        return Int((warmupMinutes + work).rounded())
    }
}
