import SwiftUI
import AudioToolbox

// MARK: - Einstellungen

struct ReactionConfig: Hashable {
    enum Signal: String, CaseIterable, Identifiable { case both, visual, voice
        var id: String { rawValue }
        var name: String { self == .both ? "Bild + Stimme" : self == .visual ? "Nur Bild" : "Nur Stimme" }
    }
    enum Pace: String, CaseIterable, Identifiable { case easy, medium, fast
        var id: String { rawValue }
        var name: String { self == .easy ? "Locker" : self == .medium ? "Mittel" : "Schnell" }
        /// Abstand zwischen zwei Signalen in Sekunden
        var gap: ClosedRange<Double> { self == .easy ? 3.0...5.0 : self == .medium ? 2.0...3.6 : 1.3...2.4 }
    }
    var signal: Signal = .both
    var pace: Pace = .medium
    var diagonals = false
    var fakes = true
    var rounds = 4
    var roundSeconds = 45
    var restSeconds = 60
}

enum ReactionDir: CaseIterable {
    case left, right, up, down, upLeft, upRight, downLeft, downRight

    static let basic: [ReactionDir] = [.left, .right, .up, .down]

    var word: String {
        switch self {
        case .left: return "Links"
        case .right: return "Rechts"
        case .up: return "Hoch"
        case .down: return "Tief"
        case .upLeft: return "Links hoch"
        case .upRight: return "Rechts hoch"
        case .downLeft: return "Links tief"
        case .downRight: return "Rechts tief"
        }
    }
    var symbol: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .upLeft: return "arrow.up.left"
        case .upRight: return "arrow.up.right"
        case .downLeft: return "arrow.down.left"
        case .downRight: return "arrow.down.right"
        }
    }
    var color: Color {
        switch self {
        case .left, .upLeft, .downLeft: return .cyan
        case .right, .upRight, .downRight: return .orange
        case .up: return .lime
        case .down: return .purple
        }
    }
}

// MARK: - Ablauf

final class ReactionEngine: ObservableObject {
    enum Stage: Equatable { case countdown(Int), active, rest, done }
    struct Shown: Equatable { let dir: ReactionDir; let fake: Bool }

    let config: ReactionConfig
    @Published var stage: Stage = .countdown(3)
    @Published var shown: Shown?
    @Published var round = 1
    @Published var secondsLeft = 0
    @Published var signals = 0
    @Published var fakes = 0
    @Published var paused = false
    let started = Date()

    private var timer: Timer?
    private var stageEnd = Date()
    private var nextSignal = Date()
    private var signalOff = Date()
    private var lastDirs: [ReactionDir] = []
    private var pausedAt: Date?
    private let voice = IntervalVoice()

    init(config: ReactionConfig) { self.config = config }

    func begin() {
        voice.prepare()
        startCountdown()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        voice.stop()
    }

    func togglePause() {
        if let p = pausedAt {
            // Zeiten um die Pausendauer verschieben
            let d = Date().timeIntervalSince(p)
            stageEnd += d; nextSignal += d; signalOff += d
            pausedAt = nil
            paused = false
        } else {
            pausedAt = Date()
            paused = true
            shown = nil
        }
    }

    func finishNow() {
        stage = .done
        shown = nil
        stop()
    }

    private func startCountdown() {
        stage = .countdown(3)
        stageEnd = Date().addingTimeInterval(3)
        if config.signal != .visual { voice.say(round == 1 ? "Grundstellung. Los geht's in drei" : "Runde \(round). Grundstellung") }
    }

    private func tick() {
        guard pausedAt == nil else { return }
        let now = Date()
        let left = stageEnd.timeIntervalSince(now)
        secondsLeft = max(0, Int(left.rounded(.up)))
        switch stage {
        case .countdown:
            if left <= 0 {
                stage = .active
                stageEnd = now.addingTimeInterval(Double(config.roundSeconds))
                nextSignal = now.addingTimeInterval(0.8)
                AudioServicesPlaySystemSound(1113)
            } else {
                let n = Int(left.rounded(.up))
                if stage != .countdown(n) { stage = .countdown(n); Haptics.tap() }
            }
        case .active:
            if shown != nil && now >= signalOff { shown = nil }
            if left <= 0 {
                shown = nil
                if round >= config.rounds {
                    if config.signal != .visual { voice.say("Geschafft. Stark gemacht!") }
                    AudioServicesPlaySystemSound(1025)
                    Haptics.success()
                    finishNow()
                } else {
                    stage = .rest
                    stageEnd = now.addingTimeInterval(Double(config.restSeconds))
                    AudioServicesPlaySystemSound(1013)
                    if config.signal != .visual { voice.say("Pause. Locker bleiben, durchatmen.") }
                }
                return
            }
            if shown == nil && now >= nextSignal && left > 1.0 { fire(now) }
        case .rest:
            if left <= 0 {
                round += 1
                startCountdown()
            } else if Int(left.rounded(.up)) == 10 && Int((left + 0.05).rounded(.up)) != 10 {
                if config.signal != .visual { voice.say("Noch zehn Sekunden") }
            }
        case .done:
            break
        }
    }

