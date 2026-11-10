import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var store: Store
    @State private var preview: Sel?
    @State private var detail: Sel?
    @State private var query = ""
    @State private var category = "Alle"
    @State private var showFree = false

    private var library: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.catalog.exercises.keys.filter { id in
            let cat = store.category(id)
            if store.s.place == "home" && (cat == "Gym" || ["thrust", "lpull", "add", "legp"].contains(id)) { return false }
            if category != "Alle" && cat != category { return false }
            if !q.isEmpty && !(store.name(id) + " " + store.equipment(id)).lowercased().contains(q) { return false }
            return true
        }
        .sorted { store.name($0).localizedCompare(store.name($1)) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Training").font(.sport(40)).textCase(.uppercase).padding(.top, 8)
                    Picker("Länge", selection: $store.s.shortMode) {
                        Text("Normal").tag(false)
                        Text("Kurz (~60 %)").tag(true)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(store.catalog.sessions) { se in
                            Button { preview = Sel(id: se.id) } label: { SessionTile(session: se) }.buttonStyle(.plain)
                        }
                    }

                    Button { showFree = true } label: {
                        Label("Freies Training", systemImage: "figure.run.circle.fill")
                    }
                    .buttonStyle(LimeButton())

                    RunPlanCard().padding(.top, 6)

                    Text("Übungen").sectionTitle().padding(.top, 10)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.mut)
                        TextField("Suchen", text: $query).textInputAutocapitalization(.never)
                    }
                    .padding(10).background(Color.card2, in: RoundedRectangle(cornerRadius: 10))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Catalog.categories, id: \.self) { c in
                                Button(c) { category = c; Haptics.tap() }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .foregroundStyle(category == c ? Color.black : .white)
                                    .background(category == c ? Color.lime : Color.card, in: Capsule())
                            }
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(library, id: \.self) { id in
                            Button { detail = Sel(id: id) } label: {
                                HStack(spacing: 12) {
                                    Thumb(id: id)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.name(id)).foregroundStyle(.white)
                                        Text("\(store.category(id)) · \(store.equipment(id))").font(.footnote).foregroundStyle(Color.mut).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Color.mut)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.line).padding(.leading, 80)
                        }
                    }
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(16)
            }
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $preview) { s in SessionPreview(session: s.id).environmentObject(store) }
            .sheet(item: $detail) { s in ExerciseDetailView(id: s.id).environmentObject(store) }
            .sheet(isPresented: $showFree) { FreeTrainingSheet().environmentObject(store) }
        }
    }
}

