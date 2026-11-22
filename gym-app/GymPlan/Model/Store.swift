import Foundation
import Observation

/// Zentrale Daten der App: Plan, Trainingsprotokoll, laufendes Training, Körpergewicht.
/// Alles wird als JSON lokal auf dem iPhone gespeichert.
@Observable
final class Store {
    var plan: TrainingPlan? = nil
    var logs: [WorkoutLog] = []          // neueste zuerst
    var active: ActiveWorkout? = nil
    var bodyWeights: [BodyEntry] = []    // älteste zuerst
    var restAlerts = true
    var profile = BodyProfile()
    var mealPicks: [String: String] = [:]
    var eaten: Set<String> = []
    var foodLog: [FoodEntry] = []

    // Nur für die Oberfläche, wird nicht gespeichert
    var showWorkout = false
    var showGenerator = false

    init() {
        load()
    }

    // MARK: - Speichern

    private struct Snapshot: Codable {
        var plan: TrainingPlan?
        var logs: [WorkoutLog]
        var active: ActiveWorkout?
        var bodyWeights: [BodyEntry]
        var restAlerts: Bool?
        var profile: BodyProfile?
        var mealPicks: [String: String]?
        var eaten: Set<String>?
        var foodLog: [FoodEntry]?
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "gymplan.json")
    }

    private var snapshot: Snapshot {
        Snapshot(plan: plan, logs: logs, active: active, bodyWeights: bodyWeights, restAlerts: restAlerts,
                 profile: profile, mealPicks: mealPicks, eaten: eaten, foodLog: foodLog)
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Speichern fehlgeschlagen: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        apply(snap)
    }

    private func apply(_ snap: Snapshot) {
        plan = snap.plan
        logs = snap.logs.sorted { $0.date > $1.date }
        active = snap.active
        bodyWeights = snap.bodyWeights.sorted { $0.date < $1.date }
        restAlerts = snap.restAlerts ?? true
        profile = snap.profile ?? BodyProfile()
        foodLog = snap.foodLog ?? []
        // Abhaken und Tausch nur für die letzten 60 Tage aufbewahren
        let cutoff = Self.dayKey(Self.calendar.date(byAdding: .day, value: -60, to: .now) ?? .now)
        mealPicks = (snap.mealPicks ?? [:]).filter { $0.key >= cutoff }
        eaten = (snap.eaten ?? []).filter { $0 >= cutoff }
    }

    func exportBackup() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return nil }
        let name = "GymPlan-Backup-\(Date.now.formatted(.iso8601.year().month().day())).json"
        let url = URL.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snap = try decoder.decode(Snapshot.self, from: data)
        apply(snap)
        save()
    }

    func resetAll() {
        plan = nil
        logs = []
        active = nil
        bodyWeights = []
        profile = BodyProfile()
        mealPicks = [:]
        eaten = []
        foodLog = []
        RestNotifier.shared.cancel()
        save()
    }

    // MARK: - Kalender

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        cal.locale = Locale(identifier: "de_DE")
        return cal
    }

    /// 1 = Montag … 7 = Sonntag
    static func weekdayIndex(_ date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date)
        return (wd + 5) % 7 + 1
    }

    static func startOfWeek(_ date: Date = .now) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func trained(on date: Date) -> Bool {
        logs.contains { Self.calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Plan

    func createPlan(_ settings: PlanSettings) {
        plan = PlanGenerator.make(settings)
        save()
    }

    var currentWeek: Int {
        guard let plan else { return 1 }
        let days = Self.calendar.dateComponents([.day], from: plan.created, to: Self.calendar.startOfDay(for: .now)).day ?? 0
        return max(1, days / 7 + 1)
    }

    var isDeloadWeek: Bool {
        plan != nil && currentWeek % 4 == 0
    }

    var planFinished: Bool {
        guard let plan, plan.settings.weeks > 0 else { return false }
        return currentWeek > plan.settings.weeks
    }

    func nextSession(from date: Date = .now) -> (day: PlanDay, date: Date)? {
        guard let plan, !plan.days.isEmpty else { return nil }
        let cal = Self.calendar
        let today = cal.startOfDay(for: date)
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let wd = Self.weekdayIndex(day)
            if let planDay = plan.days.first(where: { $0.weekday == wd }) {
                if offset == 0 && trained(on: day) { continue }
                return (planDay, day)
            }
        }
        // Keine Wochentage hinterlegt: einfach rotieren
        let index = logs.count % plan.days.count
        return (plan.days[index], today)
    }

    func planDay(_ id: UUID) -> PlanDay? {
        plan?.days.first { $0.id == id }
    }

    private func updateDay(_ dayID: UUID, _ change: (inout PlanDay) -> Void) {
        guard var p = plan, let i = p.days.firstIndex(where: { $0.id == dayID }) else { return }
        change(&p.days[i])
        plan = p
        save()
    }

    func swapExercise(dayID: UUID, itemID: UUID, to exerciseID: String) {
        updateDay(dayID) { day in
            if let i = day.exercises.firstIndex(where: { $0.id == itemID }) {
                day.exercises[i].exerciseID = exerciseID
            }
        }
    }

    func removeExercise(dayID: UUID, itemID: UUID) {
        updateDay(dayID) { day in
            day.exercises.removeAll { $0.id == itemID }
        }
    }

    func changeSets(dayID: UUID, itemID: UUID, by delta: Int) {
        updateDay(dayID) { day in
            if let i = day.exercises.firstIndex(where: { $0.id == itemID }) {
                day.exercises[i].sets = min(8, max(1, day.exercises[i].sets + delta))
            }
        }
    }

    func moveExercise(dayID: UUID, itemID: UUID, up: Bool) {
        updateDay(dayID) { day in
            guard let i = day.exercises.firstIndex(where: { $0.id == itemID }) else { return }
            let j = up ? i - 1 : i + 1
            guard day.exercises.indices.contains(j) else { return }
            day.exercises.swapAt(i, j)
        }
    }

    func addExercise(dayID: UUID, exerciseID: String) {
        guard let e = ExerciseLibrary.exercise(exerciseID) else { return }
        let s = defaultScheme(for: e)
        updateDay(dayID) { day in
            day.exercises.append(PlanExercise(exerciseID: exerciseID, sets: s.sets, repLow: s.low, repHigh: s.high, rest: s.rest))
        }
    }

    private func defaultScheme(for e: Exercise) -> PlanGenerator.Scheme {
        PlanGenerator.scheme(goal: plan?.settings.goal ?? .muscle,
                             level: plan?.settings.level ?? .intermediate,
                             exercise: e, emphasized: false)
    }

    // MARK: - Progression

    struct Suggestion {
        var weight: Double?
        var reps: Int
        var note: String?
    }

    func lastLog(for exerciseID: String) -> ExerciseLog? {
        for log in logs {
            if let e = log.exercises.first(where: { $0.exerciseID == exerciseID }), !e.sets.isEmpty {
                return e
            }
        }
        return nil
    }

    /// Doppelte Progression: erst Wiederholungen steigern, dann Gewicht erhöhen.
    func suggestion(exerciseID: String, low: Int, high: Int) -> Suggestion {
        guard let last = lastLog(for: exerciseID) else {
            return Suggestion(weight: nil, reps: low, note: nil)
        }
        let info = ExerciseLibrary.exercise(exerciseID)
        let top = last.sets.map(\.weight).max() ?? 0
        let topSets = last.sets.filter { $0.weight == top }
        let minReps = topSets.map(\.reps).min() ?? low

        if top <= 0 {
            let step = (info?.timed ?? false) ? 5 : 1
            let target = minReps + step
            return Suggestion(weight: nil, reps: target,
                              note: "Ziel: \(target) \(info?.repUnit ?? "Wdh.") – eine Steigerung zum letzten Mal")
        }

        if topSets.allSatisfy({ $0.reps >= high }) {
            let inc = info?.increment ?? 2.5
            let next = top + inc
            return Suggestion(weight: next, reps: low,
                              note: "↑ +\(Fmt.kg(inc)) kg – letztes Mal alle Wiederholungen geschafft")
        }

        let reps = min(max(minReps + 1, low), high)
        return Suggestion(weight: top, reps: reps, note: "Gleiches Gewicht, Ziel \(reps) Wdh.")
    }

    func lastText(for exerciseID: String) -> String? {
        guard let last = lastLog(for: exerciseID) else { return nil }
        let timed = ExerciseLibrary.exercise(exerciseID)?.timed ?? false
        let weights = Set(last.sets.map(\.weight))
        if timed {
            return "Letztes Mal: " + last.sets.map { "\($0.reps) s" }.joined(separator: " · ")
        }
        if weights.count == 1, let w = weights.first {
            let reps = last.sets.map { "\($0.reps)" }.joined(separator: " · ")
            return w > 0 ? "Letztes Mal: \(Fmt.kg(w)) kg × \(reps)" : "Letztes Mal: \(reps) Wdh."
        }
        return "Letztes Mal: " + last.sets.map { "\(Fmt.kg($0.weight))×\($0.reps)" }.joined(separator: " · ")
    }

    // MARK: - Training

    func startWorkout(_ day: PlanDay) {
        guard active == nil else {
            showWorkout = true
            return
        }
        let deload = isDeloadWeek
        let items = day.exercises.map { item -> ActiveExercise in
            let sug = suggestion(exerciseID: item.exerciseID, low: item.repLow, high: item.repHigh)
            let count = deload ? max(2, item.sets - 1) : item.sets
            let hintW = sug.weight.map { Fmt.kg($0) } ?? ""
            let sets = (0..<count).map { _ in ActiveSet(hintWeight: hintW, hintReps: "\(sug.reps)") }
            let note = deload ? "Entlastungswoche: ein Satz weniger, Technik im Fokus" : sug.note
            return ActiveExercise(exerciseID: item.exerciseID, repLow: item.repLow, repHigh: item.repHigh,
                                  rest: item.rest, sets: sets, note: note)
        }
        active = ActiveWorkout(start: .now, dayName: day.name, planDayID: day.id, exercises: items)
        showWorkout = true
        save()
        if restAlerts { RestNotifier.shared.requestAuthorization() }
    }

    func startEmptyWorkout() {
        guard active == nil else {
            showWorkout = true
            return
        }
        active = ActiveWorkout(start: .now, dayName: "Freies Training", planDayID: nil, exercises: [])
        showWorkout = true
        save()
        if restAlerts { RestNotifier.shared.requestAuthorization() }
    }

    func addExerciseToActive(_ exerciseID: String) {
        guard var w = active, let e = ExerciseLibrary.exercise(exerciseID) else { return }
        let s = defaultScheme(for: e)
        let sug = suggestion(exerciseID: exerciseID, low: s.low, high: s.high)
        let hintW = sug.weight.map { Fmt.kg($0) } ?? ""
        let sets = (0..<s.sets).map { _ in ActiveSet(hintWeight: hintW, hintReps: "\(sug.reps)") }
        w.exercises.append(ActiveExercise(exerciseID: exerciseID, repLow: s.low, repHigh: s.high,
                                          rest: s.rest, sets: sets, note: sug.note))
        active = w
    }

    func removeFromActive(_ itemID: UUID) {
        active?.exercises.removeAll { $0.id == itemID }
    }

    func toggleSet(exercise itemID: UUID, set setID: UUID) {
        guard var w = active,
              let ei = w.exercises.firstIndex(where: { $0.id == itemID }),
              let si = w.exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        var s = w.exercises[ei].sets[si]
        if s.done {
            s.done = false
        } else {
            if s.weight.trimmingCharacters(in: .whitespaces).isEmpty { s.weight = s.hintWeight }
            if s.reps.trimmingCharacters(in: .whitespaces).isEmpty { s.reps = s.hintReps }
            s.done = true
            let rest = w.exercises[ei].rest
            let now = Date.now
            w.restStart = now
            w.restEnd = now.addingTimeInterval(TimeInterval(rest))
            if restAlerts {
                RestNotifier.shared.schedule(seconds: rest, next: ExerciseLibrary.name(w.exercises[ei].exerciseID))
            }
        }
        w.exercises[ei].sets[si] = s
        active = w
    }

    func adjustRest(by seconds: Int) {
        guard var w = active, let start = w.restStart, let end = w.restEnd else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= Date.now.addingTimeInterval(1) {
            skipRest()
            return
        }
        w.restEnd = max(newEnd, start.addingTimeInterval(1))
        active = w
        if restAlerts {
            RestNotifier.shared.schedule(seconds: Int(newEnd.timeIntervalSinceNow.rounded()), next: nil)
        }
    }

    func skipRest() {
        active?.restStart = nil
        active?.restEnd = nil
        RestNotifier.shared.cancel()
    }

    /// Speichert das Training. Gibt nil zurück, wenn kein Satz eingetragen wurde.
    func finishWorkout() -> WorkoutLog? {
        guard let w = active else { return nil }
        var entries: [ExerciseLog] = []
        for ex in w.exercises {
            let sets: [SetLog] = ex.sets.compactMap { s in
                let typedReps = s.reps.trimmingCharacters(in: .whitespaces)
                guard s.done || !typedReps.isEmpty else { return nil }
                let repsText = typedReps.isEmpty ? s.hintReps : typedReps
                guard let reps = Int(repsText), reps > 0 else { return nil }
                let weightText = s.weight.trimmingCharacters(in: .whitespaces).isEmpty ? s.hintWeight : s.weight
                return SetLog(weight: max(0, Fmt.parse(weightText) ?? 0), reps: reps)
            }
            if !sets.isEmpty { entries.append(ExerciseLog(exerciseID: ex.exerciseID, sets: sets)) }
        }

        RestNotifier.shared.cancel()
        active = nil
        guard !entries.isEmpty else {
            save()
            return nil
        }

        var prs: [String] = []
        for e in entries {
            let before = best(for: e.exerciseID)
            let now = e.sets.map(Self.score).max() ?? 0
            if before > 0 && now > before { prs.append(e.exerciseID) }
        }

        let log = WorkoutLog(date: w.start, duration: Date.now.timeIntervalSince(w.start),
                             dayName: w.dayName, exercises: entries, prs: prs)
        logs.insert(log, at: 0)
        save()
        return log
    }

    func discardWorkout() {
        RestNotifier.shared.cancel()
        active = nil
        save()
    }

    func deleteLog(_ id: UUID) {
        logs.removeAll { $0.id == id }
        save()
    }

    // MARK: - Auswertung

    /// Geschätztes 1RM nach Epley, bei Körpergewicht die Wiederholungen.
    static func e1rm(_ s: SetLog) -> Double {
        s.weight * (1 + Double(s.reps) / 30)
    }

    static func score(_ s: SetLog) -> Double {
        s.weight > 0 ? e1rm(s) : Double(s.reps)
    }

    func best(for exerciseID: String) -> Double {
        var result = 0.0
        for log in logs {
            for e in log.exercises where e.exerciseID == exerciseID {
                for s in e.sets { result = max(result, Self.score(s)) }
            }
        }
        return result
    }

    struct HistoryPoint: Identifiable {
        var id: UUID
        var date: Date
        var e1rm: Double
        var maxWeight: Double
        var maxReps: Int
        var volume: Double
        var sets: [SetLog]
    }

    func history(for exerciseID: String) -> [HistoryPoint] {
        logs.reversed().compactMap { log in
            guard let e = log.exercises.first(where: { $0.exerciseID == exerciseID }), !e.sets.isEmpty else { return nil }
            return HistoryPoint(id: log.id, date: log.date,
                                e1rm: e.sets.map(Self.e1rm).max() ?? 0,
                                maxWeight: e.sets.map(\.weight).max() ?? 0,
                                maxReps: e.sets.map(\.reps).max() ?? 0,
                                volume: e.volume,
                                sets: e.sets)
        }
    }

    /// Übungen mit Einträgen, zuletzt trainierte zuerst.
    var trackedExercises: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for log in logs {
            for e in log.exercises where !seen.contains(e.exerciseID) {
                seen.insert(e.exerciseID)
                result.append(e.exerciseID)
            }
        }
        return result
    }

    struct WeekStat: Identifiable {
        var id: Date { start }
        var start: Date
        var volume: Double
        var count: Int
    }

    func weeklyStats(weeks: Int = 8) -> [WeekStat] {
        let cal = Self.calendar
        let thisWeek = Self.startOfWeek()
        return (0..<weeks).reversed().compactMap { back in
            guard let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = logs.filter { $0.date >= start && $0.date < end }
            return WeekStat(start: start, volume: inWeek.reduce(0.0) { $0 + $1.volume }, count: inWeek.count)
        }
    }

    var workoutsThisWeek: Int {
        let start = Self.startOfWeek()
        return logs.filter { $0.date >= start }.count
    }

    var volumeThisWeek: Double {
        let start = Self.startOfWeek()
        return logs.filter { $0.date >= start }.reduce(0.0) { $0 + $1.volume }
    }

    /// Wochen in Folge mit mindestens einem Training.
    var weekStreak: Int {
        let cal = Self.calendar
        var start = Self.startOfWeek()
        if !logs.contains(where: { $0.date >= start }) {
            guard let previous = cal.date(byAdding: .weekOfYear, value: -1, to: start) else { return 0 }
            start = previous
        }
        var count = 0
        while count < 520 {
            guard let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            if logs.contains(where: { $0.date >= start && $0.date < end }) {
                count += 1
                guard let previous = cal.date(byAdding: .weekOfYear, value: -1, to: start) else { break }
                start = previous
            } else {
                break
            }
        }
        return count
    }

    var totalPRs: Int { logs.reduce(0) { $0 + $1.prs.count } }

    // MARK: - Körpergewicht

    func addBodyWeight(_ kg: Double, date: Date) {
        bodyWeights.removeAll { Self.calendar.isDate($0.date, inSameDayAs: date) }
        bodyWeights.append(BodyEntry(date: date, kg: (kg * 10).rounded() / 10))
        bodyWeights.sort { $0.date < $1.date }
        save()
    }

    func saveProfile(_ newProfile: BodyProfile) {
        var p = newProfile
        p.configured = true
        profile = p
        save()
    }

    func deleteBodyWeight(_ id: UUID) {
        bodyWeights.removeAll { $0.id == id }
        save()
    }
}
