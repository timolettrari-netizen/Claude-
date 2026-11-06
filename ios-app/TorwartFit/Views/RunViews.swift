import SwiftUI
import MapKit

/// Laufplan der Woche (im Reiter Training)
struct RunPlanCard: View {
    @EnvironmentObject var store: Store
    @State private var detail: PlannedRun?

    var body: some View {
        let plan = store.runPlan(weekOf: Date())
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Laufplan").sectionTitle()
                Text("Woche \(store.runWeekNumber(DateUtil.weekStart(Date()))) · \(String(format: "%.1f", store.runKmThisWeek).replacingOccurrences(of: ".", with: ",")) km")
                    .font(.caption).foregroundStyle(Color.mut)
            }
            VStack(spacing: 0) {
                if plan.isEmpty {
                    Text(store.s.runsPerWeek == 0 ? "Laufplan ist aus (Profil → Läufe pro Woche)." : "Diese Woche ist kein Lauf geplant.")
                        .font(.subheadline).foregroundStyle(Color.mut).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(plan) { r in
                    Button { detail = r } label: {
                        HStack(spacing: 12) {
                            Text("🏃").font(.system(size: 18)).frame(width: 34, height: 34)
                                .background(LinearGradient(colors: [Color(hex: "#FF375F"), Color(hex: "#D70F4A")], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(DateUtil.weekdays[DateUtil.dayIndex(r.date)]) · \(r.title)").foregroundStyle(.white)
                                Text("\(fmtKg(r.km)) km · ca. \(r.minutes) min · \(r.kcal) kcal").font(.footnote).foregroundStyle(Color.mut)
                            }
                            Spacer()
                            if store.runDone(on: r.date) { Image(systemName: "checkmark").foregroundStyle(Color.lime).fontWeight(.bold) }
                            else { Image(systemName: "chevron.right").foregroundStyle(Color.mut) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Button { store.startRun(nil) } label: { Label("Freien Lauf starten (GPS)", systemImage: "location.fill") }
                .buttonStyle(LimeButton(secondary: true))
        }
        .sheet(item: $detail) { r in RunDetailSheet(run: r).environmentObject(store).presentationDetents([.medium, .large]) }
    }
}

/// Lauf heute (auf „Heute“)
struct RunTodayCard: View {
    @EnvironmentObject var store: Store
    @State private var detail: PlannedRun?
    var body: some View {
        if let r = store.plannedRun(on: Date()) {
            let done = store.runDone(on: Date())
            HStack(spacing: 14) {
                Text("🏃").font(.system(size: 22)).frame(width: 46, height: 46)
                    .background(Color(hex: "#FF375F").opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "✓ Lauf erledigt" : "Heute laufen").font(.caption.weight(.heavy)).foregroundStyle(Color(hex: "#FF375F"))
                    Text(r.title).font(.headline)
                    Text("\(fmtKg(r.km)) km · ca. \(r.minutes) min").font(.caption).foregroundStyle(Color.mut)
                }
                Spacer()
                Button(done ? "Details" : "Start") { if done { detail = r } else { store.startRun(r) } }
                    .font(.subheadline.weight(.heavy)).foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.lime, in: Capsule())
            }
            .card()
            .onTapGesture { detail = r }
            .sheet(item: $detail) { r in RunDetailSheet(run: r).environmentObject(store).presentationDetents([.medium, .large]) }
        }
    }
}

struct RunDetailSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let run: PlannedRun
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Pill(text: "\(fmtKg(run.km)) km", highlight: true)
                        Pill(text: "ca. \(run.minutes) min")
                        Pill(text: "ca. \(run.kcal) kcal")
                    }
                    if !run.timeHint.isEmpty {
                        Text("Zeitfenster: \(run.timeHint)").font(.subheadline)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.card2, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(run.details.enumerated()), id: \.offset) { n, d in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(n + 1)").font(.footnote.weight(.bold)).foregroundStyle(.black)
                                    .frame(width: 24, height: 24).background(Color.lime, in: Circle())
                                Text(d).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .card()
                    Button("Lauf starten (GPS)") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.startRun(run) }
                    }
                    .buttonStyle(LimeButton())
                    Text("Tipp: Das Handy darf in die Tasche – die Strecke wird auch bei gesperrtem Bildschirm weiter aufgezeichnet.")
                        .font(.footnote).foregroundStyle(Color.mut)
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle(run.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } } }
        }
    }
}

