import SwiftUI

/// Auswahl „Freies Training“: Lauf, Spaziergang, Intervalle, Rad, Torwart …
struct FreeTrainingSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showIntervals = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Was machst du heute? GPS-Aktivitäten zeichnen Strecke und Tempo auf, die anderen laufen mit Stoppuhr.")
                        .font(.subheadline).foregroundStyle(Color.mut)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(FreeActivity.allCases) { a in
                            Button {
                                Haptics.tap()
                                if a == .interval { showIntervals = true } else { start(a) }
                            } label: { tile(a) }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle("Freies Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } } }
            .navigationDestination(isPresented: $showIntervals) {
                IntervalListView { p in
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.startFree(.interval, program: p) }
                }
            }
        }
    }

    private func start(_ a: FreeActivity) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.startFree(a) }
    }

    private func tile(_ a: FreeActivity) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a.icon).font(.system(size: 28))
            Spacer(minLength: 14)
            Text(a.name).font(.sport(20)).textCase(.uppercase).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(a.info).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(LinearGradient(colors: a.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Vorlagen und eigene Intervalle
struct IntervalListView: View {
    @EnvironmentObject var store: Store
    let onStart: (IntervalProgram) -> Void
    @State private var editing: IntervalProgram?

    var body: some View {
        List {
            Section {
                Button { editing = IntervalProgram.blank } label: {
                    Label("Neues Intervall erstellen", systemImage: "plus.circle.fill").fontWeight(.semibold)
                }
                .listRowBackground(Color.card)
            }
            if !store.s.intervals.isEmpty {
                Section("Meine Intervalle") {
                    ForEach(store.s.intervals) { p in row(p, own: true) }
                        .onDelete { idx in store.s.intervals.remove(atOffsets: idx) }
                }
            }
            Section("Vorlagen") {
                ForEach(IntervalProgram.presets) { p in row(p, own: false) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Intervalle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { p in
            IntervalEditorView(program: p, onStart: { q in editing = nil; onStart(q) }).environmentObject(store)
        }
    }

    private func row(_ p: IntervalProgram, own: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).foregroundStyle(.white)
                Text("\(p.summary) · \(p.totalSeconds / 60) Min.").font(.caption).foregroundStyle(Color.mut).lineLimit(2)
            }
            Spacer()
            Button {
                // Vorlagen werden als Kopie bearbeitet
                editing = own ? p : IntervalProgram(name: p.name + " (eigene)", warmup: p.warmup, steps: p.steps.map {
                    IntervalStep(name: $0.name, seconds: $0.seconds, hard: $0.hard) }, repeats: p.repeats, cooldown: p.cooldown)
            } label: { Image(systemName: own ? "pencil" : "doc.on.doc").foregroundStyle(Color.mut) }
            .buttonStyle(.borderless)
            Button { onStart(p) } label: {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 34, height: 34).background(Color.lime, in: Circle())
            }
            .buttonStyle(.borderless)
        }
        .listRowBackground(Color.card)
    }
}

/// Intervalle selbst zusammenstellen
struct IntervalEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var program: IntervalProgram
    let onStart: (IntervalProgram) -> Void

    private var isOwn: Bool { store.s.intervals.contains { $0.id == program.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $program.name)
                    HStack {
                        Text("Gesamt")
                        Spacer()
                        Text("\(program.totalSeconds / 60) Min. · \(program.timeline.count) Abschnitte").foregroundStyle(Color.mut)
                    }
                }
                .listRowBackground(Color.card)

                Section("Einlaufen") {
                    DurationRow(title: "Dauer", seconds: $program.warmup, allowZero: true)
                }
                .listRowBackground(Color.card)

                Section {
                    ForEach($program.steps) { $st in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle().fill(st.hard ? Color.orange : Color.cyan).frame(width: 10, height: 10)
                                TextField("Bezeichnung", text: $st.name)
                                Picker("", selection: $st.hard) {
                                    Text("Belastung").tag(true)
                                    Text("Erholung").tag(false)
                                }
                                .pickerStyle(.segmented).frame(width: 190)
                            }
                            DurationRow(title: "Dauer", seconds: $st.seconds, allowZero: false)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { program.steps.remove(atOffsets: $0) }
                    .onMove { program.steps.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        let hard = !(program.steps.last?.hard ?? false)
                        program.steps.append(IntervalStep(name: hard ? "Schnell" : "Locker", seconds: hard ? 60 : 90, hard: hard))
                    } label: { Label("Abschnitt hinzufügen", systemImage: "plus") }
                    Stepper("Wiederholungen: \(program.repeats)×", value: $program.repeats, in: 1...40)
                } header: {
                    Text("Block (wird wiederholt)")
                } footer: {
                    Text("Wischen zum Löschen, „Bearbeiten“ zum Umsortieren. Beispiel: 30 s Schnell + 30 s Locker, 10×.")
                }
                .listRowBackground(Color.card)

                Section("Auslaufen") {
                    DurationRow(title: "Dauer", seconds: $program.cooldown, allowZero: true)
                }
                .listRowBackground(Color.card)

                Section {
                    Button("Speichern und starten") { save(); onStart(program) }
                        .fontWeight(.bold).foregroundStyle(Color.lime)
                        .disabled(program.steps.isEmpty)
                    Button("Nur speichern") { save(); dismiss() }.disabled(program.steps.isEmpty)
                    if isOwn {
                        Button("Intervall löschen", role: .destructive) { store.deleteInterval(program); dismiss() }
                    }
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle(isOwn ? "Intervall bearbeiten" : "Neues Intervall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func save() {
        if program.name.trimmingCharacters(in: .whitespaces).isEmpty { program.name = "Mein Intervall" }
        store.saveInterval(program)
        Haptics.success()
    }
}

/// Dauer in Minuten und Sekunden mit Plus/Minus (feinere Schritte bei kurzen Abschnitten)
struct DurationRow: View {
    let title: String
    @Binding var seconds: Int
    let allowZero: Bool

    private var step: Int { seconds < 120 ? 15 : seconds < 600 ? 30 : 60 }

    var body: some View {
        Stepper {
            HStack {
                Text(title)
                Spacer()
                Text(seconds == 0 ? "aus" : IntervalProgram.dur(seconds)).monospacedDigit().foregroundStyle(Color.mut)
            }
        } onIncrement: {
            seconds = min(3600, seconds + step)
        } onDecrement: {
            let s = seconds <= 120 ? 15 : seconds <= 600 ? 30 : 60
            seconds = max(allowZero ? 0 : 15, seconds - s)
        }
    }
}
