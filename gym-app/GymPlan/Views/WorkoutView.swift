import SwiftUI
import UIKit

/// Laufendes Training: Gewicht und Wiederholungen je Satz eintragen, Pausen-Timer, Abschluss mit Bestleistungen.
struct WorkoutView: View {
    @Environment(Store.self) private var store
    @State private var summary: WorkoutLog?
    @State private var showFinish = false
    @State private var showAdd = false
    @State private var restDone = 0
    @State private var checkTick = 0
    @FocusState private var focus: String?

    var body: some View {
        NavigationStack {
            Group {
                if let summary {
                    SummaryView(log: summary) { store.showWorkout = false }
                } else if store.active != nil {
                    content
                } else {
                    ContentUnavailableView("Kein laufendes Training", systemImage: "dumbbell")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Schließen") { store.showWorkout = false }
                            }
                        }
                }
            }
            .appBackground()
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// Sichere Bindung an das laufende Training (bleibt gültig, auch wenn es gerade beendet wird).
    private var workout: Binding<ActiveWorkout> {
        Binding(
            get: { store.active ?? .placeholder },
            set: { newValue in
                if store.active != nil { store.active = newValue }
            }
        )
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                WorkoutHeader(workout: workout.wrappedValue)

                ForEach(workout.exercises) { $item in
                    ActiveExerciseCard(
                        item: $item,
                        lastText: store.lastText(for: item.exerciseID),
                        focus: $focus,
                        onToggle: { setID in
                            store.toggleSet(exercise: item.id, set: setID)
                            checkTick += 1
                        },
                        onRemove: { store.removeFromActive(item.id) }
                    )
                }

                Button {
                    showAdd = true
                } label: {
                    Label("Übung hinzufügen", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)

                Button {
                    showFinish = true
                } label: {
                    Label("Training beenden", systemImage: "flag.checkered")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { restBar }
        .navigationTitle(workout.wrappedValue.dayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.showWorkout = false
                } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel("Minimieren")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { showFinish = true }
                    .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { focus = nil }
            }
        }
        .confirmationDialog("Training beenden?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Speichern") {
                focus = nil
                if let log = store.finishWorkout() {
                    summary = log
                } else {
                    store.showWorkout = false
                }
            }
            Button("Verwerfen", role: .destructive) {
                store.discardWorkout()
                store.showWorkout = false
            }
            Button("Weiter trainieren", role: .cancel) {}
        } message: {
            Text("\(workout.wrappedValue.doneSets) von \(workout.wrappedValue.totalSets) Sätzen erledigt.")
        }
        .sheet(isPresented: $showAdd) {
            ExercisePickerSheet { id in store.addExerciseToActive(id) }
        }
        .task(id: store.active?.restEnd) {
            await waitForRestEnd()
        }
        .sensoryFeedback(.success, trigger: restDone)
        .sensoryFeedback(.impact(weight: .medium), trigger: checkTick)
        .onChange(of: store.active) {
            store.save()
        }
    }

    @ViewBuilder
    private var restBar: some View {
        if let active = store.active, let start = active.restStart, let end = active.restEnd, end > start {
            RestBar(start: start, end: end,
                    onAdjust: { store.adjustRest(by: $0) },
                    onSkip: { store.skipRest() })
                .padding(.horizontal)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func waitForRestEnd() async {
        guard let end = store.active?.restEnd else { return }
        let seconds = end.timeIntervalSinceNow
        if seconds > 0 {
            try? await Task.sleep(for: .seconds(seconds))
        }
        guard !Task.isCancelled, store.active?.restEnd == end else { return }
        withAnimation {
            store.active?.restStart = nil
            store.active?.restEnd = nil
        }
        restDone += 1
    }
}

// MARK: - Kopf

private struct WorkoutHeader: View {
    let workout: ActiveWorkout

    var body: some View {
        let progress = workout.totalSets > 0 ? Double(workout.doneSets) / Double(workout.totalSets) : 0
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.start, style: .timer)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(workout.doneSets) von \(workout.totalSets) Sätzen · \(Fmt.volume(currentVolume))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .glassCard(padding: 16, radius: 28)
    }

    private var currentVolume: Double {
        workout.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter(\.done).reduce(0.0) { sum, s in
                sum + (Fmt.parse(s.weight) ?? 0) * Double(Int(s.reps) ?? 0)
            }
        }
    }
}

// MARK: - Übungskarte

private struct ActiveExerciseCard: View {
    @Binding var item: ActiveExercise
    let lastText: String?
    var focus: FocusState<String?>.Binding
    let onToggle: (UUID) -> Void
    let onRemove: () -> Void

    @State private var showInfo = false