/// GPS-Tracker während des Laufs
struct RunTrackerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let launch: RunLaunch
    @StateObject private var t = RunTracker()
    @State private var finished = false
    @State private var kmInput = ""
    @State private var confirmQuit = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { confirmQuit = true } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32)
                        .background(Color.card2, in: Circle())
                }
                Spacer()
                Text(launch.plan?.title ?? "Freier Lauf").font(.subheadline.weight(.semibold))
                Spacer()
                Text(gpsText).font(.caption).foregroundStyle(t.gps == .ok ? Color.lime : .orange)
            }
            .padding(.top, 8)
            if finished { summary } else { live }
        }
        .padding(.horizontal, 16)
        .background(Color.bg.ignoresSafeArea())
        .onAppear { t.begin(); UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { t.finish(); UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("Lauf abbrechen?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Abbrechen ohne Speichern", role: .destructive) { t.finish(); dismiss() }
            Button("Beenden und speichern") { finish() }
        }
    }

    private var gpsText: String {
        switch t.gps {
        case .ok: return "GPS aktiv"
        case .searching: return "GPS sucht …"
        case .denied: return "GPS nicht erlaubt"
        }
    }

    private var live: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(clock(t.elapsed)).font(.system(size: 84, weight: .heavy).width(.condensed).italic().monospacedDigit())
            Text(t.running ? "läuft" : "pausiert").font(.subheadline).foregroundStyle(Color.mut)
            HStack(spacing: 10) {
                stat(String(format: "%.2f", t.km).replacingOccurrences(of: ".", with: ","), "km")
                stat(t.paceMinPerKm.map { Store.pace($0) } ?? "–", "min/km")
                stat("\(kcal)", "kcal")
            }
            if let p = launch.plan {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(p.details, id: \.self) { Text("• " + $0).font(.footnote).foregroundStyle(Color.mut) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ProgressView(value: min(t.km, p.km), total: max(p.km, 0.1)).tint(.lime)
                Text("Ziel \(fmtKg(p.km)) km").font(.caption).foregroundStyle(Color.mut)
            }
            if t.gps == .denied {
                Text("Ortung ist aus. Erlaube sie unter Einstellungen → TorwartFit → Standort, oder trage die Strecke am Ende selbst ein.")
                    .font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(t.running ? "Pause" : "Weiter") { if t.running { t.pause() } else { t.resume() }; Haptics.tap() }
                    .buttonStyle(LimeButton(secondary: true))
                Button("Beenden") { finish() }.buttonStyle(LimeButton())
            }
            .padding(.bottom, 12)
        }
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Geschafft!").font(.sport(40)).textCase(.uppercase).padding(.top, 10)
                if t.route.count > 1 {
                    Map {
                        MapPolyline(coordinates: t.route).stroke(Color.lime, lineWidth: 5)
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                HStack(spacing: 10) {
                    stat("\(max(1, Int(t.elapsed / 60)))", "Minuten")
                    stat(String(format: "%.2f", t.km).replacingOccurrences(of: ".", with: ","), "km (GPS)")
                    stat("\(kcal)", "kcal")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Strecke in km (anpassen, falls das GPS gefehlt hat)").font(.footnote).foregroundStyle(Color.mut)
                    TextField("km", text: $kmInput).keyboardType(.decimalPad)
                        .padding(12).background(Color.card2, in: RoundedRectangle(cornerRadius: 10))
                }
                Button("Speichern") {
                    let km = Double(kmInput.replacingOccurrences(of: ",", with: ".")) ?? t.km
                    store.saveRun(plan: launch.plan, start: t.start, km: km, seconds: t.elapsed,
                                  route: t.route.map { RunCoordinate(lat: $0.latitude, lon: $0.longitude) })
                    Haptics.success()
                    dismiss()
                }
                .buttonStyle(LimeButton())
                Button("Verwerfen", role: .destructive) { dismiss() }.padding(.bottom, 20)
            }
        }
    }

    private var kcal: Int {
        let kg = store.currentKg
        return t.km > 0.2 ? Int(0.92 * kg * t.km) : Int(8.5 * kg * t.elapsed / 3600)
    }

    private func finish() {
        t.finish()
        kmInput = String(format: "%.2f", t.km).replacingOccurrences(of: ".", with: ",")
        finished = true
        Haptics.success()
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.sport(30))
            Text(l).font(.caption).foregroundStyle(Color.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t), h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s % 60) : String(format: "%d:%02d", m, s % 60)
    }
}
