import SwiftUI

struct CoachView: View {
    @EnvironmentObject var store: Store
    @State private var input = ""
    @State private var streaming: String?
    @State private var busy = false
    @State private var errorText: String?
    @State private var task: Task<Void, Never>?

    private let quick = ["Was soll ich heute trainieren?", "Wie war meine Woche?", "Mein Knie zwickt – was ersetze ich?",
                         "Wie werde ich bei Flanken sicherer?", "Aufwärmen vor dem Spiel", "Wie steigere ich meine Sprungkraft?"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text("🧤").font(.system(size: 26)).frame(width: 52, height: 52)
                                    .background(RadialGradient(colors: [Color(hex: "#E4FF7A"), Color(hex: "#7FA80A")], center: .topLeading, startRadius: 0, endRadius: 60), in: Circle())
                                VStack(alignment: .leading) {
                                    Text("Coach").font(.sport(36)).textCase(.uppercase)
                                    Text("Dein KI-Torwarttrainer").font(.subheadline).foregroundStyle(Color.mut)
                                }
                            }
                            .padding(.vertical, 8)
                            if store.s.chat.isEmpty {
                                bubble("Hi \(store.s.name)! 👋 Ich kenne dein Ziel (\(store.goal?.name ?? "noch offen")), deinen Plan und deine letzten Einheiten. Frag mich alles zu Training, Technik, Regeneration oder Spielvorbereitung.", user: false)
                            }
                            ForEach(store.s.chat) { msg in bubble(msg.text, user: msg.role == "user") }
                            if let s = streaming { bubble(s.isEmpty ? "Coach denkt nach …" : s, user: false).opacity(s.isEmpty ? 0.6 : 1) }
                            if let e = errorText {
                                Text(e).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 4)
                            }
                            if !store.s.chat.isEmpty && !busy {
                                Button("Chat leeren") { store.s.chat = [] }.font(.footnote).frame(maxWidth: .infinity)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(16)
                    }
                    .onChange(of: streaming) { _, _ in proxy.scrollTo("bottom") }
                    .onChange(of: store.s.chat.count) { _, _ in withAnimation { proxy.scrollTo("bottom") } }
                }
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quick, id: \.self) { q in
                                Button(q) { send(q) }.font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color.card, in: Capsule()).foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    HStack(spacing: 8) {
                        TextField("Frag deinen Coach …", text: $input, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
                            .onSubmit { send(input) }
                        if busy {
                            Button { task?.cancel() } label: {
                                Image(systemName: "stop.fill").frame(width: 40, height: 40).background(Color.card2, in: Circle())
                            }
                        } else {
                            Button { send(input) } label: {
                                Image(systemName: "arrow.up").font(.headline).foregroundStyle(.black)
                                    .frame(width: 40, height: 40).background(Color.lime, in: Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func bubble(_ text: String, user: Bool) -> some View {
        HStack {
            if user { Spacer(minLength: 40) }
            Text(LocalizedStringKey(text))   // Markdown (fett, Listen) wird dargestellt
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(user ? Color.black : .white)
                .background(user ? Color.lime : Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)
            if !user { Spacer(minLength: 40) }
        }
    }

    private func send(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        input = ""
        errorText = nil
        store.s.chat.append(ChatMessage(role: "user", text: q))
        busy = true
        streaming = ""
        let history = Array(store.s.chat.suffix(12))
        let system = CoachContext.systemPrompt(store)
        task = Task {
            do {
                let answer = try await ClaudeClient.stream(system: system, messages: history) { t in streaming = t }
                store.s.chat.append(ChatMessage(role: "assistant", text: answer))
                store.s.chat = Array(store.s.chat.suffix(40))
            } catch where Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError {
                if let s = streaming, !s.isEmpty { store.s.chat.append(ChatMessage(role: "assistant", text: s)) }
            } catch {
                errorText = error.localizedDescription
                if store.s.chat.last?.role == "user" { store.s.chat.removeLast() }
                input = q
            }
            streaming = nil
            busy = false
        }
    }
}

enum CoachContext {
    static func systemPrompt(_ store: Store) -> String {
        let cat = store.catalog
        let last = store.s.logs.suffix(12).map { l -> [String: Any] in
            var sets: [String: String] = [:]
            for (id, s) in l.sets { sets[store.name(id)] = s.map { ($0.kg > 0 ? "\(fmtKg($0.kg))kg×" : "") + "\($0.reps)" }.joined(separator: ", ") }
            return ["einheit": l.title ?? cat.session(l.session)?.name ?? l.session, "datum": DateUtil.format(l.date, "ddMMyyyy"),
                    "minuten": l.minutes, "anstrengung": l.rpe ?? 0, "saetze": sets]
        }
        let r = store.todayReadiness
        // Teilwerte vorab mit festem Typ berechnen – ein großes [String: Any]-Literal mit vielen Closures
        // bringt die Typprüfung von Swift sonst an ihre Grenzen.
        let plan: [String] = (0..<7).map { i -> String in
            let p = store.plan(for: i)
            let what: String = p == "game" ? "Spiel" : (p.flatMap { cat.session($0)?.name } ?? "frei")
            return DateUtil.weekdays[i] + ": " + what
        }
        let tagesform: [String: Int] = ["schlaf": r.sleep ?? 0, "beine": r.legs ?? 0, "energie": r.energy ?? 0]
        let tests: [String] = store.s.tests.suffix(10).map { t -> String in
            let def = cat.test(t.test)
            return "\(def?.name ?? t.test): \(fmtKg(t.value)) \(def?.unit ?? "")"
        }
        let dienstWoche: [String] = (0..<7).map { i -> String in
            let kind = NutritionData.shared.kindNames[store.dayKind(store.date(forWeekday: i))] ?? ""
            return DateUtil.weekdays[i] + ": " + kind
        }
        let laufplan: [String] = store.runPlan(weekOf: Date()).map { run -> String in
            "\(DateUtil.weekdays[DateUtil.dayIndex(run.date)]): \(run.title) \(fmtKg(run.km)) km"
        }
        let laeufe: [String] = store.s.runs.suffix(8).map { run -> String in
            "\(DateUtil.format(run.date, "ddMM")): \(String(format: "%.1f", run.km)) km in \(run.minutes) min"
        }
        let mahlzeiten: [String] = store.meals(on: Date()).map { m -> String in
            "\(m.slot.time) \(m.slot.name): \(m.recipe.name) (\(m.kcal) kcal)"
        }
        let typen: [String] = cat.sessions.map { se -> String in "\(se.name) (\(se.label))" }
        let gewicht: Double = (store.currentKg * 10).rounded() / 10
        let soll: Double = (store.targetKg(on: Date()) * 10).rounded() / 10
        let spieltag: String = store.s.gameDay < 0 ? "keiner" : DateUtil.weekdays[store.s.gameDay]
        let data: [String: Any] = [
            "name": store.s.name,
            "ziel": store.goal?.name ?? "nicht gesetzt",
            "einheitenProWoche": store.s.days,
            "spieltag": spieltag,
            "ort": store.s.place == "gym" ? "Fitnessstudio" : "Zuhause",
            "blockwoche": "\(store.weekIndex + 1) von 4 (\(store.blockWeek.name))",
            "heute": DateUtil.weekdays[store.todayIndex],
            "plan": plan,
            "tagesform": tagesform,
            "dieseWoche": "\(store.logsThisWeek.count) Einheiten",
            "letzteEinheiten": last,
            "tests": tests,
            "schritteHeute": Int(store.steps),
            "schrittZiel": store.s.body.stepGoal,
            "schritte7Tage": store.stepsWeek.map { $0.steps },
            "aktivVerbranntKcalHeute": Int(store.activeKcal),
            "schlafLetzte24hStunden": store.sleepHours.map { ($0 * 10).rounded() / 10 } ?? 0,
            "ruhepuls": store.restingHR ?? 0,
            "gewichtKg": gewicht,
            "zielGewichtKg": store.s.body.goalKg,
            "zielDatum": DateUtil.format(store.s.body.goalDate, "ddMMyyyy"),
            "sollGewichtHeute": soll,
            "kalorienzielHeute": store.calorieTarget(on: Date()),
            "heuteGegessenKcal": store.eatenKcal(on: Date()).kcal,
            "eiweissZielG": store.proteinTarget,
            "dienstHeute": NutritionData.shared.kindNames[store.dayKind(Date())] ?? "",
            "dienstWoche": dienstWoche,
            "laufplanWoche": laufplan,
            "letzteLaeufe": laeufe,
            "tempoMinProKm": Store.pace(store.paceMinPerKm),
            "mahlzeitenHeute": mahlzeiten,
            "hintergrund": "Läuft regelmäßig 5–10 km (~6:20/km), will abnehmen (Ziel ca. 100 kg), arbeitet im Schichtdienst.",
            "einheitenTypen": typen,
        ]
        let json = (try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        Du bist der persönliche KI-Coach in einer Trainings-App für einen Fußball-Torwart (Amateur), der außerdem abnehmen möchte. Du bist erfahrener Torwart- und Athletiktrainer.
        Antworte auf Deutsch, per Du, motivierend aber ehrlich, kurz und konkret (meist unter 150 Wörtern). Nutze die Daten unten, auch Dienstplan (Früh/Spät/Nacht), Gewicht, Kalorienziel und Mahlzeiten – berücksichtige Schichten, Erholung und das Kaloriendefizit. Empfiehl bevorzugt Einheiten und Übungen aus der App, mit Sätzen × Wiederholungen. Bei Schmerzen: keine Diagnose, Belastung reduzieren, schmerzfreie Alternativen nennen und bei anhaltenden Beschwerden Arzt oder Physio empfehlen. Formatiere mit kurzen Absätzen, **fett** für Wichtiges und Listen mit "- ".

        DATEN DES SPIELERS (JSON):
        \(json)
        """
    }
}
