import SwiftUI

/// Gewichtsziel und Körperdaten. Daraus entstehen Kalorien- und Eiweißziel.
struct GoalView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BodyProfile()
    @State private var startText = ""
    @State private var goalText = ""
    @State private var loaded = false

    var body: some View {
        let numbers = store.goalNumbers(for: previewProfile)
        NavigationStack {
            Form {
                Section {
                    resultView(numbers)
                }
                .listRowBackground(Rectangle().fill(.thinMaterial))

                Section("Gewicht") {
                    HStack {
                        Text("Startgewicht")
                        Spacer()
                        TextField("kg", text: $startText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    DatePicker("Start am", selection: $draft.startDate, in: ...Date.now, displayedComponents: .date)
                    HStack {
                        Text("Zielgewicht")
                        Spacer()
                        TextField("kg", text: $goalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    DatePicker("Ziel erreichen bis", selection: $draft.goalDate, in: Date.now..., displayedComponents: .date)
                    if let last = store.bodyWeights.last {
                        LabeledContent("Aktuell (\(last.date.formatted(.dateTime.day().month())))", value: "\(Fmt.kg(last.kg)) kg")
                    }
                }
                .listRowBackground(Rectangle().fill(.thinMaterial))

                Section("Über dich") {
                    Picker("Geschlecht", selection: $draft.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Größe: \(Int(draft.heightCm)) cm", value: $draft.heightCm, in: 140...220, step: 1)
                    Stepper("Alter: \(draft.age) Jahre", value: $draft.age, in: 14...90)
                    Picker("Alltag", selection: $draft.activity) {
                        ForEach(ActivityLevel.allCases) { a in
                            VStack(alignment: .leading) {
                                Text(a.title)
                                Text(a.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(a)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                .listRowBackground(Rectangle().fill(.thinMaterial))

                Section {
                    Toggle("Automatisch nachregeln", isOn: $draft.autoCalories)
                    Stepper(value: $draft.calorieAdjust, in: -500...500, step: 50) {
                        HStack {
                            Text("Feinjustierung")
                            Spacer()
                            Text(draft.calorieAdjust == 0 ? "±0" : "\(draft.calorieAdjust > 0 ? "+" : "")\(draft.calorieAdjust) kcal")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Kalorien")
                } footer: {
                    Text("Die Automatik vergleicht jeden Montag dein tatsächliches Tempo der letzten 4 Wochen mit dem Plan und gleicht die Hälfte der Abweichung aus (höchstens ±300 kcal). Dafür mindestens 3 Wiegungen über 10 Tage eintragen.")
                }
                .listRowBackground(Rectangle().fill(.thinMaterial))
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Gewichtsziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        store.saveProfile(previewProfile)
                        dismiss()
                    }
                    .disabled(Fmt.parse(startText) == nil || Fmt.parse(goalText) == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var previewProfile: BodyProfile {
        var p = draft
        if let s = Fmt.parse(startText), s > 30, s < 350 { p.startKg = s }
        if let g = Fmt.parse(goalText), g > 30, g < 350 { p.goalKg = g }
        return p
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        draft = store.profile
        startText = Fmt.kg(store.profile.startKg)
        goalText = Fmt.kg(store.profile.goalKg)
    }

    @ViewBuilder
    private func resultView(_ n: GoalNumbers) -> some View {
        let p = previewProfile
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(directionTitle(n)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text("\(Fmt.kg(n.currentKg)) → \(Fmt.kg(p.goalKg)) kg")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                if n.direction != .keep {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Fmt.kg(abs(n.currentKg - p.goalKg))) kg").font(.headline).monospacedDigit()
                        Text("in \(max(0, Store.days(from: .now, to: p.goalDate) / 7)) Wochen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                tile("\(n.restDay)", "kcal Ruhetag")
                tile("\(n.restDay + n.trainingBonus)", "kcal Trainingstag")
                tile("\(n.protein) g", "Eiweiß")
            }

            VStack(alignment: .leading, spacing: 4) {
                row("Grundumsatz", "\(Int(n.bmr.rounded())) kcal")
                row("Verbrauch ohne Training", "\(Int(n.maintenance.rounded())) kcal")
                if n.deficit > 0 {
                    row("Defizit pro Tag", "−\(n.deficit) kcal")
                    row("Geplantes Tempo", "−\(n.perWeek.formatted(.number.precision(.fractionLength(2)))) kg/Woche")
                } else if n.deficit < 0 {
                    row("Überschuss pro Tag", "+\(-n.deficit) kcal")
                    row("Geplantes Tempo", "+\((-n.perWeek).formatted(.number.precision(.fractionLength(2)))) kg/Woche")
                }
                if let auto = n.auto, auto.adjust != 0 {
                    row("Automatik", "\(auto.adjust > 0 ? "+" : "")\(auto.adjust) kcal")
                }
            }
            .font(.caption)

            if let warning = warning(n, p) {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func directionTitle(_ n: GoalNumbers) -> String {
        switch n.direction {
        case .lose: return "ABNEHMEN"
        case .gain: return "AUFBAUEN"
        case .keep: return "GEWICHT HALTEN"
        }
    }

    private func warning(_ n: GoalNumbers, _ p: BodyProfile) -> String? {
        if n.belowMinimum {
            return "Das Zieldatum ist sehr knapp – die Kalorien wurden auf ein gesundes Minimum begrenzt. Plane lieber mehr Zeit ein."
        }
        if n.direction == .lose && n.deficit >= 900 {
            return "Mehr als 900 kcal Defizit pro Tag sind nicht sinnvoll – das Ziel dauert länger als geplant. Ein späteres Zieldatum ist realistischer."
        }
        if n.direction == .lose && n.perWeek > n.currentKg * 0.01 {
            return "Mehr als 1 % des Körpergewichts pro Woche kostet Muskeln. Ein späteres Zieldatum ist schonender."
        }
        return nil
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}
