import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State private var showTest = false
    @State private var showReviews = false
    @State private var detail: Sel?

    private struct WeekBar: Identifiable { let id: Int; let label: String; let count: Int; let current: Bool }

    private var weeks: [WeekBar] {
        let ws = DateUtil.weekStart(Date())
        return (0..<8).map { k in
            let a = DateUtil.calendar.date(byAdding: .day, value: -7 * (7 - k), to: ws)!
            let b = DateUtil.calendar.date(byAdding: .day, value: 7, to: a)!
            return WeekBar(id: k, label: DateUtil.format(a, "dM"), count: store.s.logs.filter { $0.date >= a && $0.date < b }.count, current: k == 7)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Statistik").font(.sport(40)).textCase(.uppercase)
                        Spacer()
                        Button { showReviews = true } label: { Label("Rückblicke", systemImage: "doc.text.magnifyingglass") }
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.top, 8)
                    rings
                    Text("Überblick").sectionTitle()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        kpi("Einheiten", "\(store.s.logs.count)", "")
                        kpi("Trainingszeit", String(format: "%.1f", totalHours), "h")
                        kpi("Gelaufen", String(format: "%.1f", totalRunKm), "km")
                        kpi("Läufe", "\(store.runOnly.count)", "")
                        kpi("Bewegtes Gewicht", String(format: "%.1f", totalTonnes), "t")
                        let rp = store.s.logs.compactMap(\.rpe)
                        kpi("Ø Anstrengung", rp.isEmpty ? "–" : String(format: "%.1f", Double(rp.reduce(0, +)) / Double(rp.count)), "/10")
                    }
                    Text("Einheiten pro Woche").sectionTitle()
                    Chart {
                        ForEach(weeks) { w in
                            BarMark(x: .value("Woche", w.label), y: .value("Einheiten", w.count))
                                .foregroundStyle(w.current ? Color.lime : Color.white.opacity(0.3))
                                .cornerRadius(6)
                                .annotation(position: .top) { if w.count > 0 { Text("\(w.count)").font(.caption2.bold()) } }
                        }
                        RuleMark(y: .value("Ziel", store.weeklyGoal))
                            .foregroundStyle(Color.pink).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 180)
                    .card()
                    if store.s.healthEnabled && !store.stepsWeek.isEmpty {
                        Text("Schritte (7 Tage)").sectionTitle()
                        stepsChart
                    }
                    HStack {
                        Text("Leistungstests").sectionTitle()
                        Button { showTest = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    }
                    testsList
                    Text("Bestleistungen").sectionTitle()
                    prList
                    Text("Verlauf").sectionTitle()
                    history
                    if !store.s.runs.isEmpty {
                        Text("Läufe & Aktivitäten").sectionTitle()
                        runHistory
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showReviews) { WeeklyReviewView(weekStart: store.reviewWeekStart).environmentObject(store) }
            .sheet(isPresented: $showTest) { AddTestView().environmentObject(store).presentationDetents([.medium, .large]) }
            .sheet(item: $detail) { s in ExerciseDetailView(id: s.id).environmentObject(store) }
        }
    }

    private var totalHours: Double {
        let workoutMin: Int = store.s.logs.reduce(0) { $0 + $1.minutes }
        let runMin: Int = store.s.runs.reduce(0) { $0 + $1.minutes }
        return Double(workoutMin + runMin) / 60
    }
    private var totalRunKm: Double { store.runOnly.reduce(0.0) { $0 + $1.km } }
    private var totalTonnes: Double { store.s.logs.reduce(0.0) { $0 + $1.volume } / 1000 }

    private func runLine(_ r: RunLog) -> String {
        var t: String = DateUtil.format(r.date, "EEEdMMM") + " · " + String(format: "%.2f", r.km) + " km · \(r.minutes) min"
        if FreeActivity.from(logType: r.type).usesGPS, let p = r.paceMinPerKm { t += " · " + Store.pace(p) + " /km" }
        if let hr = r.avgHR { t += " · ♥ \(hr)" }
        return t
    }

    private func logLine(_ l: WorkoutLog) -> String {
        var t: String = DateUtil.format(l.date, "EEEdMMM") + " · \(l.minutes) min"
        if l.healthID == nil { t += " · \(l.sets.count) Übungen" }
        if let k = l.kcal { t += " · \(k) kcal" }
        if let hr = l.avgHR { t += " · ♥ \(hr)" }
        if let r = l.rpe { t += " · RPE \(r)" }
        return t
    }

    private var rings: some View {
        let week = store.logsThisWeek.count, goal = store.weeklyGoal
        let mins = store.logsThisWeek.reduce(0) { $0 + $1.minutes }, mgoal = goal * 40
        let steps = Int(store.steps), sgoal = max(1, store.s.body.stepGoal)
        return HStack(spacing: 20) {
            ZStack {
                ring(Double(week) / Double(max(goal, 1)), .pink, 120)
                ring(Double(mins) / Double(max(mgoal, 1)), .green, 88)
                ring(Double(steps) / Double(sgoal), .cyan, 56)
            }
            .frame(width: 130, height: 130)
            VStack(alignment: .leading, spacing: 8) {
                legend("EINHEITEN", "\(week)/\(goal)", .pink)
                legend("MINUTEN", "\(mins)/\(mgoal)", .green)
                legend("SCHRITTE HEUTE", store.s.healthEnabled ? "\(fmtInt(steps))/\(fmtInt(sgoal))" : "Health aus", .cyan)
            }
        }
        .card(padding: 18)
    }

    private var stepsChart: some View {
        let goal = store.s.body.stepGoal
        let days = store.stepsWeek
        let avg = days.isEmpty ? 0 : days.reduce(0) { $0 + $1.steps } / days.count
        let reached = days.filter { $0.steps >= goal }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ø \(fmtInt(avg)) pro Tag · Ziel an \(reached) von \(days.count) Tagen erreicht")
                .font(.footnote).foregroundStyle(Color.mut)
            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Tag", DateUtil.weekdaysShort[DateUtil.dayIndex(d.date)]), y: .value("Schritte", d.steps))
                        .foregroundStyle(d.steps >= goal ? Color.cyan : Color.white.opacity(0.3))
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Ziel", goal))
                    .foregroundStyle(Color.cyan.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 160)
        }
        .card()
    }

    private func ring(_ v: Double, _ c: Color, _ size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(c.opacity(0.2), lineWidth: 14)
            Circle().trim(from: 0, to: max(0.001, min(1, v))).stroke(c, style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private func legend(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(.caption.weight(.bold)).foregroundStyle(c)
            Text(v).font(.sport(24))
        }
    }

    private func kpi(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color.mut)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.sport(32))
                Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(Color.mut)
            }
        }
        .card(padding: 14)
    }

    @ViewBuilder private var testsList: some View {
        let used = store.catalog.tests.filter { t in store.s.tests.contains { $0.test == t.id } }
        if used.isEmpty {
            Text("Miss alle 4 Wochen deinen Test – so siehst du, ob du deinem Ziel näherkommst.")
                .font(.subheadline).foregroundStyle(Color.mut).card()
        } else {
            VStack(spacing: 0) {
                ForEach(used) { t in
                    let all = store.s.tests.filter { $0.test == t.id }.sorted { $0.date < $1.date }
                    let diff = all.count > 1 ? all.last!.value - all.first!.value : nil
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name)
                            if let d = diff {
                                let good = t.higherIsBetter ? d > 0 : d < 0
                                Text("\(all.count) Messungen · \(d > 0 ? "+" : "")\(fmtKg((d * 100).rounded() / 100)) \(t.unit)")
                                    .font(.footnote).foregroundStyle(good ? Color.lime : .red)
                            } else {
                                Text("1 Messung").font(.footnote).foregroundStyle(Color.mut)
                            }
                        }
                        Spacer()
                        if all.count > 1 {
                            Chart(all) { e in
                                LineMark(x: .value("Datum", e.date), y: .value("Wert", e.value)).foregroundStyle(Color.lime)
                            }
                            .chartXAxis(.hidden).chartYAxis(.hidden).frame(width: 70, height: 26)
                        }
                        Text("\(fmtKg(all.last?.value ?? 0)) \(t.unit)").font(.headline)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder private var prList: some View {
        let prs = store.catalog.exercises.keys.map { ($0, store.bestKg($0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        if prs.isEmpty {
            Text("Trage im Training Gewichte ein – hier erscheinen deine Bestwerte.").font(.subheadline).foregroundStyle(Color.mut).card()
        } else {
            VStack(spacing: 0) {
                ForEach(prs.map { $0.0 }, id: \.self) { id in
                    let kg = store.bestKg(id)
                    Button { detail = Sel(id: id) } label: {
                        HStack {
                            Text(store.name(id)).foregroundStyle(.white)
                            Spacer()
                            Text("\(fmtKg(kg)) kg").font(.headline).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var runHistory: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.s.runs.suffix(30).reversed())) { r in
                HStack(spacing: 12) {
                    let act = FreeActivity.from(logType: r.type)
                    Text(act.icon).frame(width: 34, height: 34).background(Color(hex: act.colors[0]).opacity(0.25), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                        Text(runLine(r))
                            .font(.footnote).foregroundStyle(Color.mut)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .contextMenu {
                    Button("Löschen", role: .destructive) { store.s.runs.removeAll { $0.id == r.id } }
                }
            }
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var history: some View {
        if store.s.logs.isEmpty {
            Text("Noch keine Einheit – leg los!").font(.subheadline).foregroundStyle(Color.mut).card()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(store.s.logs.suffix(30).reversed())) { l in
                    let se = store.catalog.session(l.session)
                    HStack(spacing: 12) {
                        if l.healthID != nil {
                            Text("🏋️").font(.system(size: 17)).frame(width: 34, height: 34)
                                .background(Color.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 9))
                        } else {
                            SessionIcon(session: se)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.title ?? se?.name ?? l.session)
                            Text(logLine(l))
                                .font(.footnote).foregroundStyle(Color.mut)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .contextMenu {
                        Button("Löschen", role: .destructive) { store.s.logs.removeAll { $0.id == l.id } }
                    }
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct AddTestView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var test = ""
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Test", selection: $test) {
                        ForEach(store.catalog.tests) { t in Text("\(t.name) (\(t.unit))").tag(t.id) }
                    }
                    if let t = store.catalog.test(test) { Text(t.hint).font(.footnote).foregroundStyle(Color.mut) }
                    TextField("Ergebnis", text: $value).keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Leistungstest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let v = Double(value.replacingOccurrences(of: ",", with: ".")), !test.isEmpty {
                            store.s.tests.append(TestEntry(test: test, value: v, date: Date()))
                            Haptics.success()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { if test.isEmpty { test = store.goal?.test ?? store.catalog.tests.first?.id ?? "" } }
        }
    }
}
