import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @Binding var tab: AppTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    if store.active != nil {
                        ResumeCard()
                    }

                    if store.plan == nil {
                        NoPlanCard()
                    } else {
                        if store.planFinished { PlanFinishedCard() }
                        if store.active == nil { NextWorkoutCard() }
                        WeekStrip()
                    }

                    HStack(spacing: 12) {
                        StatTile(value: weekValue, label: "Diese Woche", icon: "checkmark.circle.fill")
                        StatTile(value: "\(store.weekStreak)", label: "Wochen in Folge", icon: "flame.fill", tint: Theme.accent2)
                        StatTile(value: Fmt.volume(store.volumeThisWeek), label: "Volumen", icon: "scalemass.fill", tint: .blue)
                    }

                    if let last = store.logs.first {
                        SectionTitle(text: "Letztes Training")
                        Button { tab = .progress } label: {
                            WorkoutSummaryRow(log: last)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var weekValue: String {
        let planned = store.plan?.days.count ?? 0
        return planned > 0 ? "\(store.workoutsThisWeek)/\(planned)" : "\(store.workoutsThisWeek)"
    }
}

// MARK: - Karten

private struct ResumeCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let active = store.active {
            Button { store.showWorkout = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .glassEffect(Glass.make(tint: Theme.accent), in: .circle)
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Training läuft").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        Text(active.dayName).font(.headline)
                        Text("\(active.doneSets) von \(active.totalSets) Sätzen · seit \(Text(active.start, style: .timer))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .glassCard(interactive: true)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NoPlanCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
            Text("Noch kein Trainingsplan").font(.title2.bold())
            Text("Beantworte ein paar Fragen zu Ziel, Erfahrung, Zeit und Ausrüstung – die App erstellt dir automatisch einen passenden Plan.")
                .foregroundStyle(.secondary)
            Button {
                store.showGenerator = true
            } label: {
                Label("Plan erstellen", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            HStack {
                Spacer()
                Button("Ohne Plan trainieren") { store.startEmptyWorkout() }
                    .font(.subheadline)
                Spacer()
            }
        }
        .glassCard(padding: 20)
    }
}

private struct PlanFinishedCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.title).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan abgeschlossen!").font(.headline)
                Text("Zeit für einen neuen Block mit neuen Reizen.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Neu") { store.showGenerator = true }
                .buttonStyle(.glassProminent)
        }
        .glassCard()
    }
}

private struct NextWorkoutCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let next = store.nextSession(), let plan = store.plan {
            let isToday = Store.calendar.isDateInToday(next.date)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Badge(text: isToday ? "HEUTE" : Fmt.weekdayName(Store.weekdayIndex(next.date)).uppercased(),
                          icon: isToday ? "bolt.fill" : "calendar")
                    if store.isDeloadWeek {
                        Badge(text: "Entlastungswoche", icon: "leaf.fill", tint: .green)
                    }
                    Spacer()
                    Text(weekText(plan)).font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(next.day.name).font(.largeTitle.bold())
                    Text("\(next.day.exercises.count) Übungen · ca. \(PlanGenerator.minutes(of: next.day)) Min")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(next.day.exercises.prefix(5)) { item in
                        HStack(spacing: 10) {
                            if let e = ExerciseLibrary.exercise(item.exerciseID) { MuscleDot(muscle: e.muscle) }
                            Text(ExerciseLibrary.name(item.exerciseID)).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text("\(item.sets) × \(item.repLow)–\(item.repHigh)")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    if next.day.exercises.count > 5 {
                        Text("+ \(next.day.exercises.count - 5) weitere").font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        store.startWorkout(next.day)
                    } label: {
                        Label("Training starten", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)

                    Menu {
                        ForEach(plan.days) { day in
                            Button(day.name) { store.startWorkout(day) }
                        }
                        Divider()
                        Button("Freies Training", systemImage: "plus") { store.startEmptyWorkout() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .glassEffect(Glass.make(interactive: true), in: .circle)
                    }
                }
            }
            .glassCard(padding: 20, radius: 30)
        }
    }

    private func weekText(_ plan: TrainingPlan) -> String {
        plan.settings.weeks > 0 ? "Woche \(min(store.currentWeek, plan.settings.weeks)) von \(plan.settings.weeks)" : "Woche \(store.currentWeek)"
    }
}

private struct WeekStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        let cal = Store.calendar
        let start = Store.startOfWeek()
        let planned = Set(store.plan?.days.compactMap(\.weekday) ?? [])
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let date = cal.date(byAdding: .day, value: offset, to: start) ?? start
                let done = store.trained(on: date)
                let isToday = cal.isDateInToday(date)
                let isPlanned = planned.contains(offset + 1)
                VStack(spacing: 6) {
                    Text(Fmt.weekdayShort[offset])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isToday ? Theme.accent : .secondary)
                    ZStack {
                        Circle()
                            .fill(done ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Color.primary.opacity(isPlanned ? 0.10 : 0.0)))
                        Circle()
                            .strokeBorder(isToday ? Theme.accent : Color.primary.opacity(isPlanned ? 0.25 : 0.08),
                                          lineWidth: isToday ? 2 : 1)
                        if done {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        } else {
                            Text("\(cal.component(.day, from: date))").font(.caption.weight(.semibold))
                        }
                    }
                    .frame(width: 34, height: 34)
                    Circle()
                        .fill(isPlanned && !done ? Theme.accent : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard(padding: 14, radius: 24)
    }
}

struct WorkoutSummaryRow: View {
    let log: WorkoutLog

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(log.date.formatted(.dateTime.day())).font(.title3.bold())
                Text(log.date.formatted(.dateTime.month(.abbreviated))).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(log.dayName).font(.headline)
                    if !log.prs.isEmpty {
                        Badge(text: "\(log.prs.count) PR", icon: "trophy.fill", tint: .yellow)
                    }
                }
                Text("\(Fmt.duration(log.duration)) · \(log.setCount) Sätze · \(Fmt.volume(log.volume))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .glassCard(padding: 12, radius: 22, interactive: true)
    }
}
