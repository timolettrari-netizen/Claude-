import Foundation
import AVFoundation

/// Ein Abschnitt eines strukturierten Laufs (Lauf-Geh- oder Intervall-Training)
struct RunPhase: Hashable {
    enum Kind: String { case walk, jog, easy, fast }
    let kind: Kind
    let seconds: Int
}

/// Zielwerte für den Sprach-Coach
struct RunTargets: Hashable {
    var paceLo: Double?       // min/km – schnellste gewünschte Pace
    var paceHi: Double?       // min/km – langsamste gewünschte Pace
    var hrLo: Int
    var hrHi: Int
    var fastPaceLo: Double?
    var fastPaceHi: Double?
    var fastHrLo: Int
    var fastHrHi: Int
    var phases: [RunPhase]
    var goalKm: Double?

    var zoneText: String { "Puls \(hrLo)–\(hrHi)" }
}

extension Store {
    var maxHeartRate: Int { s.maxHR > 0 ? s.maxHR : Int((208 - 0.7 * Double(s.body.age)).rounded()) }

    /// Zielwerte je Lauftyp: locker = Zone 2 (60–75 % HFmax), zügig = 80–90 %
    func runTargets(for plan: PlannedRun?) -> RunTargets {
        let hf = Double(maxHeartRate), pace = paceMinPerKm
        var t = RunTargets(paceLo: nil, paceHi: nil, hrLo: Int(hf * 0.60), hrHi: Int(hf * 0.75),
                           fastPaceLo: pace * 0.85, fastPaceHi: pace * 0.95,
                           fastHrLo: Int(hf * 0.80), fastHrHi: Int(hf * 0.90), phases: [], goalKm: plan?.km)
        guard let plan else { t.hrHi = Int(hf * 0.85); return t }   // freier Lauf: nur Warnung bei sehr hohem Puls
        t.paceLo = pace * 1.06
        t.paceHi = pace * 1.16
        let w = runWeekNumber(DateUtil.weekStart(plan.date))
        switch plan.type {
        case "wr":
            let jog = w == 1 ? 60 : 120, reps = w == 1 ? 8 : 6
            t.phases = [RunPhase(kind: .walk, seconds: 300)]
                + (0..<reps).flatMap { _ in [RunPhase(kind: .jog, seconds: jog), RunPhase(kind: .walk, seconds: 120)] }
                + [RunPhase(kind: .walk, seconds: 300)]
            t.paceLo = nil; t.paceHi = nil      // beim Traben zählt nur „locker“ – Puls statt Tempo
        case "int":
            let reps = min(8, 4 + w / 3)
            t.phases = [RunPhase(kind: .easy, seconds: 600)]
                + (0..<reps).flatMap { _ in [RunPhase(kind: .fast, seconds: 120), RunPhase(kind: .jog, seconds: 120)] }
                + [RunPhase(kind: .easy, seconds: 600)]
        default:
            break
        }
        return t
    }
}