    var body: some View {
        let info = ExerciseLibrary.exercise(item.exerciseID)
        let timed = info?.timed ?? false
        let allDone = !item.sets.isEmpty && item.sets.allSatisfy(\.done)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let info { MuscleDot(muscle: info.muscle) }
                        Text(info?.name ?? item.exerciseID)
                            .font(.headline)
                            .strikethrough(allDone, color: .secondary)
                    }
                    Text("\(item.sets.count) × \(item.repLow)–\(item.repHigh) \(info?.repUnit ?? "Wdh.") · \(item.rest) s Pause")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Ausführung", systemImage: "info.circle") { showInfo = true }
                    Button("Satz hinzufügen", systemImage: "plus") { addSet() }
                    if item.sets.count > 1 {
                        Button("Letzten Satz entfernen", systemImage: "minus") { item.sets.removeLast() }
                    }
                    Divider()
                    Button("Übung entfernen", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .glassEffect(Glass.make(interactive: true), in: .circle)
                }
            }

            if let lastText {
                Label(lastText, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = item.note {
                Label(note, systemImage: note.hasPrefix("↑") ? "arrow.up.circle.fill" : "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(note.hasPrefix("↑") ? Color.green : Theme.accent)
            }

            VStack(spacing: 8) {
                ForEach($item.sets) { $set in
                    SetRow(set: $set,
                           number: (item.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                           timed: timed,
                           focus: focus,
                           onToggle: { onToggle(set.id) })
                }
            }

            Button {
                addSet()
            } label: {
                Label("Satz", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .glassCard(padding: 16, radius: 26, tint: allDone ? Color.green.opacity(0.18) : nil)
        .sheet(isPresented: $showInfo) {
            if let info {
                NavigationStack {
                    ExerciseDetailView(exerciseID: info.id)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func addSet() {
        let last = item.sets.last
        var new = ActiveSet(weight: last?.weight ?? "", reps: "",
                            hintWeight: last?.hintWeight ?? "", hintReps: last?.hintReps ?? "\(item.repLow)")
        new.done = false
        item.sets.append(new)
    }
}

private struct SetRow: View {
    @Binding var set: ActiveSet
    let number: Int
    let timed: Bool
    var focus: FocusState<String?>.Binding
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 30, height: 30)
                .foregroundStyle(set.done ? Color.white : Color.primary)
                .background(set.done ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Circle())

            if !timed {
                field(text: $set.weight, hint: set.hintWeight, placeholder: "kg", unit: "kg",
                      key: "\(set.id.uuidString)-w", keyboard: .decimalPad)
                Text("×").foregroundStyle(.secondary)
            }
            field(text: $set.reps, hint: set.hintReps, placeholder: timed ? "Sek." : "Wdh.", unit: timed ? "s" : "Wdh.",
                  key: "\(set.id.uuidString)-r", keyboard: .numberPad)

            Button(action: onToggle) {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(set.done ? Theme.accent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.done ? "Satz erledigt" : "Satz abhaken")
        }
    }

    private func field(text: Binding<String>, hint: String, placeholder: String, unit: String,
                       key: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 4) {
            TextField(hint.isEmpty ? placeholder : hint, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit().weight(.semibold))
                .focused(focus, equals: key)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(set.done ? 0.04 : 0.07), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Pausen-Timer

private struct RestBar: View {
    let start: Date
    let end: Date
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Pause", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(timerInterval: start...end, countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }
            ProgressView(timerInterval: start...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Theme.accent)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button("−15 s") { onAdjust(-15) }
                        .buttonStyle(.glass)
                    Button("+15 s") { onAdjust(15) }
                        .buttonStyle(.glass)
                    Spacer()
                    Button("Überspringen") { onSkip() }
                        .buttonStyle(.glassProminent)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

// MARK: - Zusammenfassung

private struct SummaryView: View {
    let log: WorkoutLog
    let onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: log.prs.isEmpty ? "checkmark.seal.fill" : "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(log.prs.isEmpty ? Theme.accent : Color.yellow)
                    .symbolEffect(.bounce, value: appeared)
                    .padding(.top, 30)

                VStack(spacing: 4) {
                    Text("Stark gemacht!").font(.largeTitle.bold())
                    Text(log.dayName).foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    StatTile(value: Fmt.duration(log.duration), label: "Dauer", icon: "clock.fill")
                    StatTile(value: "\(log.setCount)", label: "Sätze", icon: "list.number", tint: .blue)
                    StatTile(value: Fmt.volume(log.volume), label: "Volumen", icon: "scalemass.fill", tint: .purple)
                }

                if !log.prs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Neue Bestleistungen", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                        ForEach(log.prs, id: \.self) { id in
                            HStack {
                                Text(ExerciseLibrary.name(id)).font(.subheadline.weight(.semibold))
                                Spacer()
                                if let best = log.exercises.first(where: { $0.exerciseID == id })?.sets.max(by: { Store.score($0) < Store.score($1) }) {
                                    Text(best.weight > 0 ? "\(Fmt.kg(best.weight)) kg × \(best.reps)" : "\(best.reps) Wdh.")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .glassCard(tint: Color.yellow.opacity(0.15))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Übungen").font(.headline)
                    ForEach(log.exercises) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ExerciseLibrary.name(e.exerciseID)).font(.subheadline.weight(.semibold))
                            Text(e.sets.map { $0.weight > 0 ? "\(Fmt.kg($0.weight))×\($0.reps)" : "\($0.reps)" }.joined(separator: "  ·  "))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .glassCard()

                Button(action: onClose) {
                    Text("Fertig")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .navigationTitle("Zusammenfassung")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }
}