    private func fire(_ now: Date) {
        let pool = config.diagonals ? ReactionDir.allCases : ReactionDir.basic
        var dir = pool.randomElement() ?? .left
        // nicht dreimal hintereinander dieselbe Richtung
        if lastDirs.suffix(2).allSatisfy({ $0 == dir }) && lastDirs.count >= 2 {
            dir = pool.filter { $0 != dir }.randomElement() ?? dir
        }
        lastDirs.append(dir)
        let fake = config.fakes && Double.random(in: 0..<1) < 0.18
        shown = Shown(dir: dir, fake: fake)
        signalOff = now.addingTimeInterval(fake ? 1.0 : 0.9)
        nextSignal = now.addingTimeInterval(Double.random(in: config.pace.gap))
        if fake { fakes += 1 } else { signals += 1 }
        if config.signal != .visual { voice.say(fake ? "Stopp" : dir.word) }
        if config.signal == .visual { Haptics.tap() }
    }
}

// MARK: - Einstieg

struct ReactionSetupView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var config = ReactionConfig()
    @State private var running: ReactionConfig?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        tip("📱", "Handy 2–3 m vor dir aufstellen, z. B. an eine Flasche gelehnt.")
                        tip("🧤", "Torwart-Grundstellung, auf den Ballen, Hände vorne.")
                        tip("↔️", "Links/Rechts: Seitschritt und Abdruck – auf weichem Boden auch Hechtsprung.")
                        tip("⬆️", "Hoch: Sprung mit Armen nach oben. ⬇️ Tief: abtauchen, Hände zum Boden.")
                        tip("🟥", "Rot / „Stopp“: nicht reagieren, stehen bleiben.")
                    }
                    .font(.subheadline)
                }
                .listRowBackground(Color.card)

                Section("Signal") {
                    Picker("Signal", selection: $config.signal) {
                        ForEach(ReactionConfig.Signal.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Tempo", selection: $config.pace) {
                        ForEach(ReactionConfig.Pace.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Mit Ecken (links hoch, rechts tief …)", isOn: $config.diagonals)
                    Toggle("Täuschungen (Rot = stehen bleiben)", isOn: $config.fakes)
                }
                .listRowBackground(Color.card)

                Section {
                    Stepper("Runden: \(config.rounds)", value: $config.rounds, in: 1...10)
                    Picker("Rundendauer", selection: $config.roundSeconds) {
                        ForEach([30, 45, 60, 90], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    Picker("Pause", selection: $config.restSeconds) {
                        ForEach([30, 45, 60, 90], id: \.self) { Text("\($0) s").tag($0) }
                    }
                } header: { Text("Umfang") } footer: {
                    Text("Gesamt ca. \(totalMinutes) Minuten. Vorher 5 Minuten aufwärmen (Aktivierung).")
                }
                .listRowBackground(Color.card)

                Section {
                    Button { running = config } label: {
                        Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity).fontWeight(.bold)
                    }
                    .foregroundStyle(Color.lime)
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Torwart-Reaktion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } } }
            .fullScreenCover(item: $running) { c in
                ReactionRunView(config: c) { dismiss() }.environmentObject(store)
            }
        }
    }

    private var totalMinutes: Int {
        let s = config.rounds * (config.roundSeconds + 3) + max(0, config.rounds - 1) * config.restSeconds
        return max(1, Int((Double(s) / 60).rounded()))
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) { Text(icon); Text(text) }
    }
}

extension ReactionConfig: Identifiable {
    var id: String { "\(signal.rawValue)-\(pace.rawValue)-\(diagonals)-\(fakes)-\(rounds)-\(roundSeconds)-\(restSeconds)" }
}

