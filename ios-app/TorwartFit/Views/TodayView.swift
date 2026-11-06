import SwiftUI

struct Sel: Identifiable, Hashable { let id: String }

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var preview: Sel?
    @State private var showGoal = false

    private var greeting: String {
        let h = DateUtil.calendar.component(.hour, from: Date())
        let g = h < 11 ? "Guten Morgen" : h < 18 ? "Hallo" : "Guten Abend"
        return store.s.name.isEmpty ? g : "\(g), \(store.s.name)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DateUtil.format(Date(), "EEEEdMMMM").uppercased())
                            .font(.footnote.weight(.bold)).foregroundStyle(Color.lime)
                        Text(greeting).font(.sport(38)).textCase(.uppercase).lineLimit(2).minimumScaleFactor(0.6)
                    }
                    .padding(.top, 8)
                    HeroCard(preview: $preview)
                    GoalCard().onTapGesture { showGoal = true }
                    if store.s.healthEnabled { HealthCard() }
                    ReadinessCard()
                    WeekCard(preview: $preview)
                    Text("Auf dich abgestimmt: regelmäßige Läufe (5–10 km) sind deine Basis, deshalb liegt der Schwerpunkt auf Kraft, Sprungkraft und Beweglichkeit. Explosives nie am Tag nach dem Spiel, am Tag davor nur Aktivierung. Bei Schmerzen Übung weglassen.")
                        .font(.footnote).foregroundStyle(Color.mut).padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $preview) { s in SessionPreview(session: s.id).environmentObject(store) }
            .sheet(isPresented: $showGoal) { GoalPickerView(first: false).environmentObject(store) }
        }
    }
}

struct HeroCard: View {
    @EnvironmentObject var store: Store
    @Binding var preview: Sel?

    var body: some View {
        let i = store.todayIndex, t = store.plan(for: i), tired = store.isTired
        VStack(alignment: .leading, spacing: 6) {
            if t == "game" {
                kicker("Spieltag")
                Text("⚽️ Heute ist Spiel").font(.sport(34)).textCase(.uppercase)
                Text("Kein Training. 10 Minuten Aktivierung als Aufwärmen.").foregroundStyle(.white.opacity(0.85))
                Button("Aktivierung starten") { store.start("mobS", short: false) }.buttonStyle(LimeButton()).padding(.top, 10)
            } else if let t, let se = store.catalog.session(t) {
                let done = store.done(t, on: i)
                kicker(done ? "✓ Erledigt" : "Heute dran")
                Text("\(se.icon) \(se.name)").font(.sport(36)).textCase(.uppercase)
                Text("\(se.label) · \(store.exercises(of: t, short: tired).count) Übungen · ca. \(store.minutes(t, short: tired)) min")
                    .foregroundStyle(.white.opacity(0.85))
                if tired { Text("Tagesform niedrig – kurze Variante empfohlen").font(.footnote).foregroundStyle(.orange) }
                HStack(spacing: 10) {
                    Button(done ? "Nochmal" : (tired ? "Starten (kurz)" : "Starten")) { store.start(t, short: tired || store.s.shortMode) }
                        .buttonStyle(LimeButton())
                    Button("Details") { preview = Sel(id: t) }.buttonStyle(LimeButton(secondary: true)).frame(width: 120)
                }
                .padding(.top, 10)
            } else {
                kicker("Ruhetag")
                Text("🛌 Erholung").font(.sport(36)).textCase(.uppercase)
                Text(nextText).foregroundStyle(.white.opacity(0.85))
                Button("Lockeres Dehnen") { store.start("mob", short: true) }.buttonStyle(LimeButton()).padding(.top, 10)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(white: 0.17), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(RadialGradient(colors: [heroColor.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 140))
                    .frame(width: 280, height: 280).offset(x: 90, y: -110)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.line))
    }

    private var heroColor: Color {
        if let t = store.plan(for: store.todayIndex), let se = store.catalog.session(t) { return Color(hex: se.colors[0]) }
        return .lime
    }
    private var nextText: String {
        for k in 1..<7 {
            let d = (store.todayIndex + k) % 7
            if let p = store.plan(for: d), p != "game", let se = store.catalog.session(p) {
                return "Nächste Einheit: \(DateUtil.weekdays[d]) · \(se.name)"
            }
        }
        return "Keine Einheit geplant"
    }
    private func kicker(_ t: String) -> some View {
        Text(t.uppercased()).font(.caption.weight(.heavy)).tracking(0.8).foregroundStyle(Color.lime)
    }
}

struct GoalCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 14) {
            Text(store.goal?.icon ?? "🎯").font(.system(size: 24))
                .frame(width: 46, height: 46).background(Color.lime.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                if let g = store.goal {
                    Text("Dein Ziel").font(.caption).foregroundStyle(Color.mut)
                    Text(g.name).font(.headline)
                    let tests = store.s.tests.filter { $0.test == g.test }
                    let td = store.catalog.test(g.test)
                    Text("\(store.adherence) % der Einheiten (4 Wochen) · \(td?.name ?? ""): \(tests.last.map { fmtKg($0.value) + " " + (td?.unit ?? "") } ?? "noch kein Test")")
                        .font(.caption).foregroundStyle(Color.mut)
                    ProgressView(value: Double(store.adherence), total: 100).tint(.lime)
                } else {
                    Text("Ziel festlegen").font(.headline)
                    Text("Dein Plan passt sich daran an").font(.caption).foregroundStyle(Color.mut)
                }
            }
            Image(systemName: "chevron.right").foregroundStyle(Color.mut)
        }
        .card()
        .contentShape(Rectangle())
    }
}

