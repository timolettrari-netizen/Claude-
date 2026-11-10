import Foundation

/// Pläne: Ziel + Dauer starten, Fortschritt verfolgen, jederzeit beenden.
extension Store {
    struct ProgramInfo {
        let goal: Goal
        let start: Date
        let weeks: Int          // 0 = offen
        let week: Int
        let units: Int
        let adherence: Int
        var finished: Bool { weeks > 0 && week > weeks }
        var progress: Double { weeks > 0 ? min(1, Double(min(week, weeks)) / Double(weeks)) : Double(adherence) / 100 }
        var weekText: String { weeks > 0 ? "Woche \(min(week, weeks)) von \(weeks)" : "Woche \(week) (offen)" }
    }

    var program: ProgramInfo? {
        guard let g = goal, let start = s.programStart else { return nil }
        let week = DateUtil.days(from: DateUtil.weekStart(start), to: DateUtil.weekStart(Date())) / 7 + 1
        let units = s.logs.filter { $0.date >= start }.count
        let soFar = max(1, s.programWeeks > 0 ? min(week, s.programWeeks) : week)
        let adh = min(100, Int(Double(units) / Double(max(1, s.days * soFar)) * 100))
        return ProgramInfo(goal: g, start: start, weeks: s.programWeeks, week: week, units: units, adherence: adh)
    }

    func startProgram(goal: String, weeks: Int) {
        if let p = program, p.goal.id == goal {
            s.programWeeks = weeks          // nur Dauer ändern
            return
        }
        if program != nil { _ = endProgram(completed: false) }
        s.goal = goal
        s.programStart = Date()
        s.programWeeks = weeks
        s.blockStart = DateUtil.weekStart(Date())
        Reminders.reschedule(self)
    }

    /// Beendet den aktiven Plan und legt ihn im Verlauf ab.
    @discardableResult
    func endProgram(completed: Bool) -> ProgramRecord? {
        guard let p = program else { return nil }
        let tests = s.tests.filter { $0.test == p.goal.test && $0.date >= p.start.addingTimeInterval(-7 * 86400) }.sorted { $0.date < $1.date }
        let rec = ProgramRecord(goal: p.goal.id, start: p.start, end: Date(), weeks: p.weeks, units: p.units,
                                adherence: p.adherence, completed: completed,
                                testFrom: tests.count > 1 ? tests.first?.value : nil, testTo: tests.count > 1 ? tests.last?.value : nil)
        s.programs.append(rec)
        s.goal = nil
        s.programStart = nil
        Reminders.reschedule(self)
        return rec
    }

    // MARK: Laufplan starten / beenden

    var runPlanActive: Bool { s.runsPerWeek > 0 }

    func startRunPlan() {
        s.runsPerWeek = max(1, s.savedRunsPerWeek)
        s.runPlanStart = DateUtil.weekStart(Date())
    }

    func endRunPlan() {
        if s.runsPerWeek > 0 { s.savedRunsPerWeek = s.runsPerWeek }
        s.runsPerWeek = 0
    }
}