/// Sprach-Coach: sagt Abschnitte, Kilometer, Tempo- und Pulshinweise an.
final class RunCoach: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var message = "Los geht's – ich melde mich unterwegs."
    @Published var phaseIndex: Int?
    @Published var phaseRemaining: Int = 0
    var voiceOn: Bool

    private let targets: RunTargets
    private let synth = AVSpeechSynthesizer()
    private var lastKm = 0
    private var lastFeedback: TimeInterval = 0
    private var lastSpoken: TimeInterval = -999
    private var goodCount = 0
    private var goalAnnounced = false
    private var halfAnnounced = false

    init(targets: RunTargets, voiceOn: Bool) {
        self.targets = targets
        self.voiceOn = voiceOn
        super.init()
        synth.delegate = self
    }

    // MARK: Ablauf

    func begin() {
        if let first = targets.phases.first {
            phaseIndex = 0
            say("Los geht's. \(phaseText(first))")
        } else if let lo = targets.paceLo, let hi = targets.paceHi {
            say("Los geht's. Lauf locker, Tempo \(Self.spokenPace(lo)) bis \(Self.spokenPace(hi)) pro Kilometer, Puls unter \(targets.hrHi).")
        } else {
            say("Los geht's. Ich sage dir jeden Kilometer an.")
        }
    }

    /// Jede Sekunde aufrufen
    func update(elapsed: TimeInterval, km: Double, rollingPace: Double?, hr: Int?) {
        // Abschnitte (Lauf-Geh / Intervalle)
        var kind: RunPhase.Kind = .easy
        if !targets.phases.isEmpty {
            var acc = 0
            var idx = targets.phases.count
            for (i, p) in targets.phases.enumerated() {
                if Int(elapsed) < acc + p.seconds { idx = i; phaseRemaining = acc + p.seconds - Int(elapsed); break }
                acc += p.seconds
            }
            if idx >= targets.phases.count {
                if phaseIndex != nil { phaseIndex = nil; say("Geschafft! Alle Abschnitte erledigt. Du kannst jetzt beenden."); }
                return
            }
            kind = targets.phases[idx].kind
            if phaseIndex != idx {
                phaseIndex = idx
                let next = targets.phases[idx]
                let left = targets.phases[idx...].filter { $0.kind == .jog || $0.kind == .fast }.count
                say(phaseText(next) + (next.kind == .jog || next.kind == .fast ? " Noch \(left) Mal." : ""))
                lastFeedback = elapsed
                return
            }
        }

        // Kilometer-Ansage
        let k = Int(km)
        if k > lastKm {
            lastKm = k
            var text = "Kilometer \(k). Zeit \(Self.spokenTime(elapsed))."
            if km > 0.05 { text += " Durchschnitt \(Self.spokenPace(elapsed / 60 / km)) pro Kilometer." }
            if let hr { text += " Puls \(hr)." }
            say(text)
            lastFeedback = elapsed
            return
        }

        // Halbzeit / Ziel
        if let goal = targets.goalKm, goal > 0 {
            if !halfAnnounced && km >= goal / 2 && goal >= 3 { halfAnnounced = true; say("Halbzeit. Noch \(Self.spokenKm(goal - km)) Kilometer."); return }
            if !goalAnnounced && km >= goal { goalAnnounced = true; say("Ziel erreicht! \(Self.spokenKm(goal)) Kilometer. Locker auslaufen oder beenden."); return }
        }

        // Rückmeldung alle 60 Sekunden (nicht in den ersten 3 Minuten, nicht beim Gehen)
        guard elapsed - lastFeedback >= 60, elapsed > 180, kind != .walk else { return }
        lastFeedback = elapsed
        feedback(kind: kind, pace: rollingPace, hr: hr)
    }

    private func feedback(kind: RunPhase.Kind, pace: Double?, hr: Int?) {
        let fast = kind == .fast
        let hrLo = fast ? targets.fastHrLo : targets.hrLo
        let hrHi = fast ? targets.fastHrHi : targets.hrHi
        let pLo = fast ? targets.fastPaceLo : targets.paceLo
        let pHi = fast ? targets.fastPaceHi : targets.paceHi

        if let hr {
            if hr > hrHi + 3 {
                goodCount = 0
                say(fast ? "Puls \(hr) – das reicht, nicht noch schneller." : "Etwas langsamer. Puls \(hr), Ziel unter \(hrHi). Wenn nötig kurz gehen.")
                return
            }
            if hr < hrLo - 5 && (fast || kind == .easy) && pLo != nil {
                goodCount = 0
                say(fast ? "Mehr Tempo! Puls erst \(hr)." : "Du kannst etwas schneller laufen. Puls \(hr).")
                return
            }
        }
        if let pace, let pLo, let pHi {
            if pace < pLo - 0.1 && (hr == nil || hr! > hrLo) {
                goodCount = 0
                say("Etwas langsamer. Du läufst \(Self.spokenPace(pace)), Ziel \(Self.spokenPace(pLo)) bis \(Self.spokenPace(pHi)).")
                return
            }
            if pace > pHi + 0.15 && (hr == nil || hr! < hrHi) {
                goodCount = 0
                say("Ein bisschen schneller. Du läufst \(Self.spokenPace(pace)), Ziel \(Self.spokenPace(pLo)) bis \(Self.spokenPace(pHi)).")
                return
            }
        }
        goodCount += 1
        if goodCount % 3 == 1 {
            say(hr.map { "Perfekt, genau richtig. Puls \($0)." } ?? "Gutes Tempo, weiter so.")
        }
    }

    private func phaseText(_ p: RunPhase) -> String {
        let min = p.seconds / 60, dur = p.seconds % 60 == 0 ? "\(min) \(min == 1 ? "Minute" : "Minuten")" : "\(p.seconds) Sekunden"
        switch p.kind {
        case .walk: return "Jetzt gehen, \(dur)."
        case .jog: return "Jetzt locker traben, \(dur)."
        case .easy: return "Locker laufen, \(dur)."
        case .fast: return "Jetzt zügig, \(dur)! Tempo \(targets.fastPaceLo.map { Self.spokenPace($0) } ?? "flott")."
        }
    }

    // MARK: Sprache

    func say(_ text: String) {
        DispatchQueue.main.async { self.message = text }
        guard voiceOn else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if synth.isSpeaking && now - lastSpoken < 4 { return }
        lastSpoken = now
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "de-DE")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !s.isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    // MARK: Formatierung für die Sprachausgabe

    static func spokenPace(_ minPerKm: Double) -> String {
        let s = Int((minPerKm * 60).rounded())
        return s % 60 == 0 ? "\(s / 60) Minuten" : "\(s / 60) \(s % 60)"
    }
    static func spokenTime(_ t: TimeInterval) -> String {
        let s = Int(t), h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h) Stunde \(m) Minuten" : "\(m) Minuten \(s % 60)"
    }
    static func spokenKm(_ km: Double) -> String {
        String(format: "%.1f", max(0, km)).replacingOccurrences(of: ".", with: " Komma ")
    }
}
