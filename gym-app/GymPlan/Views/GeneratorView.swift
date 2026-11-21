import SwiftUI

/// Fragebogen, aus dem automatisch der Trainingsplan erstellt wird.
struct GeneratorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var goal: TrainingGoal = .muscle
    @State private var level: ExperienceLevel = .beginner
    @State private var weekdays: Set<Int> = [1, 3, 5]
    @State private var minutes = 60
    @State private var equipment: EquipmentSetup = .gym
    @State private var focus: TrainingFocus = .balanced
    @State private var limitations: Set<Limitation> = []
    @State private var weeks = 8
    @State private var didPrefill = false

    private static let minuteOptions = [30, 45, 60, 75, 90]
    private static let weekOptions = [4, 8, 12, 0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.plan == nil { intro }

                    card("Dein Ziel") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(TrainingGoal.allCases) { g in
                                OptionTile(icon: g.icon, title: g.title, subtitle: g.subtitle, selected: goal == g) { goal = g }
                            }
                        }
                    }

                    card("Erfahrung") {
                        Picker("Erfahrung", selection: $level) {
                            ForEach(ExperienceLevel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    card("Trainingstage", footer: daysFooter) {
                        GlassEffectContainer(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { day in
                                    weekdayButton(day)
                                }
                            }
                        }
                    }

                    card("Zeit pro Training") {
                        Picker("Minuten", selection: $minutes) {
                            ForEach(Self.minuteOptions, id: \.self) { Text("\($0) Min").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    card("Ausrüstung") {
                        VStack(spacing: 10) {
                            ForEach(EquipmentSetup.allCases) { e in
                                OptionTile(icon: e.icon, title: e.title, subtitle: e.subtitle, selected: equipment == e, wide: true) { equipment = e }
                            }
                        }
                    }

                    card("Schwerpunkt", footer: "Der Schwerpunkt bekommt zusätzliche Übungen und einen Satz mehr.") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(TrainingFocus.allCases) { f in
                                Chip(title: f.title, selected: focus == f) { focus = f }
                            }
                        }
                    }

                    card("Beschwerden", footer: "Übungen, die diese Bereiche stark belasten, werden durch schonendere ersetzt.") {
                        FlowLayout(spacing: 8) {
                            ForEach(Limitation.allCases) { l in
                                Chip(title: l.title, icon: limitations.contains(l) ? "checkmark" : nil,
                                     selected: limitations.contains(l)) {
                                    if limitations.contains(l) { limitations.remove(l) } else { limitations.insert(l) }
                                }
                            }
                        }
                    }

                    card("Plandauer", footer: "Jede 4. Woche ist eine leichtere Entlastungswoche.") {
                        Picker("Dauer", selection: $weeks) {
                            ForEach(Self.weekOptions, id: \.self) { w in
                                Text(w == 0 ? "Offen" : "\(w) Wochen").tag(w)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    preview

                    Button {
                        create()
                    } label: {
                        Label(store.plan == nil ? "Plan erstellen" : "Neuen Plan erstellen", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!isValid)

                    if store.plan != nil {
                        Text("Dein Trainingsverlauf bleibt erhalten – nur der Plan wird ersetzt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .appBackground()
            .navigationTitle(store.plan == nil ? "Willkommen" : "Neuer Plan")
            .toolbar {
                if store.plan != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(store.plan == nil)
        .onAppear(perform: prefill)
    }

    // MARK: Teile

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .glassEffect(Glass.make(tint: Theme.accent), in: .rect(cornerRadius: 20))
            Text("Dein persönlicher Plan").font(.title.bold())
            Text("Ein paar Angaben – daraus entsteht automatisch ein Trainingsplan mit Übungen, Sätzen, Wiederholungen und Pausen. Beim Training trägst du Gewicht und Wiederholungen ein und siehst deinen Fortschritt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var preview: some View {
        let settings = currentSettings
        let plan = PlanGenerator.make(settings)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Vorschau", systemImage: "eye").font(.headline)
            ForEach(plan.days) { day in
                HStack(alignment: .firstTextBaseline) {
                    Text(day.weekday.map { Fmt.weekdayName($0, short: true) } ?? "–")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name).font(.subheadline.weight(.semibold))
                        Text(day.exercises.map { ExerciseLibrary.name($0.exerciseID) }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("\(PlanGenerator.minutes(of: day))′").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
        .opacity(isValid ? 1 : 0.4)
    }

    private func card<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
            if let footer {
                Text(footer).font(.caption).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    private func weekdayButton(_ day: Int) -> some View {
        let selected = weekdays.contains(day)
        return Button {
            if selected {
                weekdays.remove(day)
            } else {
                weekdays.insert(day)
            }
        } label: {
            Text(Fmt.weekdayName(day, short: true))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(Glass.make(tint: selected ? Theme.accent : nil, interactive: true), in: .circle)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var daysFooter: String {
        let n = weekdays.count
        if n < 2 { return "Wähle mindestens 2 Tage." }
        if n > 6 { return "Maximal 6 Tage – mindestens ein Ruhetag pro Woche ist wichtig." }
        return "\(n) Tage · \(PlanGenerator.splitName(days: n, level: level))"
    }

    private var isValid: Bool { (2...6).contains(weekdays.count) }

    private var currentSettings: PlanSettings {
        PlanSettings(goal: goal, level: level, weekdays: weekdays.sorted(), minutes: minutes,
                     equipment: equipment, focus: focus, limitations: limitations, weeks: weeks)
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        guard let s = store.plan?.settings else { return }
        goal = s.goal
        level = s.level
        weekdays = Set(s.weekdays)
        minutes = s.minutes
        equipment = s.equipment
        focus = s.focus
        limitations = s.limitations
        weeks = s.weeks
    }

    private func create() {
        guard isValid else { return }
        store.createPlan(currentSettings)
        dismiss()
    }
}

private struct OptionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let selected: Bool
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if wide {
                    HStack(spacing: 12) {
                        iconView
                        texts
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? Color.white : Color.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        iconView
                        texts
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(Glass.make(tint: selected ? Theme.accent : nil, interactive: true), in: .rect(cornerRadius: 20))
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.title3)
            .frame(width: 28, height: 28)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.bold)).lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .opacity(0.75)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