// MARK: - Training

struct ReactionRunView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: ReactionEngine
    let onSaved: () -> Void

    init(config: ReactionConfig, onSaved: @escaping () -> Void) {
        _engine = StateObject(wrappedValue: ReactionEngine(config: config))
        self.onSaved = onSaved
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer()
                center
                Spacer()
                bottomBar
            }
            .padding(16)
        }
        .animation(.easeOut(duration: 0.08), value: engine.shown)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true; engine.begin() }
        .onDisappear { engine.stop(); UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var background: Color {
        guard let s = engine.shown, engine.config.signal != .voice else { return Color.bg }
        return s.fake ? Color.red : s.dir.color
    }

    private var topBar: some View {
        HStack {
            Text(engine.stage == .done ? "Fertig" : "Runde \(engine.round) / \(engine.config.rounds)")
                .font(.headline)
            Spacer()
            if engine.stage == .active || engine.stage == .rest {
                Text("\(engine.secondsLeft) s").font(.headline.monospacedDigit())
            }
        }
        .foregroundStyle(background == Color.bg ? Color.white : Color.black)
    }

    @ViewBuilder private var center: some View {
        switch engine.stage {
        case .countdown(let n):
            VStack(spacing: 8) {
                Text("Grundstellung").font(.sport(30)).textCase(.uppercase).foregroundStyle(Color.mut)
                Text("\(n)").font(.system(size: 140, weight: .heavy).monospacedDigit())
            }
        case .active:
            if engine.paused {
                Text("PAUSE").font(.sport(60)).foregroundStyle(Color.mut)
            } else if let s = engine.shown, engine.config.signal != .voice {
                VStack(spacing: 10) {
                    Image(systemName: s.fake ? "hand.raised.fill" : s.dir.symbol)
                        .font(.system(size: 170, weight: .black))
                    Text(s.fake ? "STOPP" : s.dir.word.uppercased()).font(.sport(56))
                }
                .foregroundStyle(Color.black)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: engine.config.signal == .voice ? "ear" : "eye")
                        .font(.system(size: 60)).foregroundStyle(Color.mut)
                    Text(engine.config.signal == .voice ? "Hör hin …" : "Bereit …").font(.sport(30)).foregroundStyle(Color.mut)
                }
            }
        case .rest:
            VStack(spacing: 8) {
                Text("Pause").font(.sport(40)).textCase(.uppercase).foregroundStyle(Color.cyan)
                Text("\(engine.secondsLeft)").font(.system(size: 120, weight: .heavy).monospacedDigit())
                Text("Locker gehen, Arme ausschütteln").font(.subheadline).foregroundStyle(Color.mut)
            }
        case .done:
            summary
        }
    }

    private var summary: some View {
        let minutes = max(1, Int(Date().timeIntervalSince(engine.started) / 60))
        return VStack(spacing: 14) {
            Text("🧤").font(.system(size: 64))
            Text("Stark reagiert!").font(.sport(36)).textCase(.uppercase)
            HStack(spacing: 10) {
                box("\(engine.round)", "Runden")
                box("\(engine.signals)", "Signale")
                box("\(engine.fakes)", "Täuschungen")
            }
            Button("Speichern") { save(minutes: minutes) }.buttonStyle(LimeButton())
            Button("Verwerfen", role: .destructive) { dismiss() }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if engine.stage != .done {
                Button(engine.paused ? "Weiter" : "Pause") { engine.togglePause(); Haptics.tap() }
                    .buttonStyle(LimeButton(secondary: true))
                Button("Beenden") { engine.finishNow() }.buttonStyle(LimeButton(secondary: true))
            }
        }
    }

    private func box(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(.sport(28)); Text(l).font(.caption).foregroundStyle(Color.mut) }
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func save(minutes: Int) {
        let kcal = Int(7 * store.currentKg * Double(minutes) / 60)
        store.s.logs.append(WorkoutLog(session: "react", date: Date(), minutes: minutes, sets: [:], rpe: nil, volume: 0,
                                       title: "Reaktionstraining (Signale)", kcal: kcal))
        if store.s.healthEnabled {
            let start = engine.started
            Task { await HealthService.shared.saveActivity(.keeper, start: start, end: Date(), km: 0, kcal: Double(kcal)) }
        }
        Haptics.success()
        dismiss()
        onSaved()
    }
}
