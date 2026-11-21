import SwiftUI

struct PlanView: View {
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let plan = store.plan {
                        PlanHeader(plan: plan)
                        SectionTitle(text: "Trainingstage", trailing: "\(plan.days.count) pro Woche")
                        ForEach(plan.days) { day in
                            NavigationLink(value: day.id) {
                                PlanDayCard(day: day)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Tippe auf einen Tag, um Übungen zu tauschen, Sätze anzupassen oder Übungen hinzuzufügen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        ContentUnavailableView {
                            Label("Kein Plan", systemImage: "calendar.badge.plus")
                        } description: {
                            Text("Erstelle deinen persönlichen Trainingsplan in weniger als einer Minute.")
                        } actions: {
                            Button("Plan erstellen") { store.showGenerator = true }
                                .buttonStyle(.glassProminent)
                        }
                        .glassCard(radius: 30)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Plan")
            .navigationDestination(for: UUID.self) { id in
                PlanDayView(dayID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Neu erstellen", systemImage: "wand.and.stars") {
                        store.showGenerator = true
                    }
                }
            }
        }
    }
}

private struct PlanHeader: View {
    @Environment(Store.self) private var store
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: plan.settings.goal.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .glassEffect(Glass.make(tint: Theme.accent), in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).font(.title2.bold())
                    Text(plan.split).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if plan.settings.weeks > 0 {
                let week = min(store.currentWeek, plan.settings.weeks)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Woche \(week) von \(plan.settings.weeks)").font(.subheadline.weight(.semibold))
                        Spacer()
                        if store.isDeloadWeek { Badge(text: "Entlastung", icon: "leaf.fill", tint: .green) }
                    }
                    ProgressView(value: Double(week), total: Double(plan.settings.weeks))
                        .tint(Theme.accent)
                }
            }

            FlowRow(items: tags)
        }
        .glassCard(padding: 18, radius: 30)
    }

    private var tags: [String] {
        var t = [plan.settings.level.title, "\(plan.settings.minutes) Min", plan.settings.equipment.title]
        if plan.settings.focus != .balanced { t.append(plan.settings.focus.title) }
        t += plan.settings.limitations.map { "Schont \($0.title)" }
        return t
    }
}

/// Einfache Zeile mit Etiketten, die bei Bedarf umbricht.
struct FlowRow: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct PlanDayCard: View {
    let day: PlanDay

    var body: some View {
        HStack(spacing: 14) {
            Text(day.weekday.map { Fmt.weekdayName($0, short: true) } ?? "–")
                .font(.headline)
                .frame(width: 48, height: 48)
                .glassEffect(Glass.make(tint: Theme.accent.opacity(0.35)), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(day.name).font(.headline)
                Text("\(day.exercises.count) Übungen · ca. \(PlanGenerator.minutes(of: day)) Min")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(muscles, id: \.self) { m in MuscleDot(muscle: m, size: 8) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .glassCard(padding: 14, radius: 24, interactive: true)
    }

    private var muscles: [Muscle] {
        var seen: [Muscle] = []
        for item in day.exercises {
            if let m = ExerciseLibrary.exercise(item.exerciseID)?.muscle, !seen.contains(m) { seen.append(m) }
        }
        return seen
    }
}

// MARK: - Tag bearbeiten

struct PlanDayView: View {
    @Environment(Store.self) private var store
    let dayID: UUID

    @State private var swapItem: PlanExercise?
    @State private var showAdd = false

    var body: some View {
        Group {
            if let day = store.planDay(dayID) {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            if let wd = day.weekday { Badge(text: Fmt.weekdayName(wd), icon: "calendar") }
                            Badge(text: day.kind, icon: "figure.strengthtraining.traditional", tint: .blue)
                            Spacer()
                            Text("ca. \(PlanGenerator.minutes(of: day)) Min").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                            PlanItemRow(index: index, item: item, isFirst: index == 0,
                                        isLast: index == day.exercises.count - 1, dayID: dayID,
                                        onSwap: { swapItem = item })
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
                            store.startWorkout(day)
                        } label: {
                            Label(store.active == nil ? "Dieses Training starten" : "Laufendes Training öffnen",
                                  systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle(day.name)
            } else {
                ContentUnavailableView("Tag nicht gefunden", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .appBackground()
        .sheet(item: $swapItem) { item in
            SwapSheet(item: item) { newID in
                store.swapExercise(dayID: dayID, itemID: item.id, to: newID)
            }
        }
        .sheet(isPresented: $showAdd) {
            ExercisePickerSheet { id in
                store.addExercise(dayID: dayID, exerciseID: id)
            }
        }
    }
}

private struct PlanItemRow: View {
    @Environment(Store.self) private var store
    let index: Int
    let item: PlanExercise
    let isFirst: Bool
    let isLast: Bool
    let dayID: UUID
    let onSwap: () -> Void

    var body: some View {
        let info = ExerciseLibrary.exercise(item.exerciseID)
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.bold())
                .frame(width: 30, height: 30)
                .background((info?.muscle.color ?? .gray).opacity(0.25), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(info?.name ?? item.exerciseID).font(.headline).lineLimit(2)
                Text("\(item.sets) Sätze × \(item.repLow)–\(item.repHigh) \(info?.repUnit ?? "Wdh.") · \(item.rest) s Pause")
                    .font(.caption).foregroundStyle(.secondary)
                if let info {
                    Text("\(info.muscle.title) · \(info.gear.title)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Menu {
                Button("Übung tauschen", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                Button("Satz hinzufügen", systemImage: "plus") { store.changeSets(dayID: dayID, itemID: item.id, by: 1) }
                Button("Satz entfernen", systemImage: "minus") { store.changeSets(dayID: dayID, itemID: item.id, by: -1) }
                if !isFirst {
                    Button("Nach oben", systemImage: "arrow.up") { store.moveExercise(dayID: dayID, itemID: item.id, up: true) }
                }
                if !isLast {
                    Button("Nach unten", systemImage: "arrow.down") { store.moveExercise(dayID: dayID, itemID: item.id, up: false) }
                }
                Divider()
                Button("Entfernen", systemImage: "trash", role: .destructive) {
                    store.removeExercise(dayID: dayID, itemID: item.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .glassEffect(Glass.make(interactive: true), in: .circle)
            }
        }
        .glassCard(padding: 14, radius: 22)
    }
}

private struct SwapSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: PlanExercise
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Aktuell: \(ExerciseLibrary.name(item.exerciseID))")
                        .foregroundStyle(.secondary)
                }
                Section("Alternativen") {
                    ForEach(PlanGenerator.alternatives(for: item.exerciseID, settings: store.plan?.settings)) { e in
                        Button {
                            onPick(e.id)
                            dismiss()
                        } label: {
                            ExerciseRow(exercise: e)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Übung tauschen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
