import SwiftUI
import Charts

struct ProgressTab: View {
    @Environment(Store.self) private var store
    @State private var showWeightSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        StatTile(value: "\(store.logs.count)", label: "Trainings", icon: "figure.strengthtraining.traditional")
                        StatTile(value: "\(store.weekStreak)", label: "Wochen in Folge", icon: "flame.fill", tint: Theme.accent2)
                        StatTile(value: "\(store.totalPRs)", label: "Bestleistungen", icon: "trophy.fill", tint: .yellow)
                    }

                    if store.logs.isEmpty {
                        ContentUnavailableView {
                            Label("Noch keine Trainings", systemImage: "chart.line.uptrend.xyaxis")
                        } description: {
                            Text("Sobald du dein erstes Training mit Gewicht und Wiederholungen speicherst, siehst du hier deinen Fortschritt.")
                        }
                        .glassCard(radius: 30)
                    } else {
                        WeeklyVolumeCard(stats: store.weeklyStats())
                    }

                    BodyWeightCard(showSheet: $showWeightSheet)

                    if !store.trackedExercises.isEmpty {
                        SectionTitle(text: "Übungen", trailing: "geschätztes 1RM")
                        ForEach(store.trackedExercises, id: \.self) { id in
                            NavigationLink(value: id) {
                                ExerciseProgressRow(exerciseID: id)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !store.logs.isEmpty {
                        SectionTitle(text: "Verlauf")
                        ForEach(store.logs.prefix(30)) { log in
                            NavigationLink(value: log.id) {
                                WorkoutSummaryRow(log: log)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Fortschritt")
            .navigationDestination(for: String.self) { id in
                ExerciseProgressView(exerciseID: id)
            }
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(logID: id)
            }
            .sheet(isPresented: $showWeightSheet) {
                BodyWeightSheet()
            }
        }
    }
}

// MARK: - Wochenvolumen

private struct WeeklyVolumeCard: View {
    let stats: [Store.WeekStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wochenvolumen", systemImage: "chart.bar.fill").font(.headline)
                Spacer()
                Text("Gewicht × Wdh.").font(.caption).foregroundStyle(.secondary)
            }
            Chart(stats) { week in
                BarMark(
                    x: .value("Woche", week.start, unit: .weekOfYear),
                    y: .value("Tonnen", week.volume / 1000)
                )
                .foregroundStyle(Theme.accent.gradient)
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text("\(v.formatted(.number.precision(.fractionLength(0...1)))) t") }
                    }
                }
            }
            .frame(height: 170)
        }
        .glassCard()
    }
}

// MARK: - Körpergewicht

private struct BodyWeightCard: View {
    @Environment(Store.self) private var store
    @Binding var showSheet: Bool
    @State private var showGoal = false

    private struct TargetPoint: Identifiable {
        let date: Date
        let kg: Double
        var id: Date { date }
    }

