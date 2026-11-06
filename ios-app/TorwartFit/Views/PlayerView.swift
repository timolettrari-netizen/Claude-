import SwiftUI
import AudioToolbox

/// Geführtes Training: Satz für Satz, Pausen-Timer, Gewichte, Zusammenfassung.
final class PlayerModel: ObservableObject {
    enum Phase { case work, rest, timed, done }

    let session: String
    let short: Bool
    let list: [String]
    let start = Date()

    @Published var index = 0
    @Published var setNo = 1
    @Published var sets: [String: [SetEntry]] = [:]
    @Published var phase: Phase = .work
    @Published var phaseEnd = Date()
    @Published var phaseLength: Double = 1
    @Published var kg: Double = 0
    @Published var reps: Int = 10
    @Published var rpe: Int?
    @Published var now = Date()
    private var lastBeep = -1

    init(session: String, short: Bool, store: Store) {
        self.session = session
        self.short = short
        self.list = store.exercises(of: session, short: short)
        prepare(store)
    }

    var current: String? { index < list.count ? list[index] : nil }
    var remaining: Double { max(0, phaseEnd.timeIntervalSince(now)) }

    func prepare(_ store: Store) {
        guard let id = current else { return }
        let d = store.dose(id, short: short)
        reps = d.reps
        if let done = sets[id], let last = done.last { kg = last.kg }
        else if let p = store.progression(id, short: short) { kg = p.up ?? (store.lastSets(id)?.map(\.kg).max() ?? 0) }
        else { kg = 0 }
    }

    func tick(_ store: Store) {
        now = Date()
        guard phase == .rest || phase == .timed else { return }
        let left = Int(remaining.rounded(.up))
        if left <= 3 && left > 0 && left != lastBeep { lastBeep = left; AudioServicesPlaySystemSound(1103) }
        if remaining <= 0 {
            lastBeep = -1
            AudioServicesPlaySystemSound(1013)
            Haptics.success()
            if phase == .rest { phase = .work; prepare(store) }
            else if let id = current { logSet(store, kg: 0, reps: store.dose(id, short: short).reps) }
        }
    }

    func startTimed(seconds: Int) {
        phaseLength = Double(seconds)
        phaseEnd = Date().addingTimeInterval(Double(seconds))
        phase = .timed
        AudioServicesPlaySystemSound(1103)
    }

    func logSet(_ store: Store, kg: Double, reps: Int) {
        guard let id = current else { return }
        sets[id, default: []].append(SetEntry(kg: kg, reps: reps))
        Haptics.tap()
        let d = store.dose(id, short: short)
        setNo += 1
        let finishedExercise = setNo > d.sets
        if finishedExercise { index += 1; setNo = 1 }
        if index >= list.count { phase = .done; return }
        let r = store.rest(finishedExercise ? list[index - 1] : id)
        if r > 0 {
            phaseLength = Double(r)
            phaseEnd = Date().addingTimeInterval(Double(r))
            phase = .rest
        } else {
            phase = .work
        }
        prepare(store)
    }

    func move(_ delta: Int, _ store: Store) {
        index = min(list.count, max(0, index + delta))
        if index >= list.count { phase = .done; return }
        setNo = (sets[list[index]]?.count ?? 0) + 1
        phase = .work
        prepare(store)
    }

    var totalSets: Int { sets.values.reduce(0) { $0 + $1.count } }
    var volume: Double { sets.values.flatMap { $0 }.reduce(0) { $0 + $1.kg * Double($1.reps) } }
}