struct SessionTile: View {
    @EnvironmentObject var store: Store
    let session: SessionType
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.icon).font(.system(size: 26))
            Spacer(minLength: 18)
            Text(session.name).font(.sport(22)).textCase(.uppercase).foregroundStyle(.white)
            Text("\(session.label) · \(store.minutes(session.id, short: store.s.shortMode)) min")
                .font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(LinearGradient(colors: session.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SessionPreview: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let session: String
    @State private var detail: Sel?

    var body: some View {
        let short = store.s.shortMode || (store.isTired && store.plan(for: store.todayIndex) == session)
        let se = store.catalog.session(session)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Pill(text: "\(store.exercises(of: session, short: short).count) Übungen", highlight: true)
                        Pill(text: "ca. \(store.minutes(session, short: short)) min")
                        Pill(text: store.s.place == "gym" ? "🏋️ Studio" : "🏠 Zuhause")
                        if short { Pill(text: "Kurz") }
                    }
                    Text(se?.info ?? "").foregroundStyle(Color.mut)
                    VStack(spacing: 0) {
                        ForEach(store.exercises(of: session, short: short), id: \.self) { id in
                            Button { detail = Sel(id: id) } label: {
                                HStack(spacing: 12) {
                                    Thumb(id: id)
                                    VStack(alignment: .leading) {
                                        Text(store.name(id)).foregroundStyle(.white)
                                        Text(store.dose(id, short: short).text).font(.footnote).foregroundStyle(Color.mut)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Color.mut)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button("Training starten") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.start(session, short: short) }
                    }
                    .buttonStyle(LimeButton())
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle("\(se?.icon ?? "") \(se?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } } }
            .sheet(item: $detail) { s in ExerciseDetailView(id: s.id, short: short).environmentObject(store) }
        }
    }
}

struct GoalPickerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let first: Bool
    @State private var pick: String?
    @State private var weeks = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(first ? "Was willst du verbessern? Plan, Übungen und Coach passen sich daran an. Du kannst den Plan jederzeit beenden."
                               : "Wähle Ziel und Dauer. Ein laufender Plan wird dabei beendet und im Verlauf gespeichert.")
                        .foregroundStyle(Color.mut)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(store.catalog.goals) { g in
                            Button { pick = g.id; Haptics.tap() } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(g.icon).font(.system(size: 26))
                                    Text(g.name).font(.headline).foregroundStyle(.white)
                                    Text(g.info).font(.caption).foregroundStyle(Color.mut).multilineTextAlignment(.leading)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                                .background(pick == g.id ? Color.lime.opacity(0.1) : Color.card, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(pick == g.id ? Color.lime : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Dauer").font(.subheadline)
                    Picker("Dauer", selection: $weeks) { ForEach([4, 8, 12, 0], id: \.self) { w in Text(w == 0 ? "Offen" : "\(w) Wo.").tag(w) } }
                        .pickerStyle(.segmented)
                    Text("Einheiten pro Woche").font(.subheadline)
                    Picker("Einheiten", selection: $store.s.days) { ForEach(2...5, id: \.self) { Text("\($0)").tag($0) } }
                        .pickerStyle(.segmented)
                    Text("Spieltag").font(.subheadline)
                    Picker("Spieltag", selection: $store.s.gameDay) {
                        Text("–").tag(-1)
                        ForEach(0..<7, id: \.self) { Text(DateUtil.weekdaysShort[$0]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button(buttonTitle) {
                        guard let pick else { return }
                        store.startProgram(goal: pick, weeks: weeks)
                        Haptics.success()
                        dismiss()
                    }
                    .buttonStyle(LimeButton())
                    .disabled(pick == nil)
                    .opacity(pick == nil ? 0.4 : 1)
                    if first {
                        Button("Erst mal ohne Plan") { dismiss() }.buttonStyle(LimeButton(secondary: true))
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle(first ? "Willkommen 👋" : "Plan wählen")
            .toolbar { if !first { ToolbarItem(placement: .topBarTrailing) { Button("Abbrechen") { dismiss() } } } }
            .onAppear {
                pick = pick ?? store.s.goal
                weeks = store.program?.weeks ?? 8
            }
        }
    }

    private var buttonTitle: String {
        guard let active = store.program else { return "Plan starten" }
        return active.goal.id == pick ? "Plan übernehmen" : "Aktuellen Plan beenden & neuen starten"
    }
}

/// Details zum laufenden Plan: ändern oder beenden
struct PlanSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false
    @State private var showPicker = false
    @State private var summary: ProgramRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let p = store.program {
                        HStack(spacing: 8) {
                            Pill(text: p.weekText, highlight: true)
                            Pill(text: "seit \(DateUtil.format(p.start, "dMMM"))")
                            Pill(text: "\(p.units) Einheiten")
                        }
                        Text(p.goal.info).foregroundStyle(Color.mut)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fortschritt").font(.caption).foregroundStyle(Color.mut)
                            ProgressView(value: p.progress).tint(.lime)
                            Text("\(p.adherence) % der geplanten Einheiten erledigt").font(.footnote)
                        }
                        .card()
                        Button("Plan ändern / anderes Ziel") { showPicker = true }.buttonStyle(LimeButton())
                        Button("Plan beenden") { confirmEnd = true }.buttonStyle(LimeButton(secondary: true)).foregroundStyle(.red)
                    } else {
                        Text("Kein aktiver Plan – du trainierst frei.").foregroundStyle(Color.mut)
                        Button("Plan wählen") { showPicker = true }.buttonStyle(LimeButton())
                    }
                    if !store.s.programs.isEmpty {
                        Text("Frühere Pläne").sectionTitle().padding(.top, 8)
                        VStack(spacing: 0) {
                            ForEach(store.s.programs.reversed()) { r in
                                let g = store.catalog.goal(r.goal)
                                HStack {
                                    Text(g?.icon ?? "🎯")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g?.name ?? r.goal)
                                        Text("\(DateUtil.format(r.start, "dMMMyy")) – \(DateUtil.format(r.end, "dMMMyy")) · \(r.units) Einheiten · \(r.adherence) %\(r.completed ? " · ✓ geschafft" : " · beendet")")
                                            .font(.caption).foregroundStyle(Color.mut)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 9)
                            }
                        }
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle(store.program.map { "\($0.goal.icon) \($0.goal.name)" } ?? "Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
            .confirmationDialog("Plan jetzt beenden? Deine Trainings bleiben gespeichert.", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("Plan beenden", role: .destructive) { summary = store.endProgram(completed: false) }
            }
            .sheet(isPresented: $showPicker) { GoalPickerView(first: false).environmentObject(store) }
            .sheet(item: $summary) { r in ProgramSummaryView(record: r).environmentObject(store) }
        }
    }
}

/// Bilanz nach dem Beenden oder Abschließen eines Plans
struct ProgramSummaryView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let record: ProgramRecord
    @State private var showPicker = false

    var body: some View {
        let g = store.catalog.goal(record.goal)
        let t = g.flatMap { store.catalog.test($0.test) }
        VStack(spacing: 16) {
            Text(record.completed ? "🏆" : "🏁").font(.system(size: 64)).padding(.top, 24)
            Text(record.completed ? "Plan geschafft!" : "Plan beendet").font(.sport(36)).textCase(.uppercase)
            Text("\(g?.icon ?? "") \(g?.name ?? record.goal)").foregroundStyle(Color.mut)
            HStack(spacing: 10) {
                box("\(max(1, DateUtil.days(from: record.start, to: record.end) / 7))", "Wochen")
                box("\(record.units)", "Einheiten")
                box("\(record.adherence) %", "erledigt")
            }
            if let from = record.testFrom, let to = record.testTo, let t {
                Text("\(t.name): \(fmtKg(from)) → \(fmtKg(to)) \(t.unit)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.lime)
                    .padding(12).frame(maxWidth: .infinity).background(Color.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Bis du einen neuen Plan startest, trainierst du frei – alle Einheiten findest du unter „Training“.")
                .font(.footnote).foregroundStyle(Color.mut).multilineTextAlignment(.center)
            Spacer()
            Button("Neuen Plan wählen") { showPicker = true }.buttonStyle(LimeButton())
            Button("Ohne Plan weiter") { dismiss() }.buttonStyle(LimeButton(secondary: true))
        }
        .padding(16)
        .background(Color.bg)
        .sheet(isPresented: $showPicker, onDismiss: { dismiss() }) { GoalPickerView(first: false).environmentObject(store) }
    }

    private func box(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(.sport(28)); Text(l).font(.caption).foregroundStyle(Color.mut) }
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
