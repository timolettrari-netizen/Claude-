import SwiftUI
import Charts

struct ExercisesView: View {
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ExerciseList(search: search) { e in
                NavigationLink(value: e.id) {
                    ExerciseRow(exercise: e)
                }
            }
            .searchable(text: $search, prompt: "Übung suchen")
            .appBackground()
            .navigationTitle("Übungen")
            .navigationDestination(for: String.self) { id in
                ExerciseDetailView(exerciseID: id)
            }
        }
    }
}

/// Liste aller Übungen, gruppiert nach Muskel.
struct ExerciseList<Row: View>: View {
    let search: String
    @ViewBuilder let row: (Exercise) -> Row

    var body: some View {
        List {
            ForEach(Muscle.allCases) { muscle in
                let items = filtered.filter { $0.muscle == muscle }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { e in
                            row(e)
                                .listRowBackground(Rectangle().fill(.thinMaterial))
                        }
                    } header: {
                        HStack(spacing: 6) {
                            MuscleDot(muscle: muscle, size: 8)
                            Text(muscle.title)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var filtered: [Exercise] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return ExerciseLibrary.all }
        return ExerciseLibrary.all.filter {
            $0.name.lowercased().contains(q)
                || $0.muscle.title.lowercased().contains(q)
                || $0.gear.title.lowercased().contains(q)
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(exercise.muscle.color)
                .frame(width: 34, height: 34)
                .background(exercise.muscle.color.opacity(0.15), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.subheadline.weight(.semibold))
                Text("\(exercise.gear.title)\(exercise.compound ? " · Grundübung" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch exercise.gear {
        case .barbell, .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.connector"
        case .bodyweight: return "figure.core.training"
        case .bar: return "figure.play"
        }
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            ExerciseList(search: search) { e in
                Button {
                    onPick(e.id)
                    dismiss()
                } label: {
                    ExerciseRow(exercise: e)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Übung suchen")
            .appBackground()
            .navigationTitle("Übung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

struct ExerciseDetailView: View {
    @Environment(Store.self) private var store
    let exerciseID: String

    var body: some View {
        Group {
            if let e = ExerciseLibrary.exercise(exerciseID) {
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Badge(text: e.muscle.title, tint: e.muscle.color)
                                Badge(text: e.gear.title, icon: "dumbbell.fill", tint: .blue)
                            }
                            HStack(spacing: 8) {
                                Badge(text: levelText(e.level), icon: "chart.bar.fill", tint: .purple)
                                if e.compound { Badge(text: "Grundübung", icon: "star.fill", tint: Theme.accent) }
                            }
                            if !e.avoid.isEmpty {
                                Label("Vorsicht bei Beschwerden: \(e.avoid.map(\.title).sorted().joined(separator: ", "))",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ausführung").font(.headline)
                            ForEach(Array(e.cues.enumerated()), id: \.offset) { i, cue in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Theme.accent.gradient, in: Circle())
                                    Text(cue).font(.subheadline)
                                }
                            }
                        }
                        .glassCard()

                        progressCard(e)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle(e.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Übung nicht gefunden", systemImage: "questionmark")
            }
        }
        .appBackground()
    }

    @ViewBuilder
    private func progressCard(_ e: Exercise) -> some View {
        let points = store.history(for: e.id)
        VStack(alignment: .leading, spacing: 10) {
            Text("Dein Fortschritt").font(.headline)
            if points.isEmpty {
                Text("Noch nicht trainiert. Füge die Übung einem Trainingstag hinzu oder nutze sie im freien Training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let usesWeight = points.contains { $0.maxWeight > 0 }
                Sparkline(values: points.map { usesWeight ? $0.e1rm : Double($0.maxReps) })
                    .frame(height: 70)
                if let text = store.lastText(for: e.id) {
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
                NavigationLink {
                    ExerciseProgressView(exerciseID: e.id)
                } label: {
                    Label("Alle Daten ansehen", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .glassCard()
    }

    private func levelText(_ level: Int) -> String {
        switch level {
        case 0: return "Einsteiger"
        case 1: return "Fortgeschritten"
        default: return "Profi"
        }
    }
}