struct PlayerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var m: PlayerModel
    @State private var detail: Sel?
    @State private var confirmQuit = false
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(launch: Launch, store: Store) {
        _m = StateObject(wrappedValue: PlayerModel(session: launch.session, short: launch.short, store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if m.phase == .done { summary } else if m.phase == .rest { restView } else { workView }
        }
        .padding(.horizontal, 16)
        .background(Color.bg.ignoresSafeArea())
        .onReceive(timer) { _ in m.tick(store) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $detail) { s in ExerciseDetailView(id: s.id, short: m.short).environmentObject(store) }
        .confirmationDialog("Training beenden?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Beenden ohne Speichern", role: .destructive) { dismiss() }
            Button("Zur Zusammenfassung") { m.phase = .done }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button { confirmQuit = true } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32)
                        .background(Color.card2, in: Circle())
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(store.catalog.session(m.session)?.name ?? "").font(.subheadline.weight(.semibold))
                    Text(clock(m.now.timeIntervalSince(m.start))).font(.caption.monospacedDigit()).foregroundStyle(Color.mut)
                }
                Spacer()
                Button("Ende") { m.phase = .done }.font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).frame(height: 32).background(Color.card2, in: Capsule())
            }
            HStack(spacing: 3) {
                ForEach(0..<m.list.count, id: \.self) { k in
                    Capsule().fill(k < m.index ? Color.lime : k == m.index ? Color.white : Color.card2).frame(height: 4)
                }
            }
        }
        .padding(.top, 8).padding(.bottom, 14)
    }

    @ViewBuilder private var workView: some View {
        if let id = m.current {
            let d = store.dose(id, short: m.short)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ExerciseMedia(id: id)
                    Text(store.name(id)).font(.sport(34)).textCase(.uppercase).lineLimit(2).minimumScaleFactor(0.7)
                    (Text("Satz ").foregroundColor(Color.mut) + Text("\(min(m.setNo, d.sets)) von \(d.sets)").bold()
                     + Text(" · Ziel ").foregroundColor(Color.mut) + Text(d.targetText).bold())
                    if let p = store.progression(id, short: m.short) {
                        Text(p.text + (p.up.map { " → heute \(fmtKg($0)) kg probieren" } ?? ""))
                            .font(.footnote.weight(p.up == nil ? .regular : .semibold))
                            .foregroundStyle(p.up == nil ? Color.white : Color.lime)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(p.up == nil ? Color.card2 : Color.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let done = m.sets[id], !done.isEmpty {
                        HStack {
                            ForEach(Array(done.enumerated()), id: \.offset) { _, s in
                                Text("✓ " + (s.kg > 0 ? "\(fmtKg(s.kg)) kg × " : "") + "\(s.reps)")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Color.lime)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.lime.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    if m.phase == .timed {
                        TimerRing(remaining: m.remaining, total: m.phaseLength, color: .lime).frame(height: 220)
                    } else if !d.timed {
                        HStack(spacing: 12) {
                            if store.isLoaded(id) {
                                StepperBox(title: "Gewicht kg", value: fmtKg(m.kg),
                                           minus: { m.kg = max(0, m.kg - 2.5) }, plus: { m.kg += 2.5 })
                            }
                            StepperBox(title: "Wiederholungen", value: "\(m.reps)",
                                       minus: { m.reps = max(0, m.reps - 1) }, plus: { m.reps += 1 })
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 6) {
                if m.phase == .timed {
                    Button("Fertig") { m.logSet(store, kg: 0, reps: d.reps) }.buttonStyle(LimeButton(secondary: true))
                } else if d.timed {
                    Button("▶ Start \(d.targetText)") { m.startTimed(seconds: d.seconds) }.buttonStyle(LimeButton())
                } else {
                    Button("Satz erledigt ✓") { m.logSet(store, kg: store.isLoaded(id) ? m.kg : 0, reps: m.reps) }.buttonStyle(LimeButton())
                }
                HStack {
                    Button("‹ Zurück") { m.move(-1, store) }.opacity(m.index == 0 ? 0 : 1).disabled(m.index == 0)
                    Spacer()
                    Button("Anleitung") { detail = Sel(id: id) }
                    Spacer()
                    Button("Überspringen ›") { m.move(1, store) }
                }
                .font(.subheadline).padding(.vertical, 8)
            }
            .padding(.bottom, 8)
        }
    }

    private var restView: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("PAUSE").font(.footnote.weight(.bold)).foregroundStyle(Color.mut)
            TimerRing(remaining: m.remaining, total: m.phaseLength, color: .blue).frame(height: 250)
            if let id = m.current {
                Text("Als Nächstes").font(.footnote).foregroundStyle(Color.mut)
                Text("Satz \(m.setNo) · \(store.name(id))").font(.title3.bold()).multilineTextAlignment(.center)
            }
            Spacer()
            HStack(spacing: 10) {
                Button("+15 s") { m.phaseEnd = m.phaseEnd.addingTimeInterval(15); m.phaseLength += 15 }
                    .buttonStyle(LimeButton(secondary: true)).frame(width: 120)
                Button("Pause überspringen") { m.phaseEnd = Date() }.buttonStyle(LimeButton())
            }
            .padding(.bottom, 12)
        }
    }

    private var summary: some View {
        let minutes = max(1, Int(Date().timeIntervalSince(m.start) / 60))
        return ScrollView {
            VStack(spacing: 14) {
                Text("🏆").font(.system(size: 64)).padding(.top, 20)
                Text("Stark gemacht!").font(.sport(36)).textCase(.uppercase)
                Text("\(store.catalog.session(m.session)?.name ?? "") abgeschlossen").foregroundStyle(Color.mut)
                HStack(spacing: 10) {
                    stat("\(minutes)", "Minuten")
                    stat("\(m.totalSets)", "Sätze")
                    stat(m.volume >= 1000 ? String(format: "%.1f t", m.volume / 1000) : "\(Int(m.volume)) kg", "Volumen")
                }
                Text("Wie anstrengend war's? (1 = locker, 10 = maximal)").font(.subheadline).foregroundStyle(Color.mut)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(1...10, id: \.self) { v in
                        Button { m.rpe = v; Haptics.tap() } label: {
                            Text("\(v)").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .foregroundStyle(m.rpe == v ? Color.black : .white)
                                .background(m.rpe == v ? Color.lime : Color.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Speichern") {
                    store.saveWorkout(session: m.session, start: m.start, sets: m.sets, rpe: m.rpe)
                    Haptics.success()
                    dismiss()
                }
                .buttonStyle(LimeButton())
                .padding(.top, 10)
                Button("Verwerfen", role: .destructive) { dismiss() }.padding(.bottom, 20)
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.sport(28))
            Text(l).font(.caption).foregroundStyle(Color.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct StepperBox: View {
    let title: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void
    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Color.mut)
            HStack {
                round("minus", minus)
                Spacer()
                Text(value).font(.system(size: 30, weight: .bold).monospacedDigit())
                Spacer()
                round("plus", plus)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
    }
    private func round(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.tap() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.lime)
                .frame(width: 40, height: 40).background(Color.card2, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct TimerRing: View {
    let remaining: Double
    let total: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(Color.card2, lineWidth: 16)
            Circle().trim(from: 0, to: max(0, min(1, remaining / max(total, 1))))
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: remaining)
            let s = Int(remaining.rounded(.up))
            Text(s >= 60 ? String(format: "%d:%02d", s / 60, s % 60) : "\(s)")
                .font(.system(size: 54, weight: .bold).monospacedDigit())
        }
        .padding(8)
    }
}