struct HealthCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack {
            stat("Schritte heute", "\(Int(store.steps))", "figure.walk")
            Divider().overlay(Color.line)
            stat("Gewicht", store.weight.map { fmtKg(($0 * 10).rounded() / 10) + " kg" } ?? "–", "scalemass")
        }
        .card()
    }
    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(t, systemImage: icon).font(.caption).foregroundStyle(Color.mut)
            Text(v).font(.sport(30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReadinessCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let r = store.todayReadiness
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TAGESFORM").font(.footnote).foregroundStyle(Color.mut)
                Spacer()
                if let sc = r.score { Text(sc >= 3.7 ? "🟢 Top" : sc >= 2.7 ? "🟡 Normal" : "🔴 Müde").font(.footnote) }
            }
            line("😴 Schlaf", r.sleep, \.sleep)
            line("🦵 Beine frisch", r.legs, \.legs)
            line("⚡️ Energie", r.energy, \.energy)
        }
        .card()
    }
    private func line(_ label: String, _ value: Int?, _ key: WritableKeyPath<Readiness, Int?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { v in
                    Button { store.setReadiness(key, v); Haptics.tap() } label: {
                        Text("\(v)").font(.subheadline.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(value == v ? Color.black : .white)
                            .background(value == v ? Color.lime : Color.card2, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WeekCard: View {
    @EnvironmentObject var store: Store
    @Binding var preview: Sel?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DIESE WOCHE").font(.footnote).foregroundStyle(Color.mut)
                Spacer()
                Text("Woche \(store.weekIndex + 1) · \(store.blockWeek.name)").font(.footnote).foregroundStyle(Color.mut)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let t = store.plan(for: i)
                    Button { if let t, t != "game" { preview = Sel(id: t) } } label: {
                        HStack(spacing: 12) {
                            if t == "game" {
                                Text("⚽️").frame(width: 34, height: 34).background(Color.orange, in: RoundedRectangle(cornerRadius: 9))
                            } else if let t {
                                SessionIcon(session: store.catalog.session(t))
                            } else {
                                RoundedRectangle(cornerRadius: 9).fill(Color.card2).frame(width: 34, height: 34)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateUtil.weekdays[i] + (i == store.todayIndex ? " · Heute" : ""))
                                    .fontWeight(i == store.todayIndex ? .bold : .medium)
                                Text(t == "game" ? "Spiel" : t.flatMap { store.catalog.session($0) }.map { "\($0.name) · \($0.label)" } ?? "Ruhetag / Verein")
                                    .font(.subheadline).foregroundStyle(Color.mut)
                            }
                            Spacer()
                            if let t, t != "game" {
                                if store.done(t, on: i) { Image(systemName: "checkmark").foregroundStyle(Color.lime).fontWeight(.bold) }
                                else { Image(systemName: "chevron.right").foregroundStyle(Color.mut) }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < 6 { Divider().overlay(Color.line).padding(.leading, 62) }
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