    var body: some View {
        let p = store.profile
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Körpergewicht", systemImage: "figure").font(.headline)
                Spacer()
                Button {
                    showGoal = true
                } label: {
                    Image(systemName: "target")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Gewichtsziel")
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Gewicht eintragen")
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.kg(store.currentKg)).font(.system(size: 34, weight: .bold, design: .rounded))
                Text("kg").foregroundStyle(.secondary)
                Spacer()
                if p.configured && store.goalDirection != .keep {
                    Text("noch \(Fmt.kg(abs(store.currentKg - p.goalKg))) kg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                } else if p.configured {
                    Badge(text: "Ziel erreicht", icon: "checkmark.seal.fill", tint: .green)
                }
            }

            if p.configured {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: store.goalProgress)
                        .tint(Theme.accent)
                    HStack {
                        Text("Start \(Fmt.kg(p.startKg))")
                        Spacer()
                        Text("Soll heute \(Fmt.kg((store.targetKg(on: .now) * 10).rounded() / 10))")
                        Spacer()
                        Text("Ziel \(Fmt.kg(p.goalKg)) kg")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            if store.bodyWeights.count > 1 {
                Chart {
                    ForEach(store.bodyWeights) { entry in
                        LineMark(x: .value("Datum", entry.date), y: .value("kg", entry.kg), series: .value("Linie", "Gewicht"))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        PointMark(x: .value("Datum", entry.date), y: .value("kg", entry.kg))
                            .foregroundStyle(Color.blue)
                            .symbolSize(30)
                    }
                    if p.configured {
                        ForEach(targetLine) { t in
                            LineMark(x: .value("Datum", t.date), y: .value("kg", t.kg), series: .value("Linie", "Soll"))
                                .foregroundStyle(Theme.accent.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                if p.configured {
                    HStack(spacing: 12) {
                        Label("Gewicht", systemImage: "circle.fill").foregroundStyle(.blue)
                        Label("Soll-Linie zum Ziel", systemImage: "line.diagonal").foregroundStyle(Theme.accent)
                    }
                    .font(.caption2)
                    .labelStyle(.titleAndIcon)
                }
            }

            if p.configured, let trend = store.weightTrend() {
                let word = trend >= 0 ? "abgenommen" : "zugenommen"
                Text("Letzte 4 Wochen: \(abs(trend).formatted(.number.precision(.fractionLength(1)))) kg pro Woche \(word)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if p.configured, let forecast = store.goalForecast {
                Label("Bei diesem Tempo erreichst du dein Ziel ca. am \(forecast.formatted(date: .long, time: .omitted)).",
                      systemImage: "flag.checkered")
                    .font(.caption)
            }

            if !p.configured {
                Button {
                    showGoal = true
                } label: {
                    Label("Gewichtsziel festlegen", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }

            if !store.bodyWeights.isEmpty {
                NavigationLink {
                    BodyWeightListView()
                } label: {
                    Text("Alle Einträge").font(.caption.weight(.semibold))
                }
            } else {
                Text("Trage dein Gewicht regelmäßig ein – am besten morgens nüchtern, 2–3× pro Woche.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard()
        .sheet(isPresented: $showGoal) {
            GoalView()
        }
    }

    /// Soll-Linie im sichtbaren Zeitraum (vom ersten Eintrag bis etwas nach heute)
    private var targetLine: [TargetPoint] {
        guard let first = store.bodyWeights.first?.date else { return [] }
        let start = max(first, store.profile.startDate)
        let end = min(store.profile.goalDate, Date.now.addingTimeInterval(7 * 86400))
        guard end > start else { return [] }
        return [TargetPoint(date: start, kg: store.targetKg(on: start)),
                TargetPoint(date: end, kg: store.targetKg(on: end))]
    }
}

private struct BodyWeightSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date.now
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    TextField(store.bodyWeights.last.map { Fmt.kg($0.kg) } ?? "z. B. 78,5", text: $text)
                        .keyboardType(.decimalPad)
                        .font(.title.bold())
                        .focused($focused)
                    Text("kg").foregroundStyle(.secondary)
                }
                DatePicker("Datum", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("Gewicht eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let kg = Fmt.parse(text), kg > 20, kg < 400 {
                            store.addBodyWeight(kg, date: date)
                            dismiss()
                        }
                    }
                    .disabled(Fmt.parse(text) == nil)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

private struct BodyWeightListView: View {
    @Environment(Store.self) private var store

    var body: some View {
        List {
            ForEach(store.bodyWeights.reversed()) { entry in
                HStack {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text("\(Fmt.kg(entry.kg)) kg").monospacedDigit().fontWeight(.semibold)
                }
                .swipeActions {
                    Button("Löschen", systemImage: "trash", role: .destructive) {
                        store.deleteBodyWeight(entry.id)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Körpergewicht")
    }
}

// MARK: - Übungen

private struct ExerciseProgressRow: View {
    @Environment(Store.self) private var store
    let exerciseID: String

    var body: some View {
        let points = store.history(for: exerciseID)
        let info = ExerciseLibrary.exercise(exerciseID)
        let usesWeight = (points.last?.maxWeight ?? 0) > 0
        let values = points.suffix(10).map { usesWeight ? $0.e1rm : Double($0.maxReps) }
        let trend = (values.last ?? 0) - (values.first ?? 0)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let info { MuscleDot(muscle: info.muscle) }
                    Text(info?.name ?? exerciseID).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Text("\(points.count)× trainiert").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Sparkline(values: values)
                .frame(width: 70, height: 30)
            VStack(alignment: .trailing, spacing: 2) {
                Text(usesWeight ? "\(Fmt.kg((values.last ?? 0).rounded())) kg" : "\(Int(values.last ?? 0)) Wdh.")
                    .font(.subheadline.bold().monospacedDigit())
                if values.count > 1 {
                    Text("\(trend >= 0 ? "▲" : "▼") \(Fmt.kg(abs(trend).rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(trend >= 0 ? Color.green : Color.red)
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .glassCard(padding: 14, radius: 22, interactive: true)
    }
}

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            LineMark(x: .value("i", item.offset), y: .value("v", item.element))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
    }
}

enum ProgressMetric: String, CaseIterable, Identifiable {
    case e1rm, weight, volume, reps
    var id: String { rawValue }

    var title: String {
        switch self {
        case .e1rm: return "1RM"
        case .weight: return "Gewicht"
        case .volume: return "Volumen"
        case .reps: return "Wdh."
        }
    }

    func value(_ p: Store.HistoryPoint) -> Double {
        switch self {
        case .e1rm: return p.e1rm
        case .weight: return p.maxWeight
        case .volume: return p.volume
        case .reps: return Double(p.maxReps)
        }
    }
}

struct ExerciseProgressView: View {
    @Environment(Store.self) private var store
    let exerciseID: String
    @State private var metric: ProgressMetric = .e1rm

    var body: some View {
        let points = store.history(for: exerciseID)
        let usesWeight = points.contains { $0.maxWeight > 0 }
        let metrics: [ProgressMetric] = usesWeight ? [.e1rm, .weight, .volume, .reps] : [.reps]
        let active = metrics.contains(metric) ? metric : metrics[0]

        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Wert", selection: $metric) {
                        ForEach(metrics) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if points.isEmpty {
                        Text("Noch keine Einträge.").foregroundStyle(.secondary)
                    } else {
                        Chart(points) { p in
                            LineMark(x: .value("Datum", p.date), y: .value(active.title, active.value(p)))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.accent)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            PointMark(x: .value("Datum", p.date), y: .value(active.title, active.value(p)))
                                .foregroundStyle(Theme.accent)
                                .symbolSize(40)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 220)
                    }
                    if active == .e1rm {
                        Text("Geschätztes Maximalgewicht für 1 Wiederholung (Epley-Formel) – zeigt deine Kraftentwicklung, auch wenn die Wiederholungen schwanken.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .glassCard()

                if usesWeight {
                    HStack(spacing: 12) {
                        StatTile(value: "\(Fmt.kg((points.map(\.e1rm).max() ?? 0).rounded())) kg", label: "Bestes 1RM", icon: "trophy.fill", tint: .yellow)
                        StatTile(value: "\(Fmt.kg(points.map(\.maxWeight).max() ?? 0)) kg", label: "Max. Gewicht", icon: "scalemass.fill")
                    }
                } else {
                    HStack(spacing: 12) {
                        StatTile(value: "\(points.map(\.maxReps).max() ?? 0)", label: "Meiste Wdh.", icon: "trophy.fill", tint: .yellow)
                        StatTile(value: "\(points.count)", label: "Einheiten", icon: "calendar")
                    }
                }

                SectionTitle(text: "Alle Einheiten")
                ForEach(points.reversed()) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.semibold))
                        Text(p.sets.map { $0.weight > 0 ? "\(Fmt.kg($0.weight)) kg × \($0.reps)" : "\($0.reps)" }.joined(separator: "  ·  "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .glassCard(padding: 12, radius: 20)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle(ExerciseLibrary.name(exerciseID))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Einzelnes Training

struct WorkoutDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let logID: UUID
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let log = store.logs.first(where: { $0.id == logID }) {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            StatTile(value: Fmt.duration(log.duration), label: "Dauer", icon: "clock.fill")
                            StatTile(value: "\(log.setCount)", label: "Sätze", icon: "list.number", tint: .blue)
                            StatTile(value: Fmt.volume(log.volume), label: "Volumen", icon: "scalemass.fill", tint: .purple)
                        }
                        ForEach(log.exercises) { e in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(ExerciseLibrary.name(e.exerciseID)).font(.headline)
                                    if log.prs.contains(e.exerciseID) {
                                        Badge(text: "PR", icon: "trophy.fill", tint: .yellow)
                                    }
                                }
                                ForEach(Array(e.sets.enumerated()), id: \.offset) { i, s in
                                    HStack {
                                        Text("Satz \(i + 1)").foregroundStyle(.secondary)
                                        Spacer()
                                        Text(s.weight > 0 ? "\(Fmt.kg(s.weight)) kg × \(s.reps)" : "\(s.reps) Wdh.")
                                            .monospacedDigit()
                                    }
                                    .font(.subheadline)
                                }
                            }
                            .glassCard()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle(log.dayName)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Löschen", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                }
                .confirmationDialog("Training löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) {
                        dismiss()
                        store.deleteLog(logID)
                    }
                }
            } else {
                ContentUnavailableView("Training gelöscht", systemImage: "trash")
            }
        }
        .appBackground()
    }
}
