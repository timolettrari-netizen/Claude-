import SwiftUI
import Charts

/// Gewicht mit Soll-Linie und Eingabe
struct WeightCard: View {
    @EnvironmentObject var store: Store
    @State private var input = ""

    var body: some View {
        let kg = store.currentKg
        let diff = kg - store.targetKg(on: Date())
        let lost = store.s.body.startKg - kg
        let d = store.deficit
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gewicht").sectionTitle()
                Text("noch \(d.days) Tage").font(.caption).foregroundStyle(Color.mut)
            }
            HStack(spacing: 22) {
                value(fmtKg((kg * 10).rounded() / 10), "kg aktuell", .white)
                value((lost >= 0 ? "−" : "+") + fmtKg((abs(lost) * 10).rounded() / 10), "seit Start", lost >= 0 ? .lime : .red)
                value((diff > 0 ? "+" : "−") + fmtKg((abs(diff) * 10).rounded() / 10), "zur Soll-Linie", diff > 1.5 ? .red : diff <= 0.3 ? .lime : .orange)
            }
            Chart {
                ForEach(store.s.weights) { w in
                    LineMark(x: .value("Datum", w.date), y: .value("kg", w.kg), series: .value("Reihe", "Gewicht"))
                        .foregroundStyle(Color.cyan).lineStyle(StrokeStyle(lineWidth: 3))
                    PointMark(x: .value("Datum", w.date), y: .value("kg", w.kg)).foregroundStyle(Color.cyan)
                }
                LineMark(x: .value("Datum", store.s.body.startDate), y: .value("kg", store.s.body.startKg), series: .value("Reihe", "Soll"))
                    .foregroundStyle(Color.mut).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                LineMark(x: .value("Datum", store.s.body.goalDate), y: .value("kg", store.s.body.goalKg), series: .value("Reihe", "Soll"))
                    .foregroundStyle(Color.mut).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                RuleMark(x: .value("Heute", Date())).foregroundStyle(Color.lime.opacity(0.6))
            }
            .chartYScale(domain: (store.s.body.goalKg - 3)...(max(store.s.body.startKg, store.s.weights.map(\.kg).max() ?? 0) + 3))
            .frame(height: 160)
            HStack {
                TextField("Gewicht heute (kg)", text: $input).keyboardType(.decimalPad)
                    .padding(10).background(Color.card2, in: RoundedRectangle(cornerRadius: 10))
                Button("Speichern") {
                    if let v = Double(input.replacingOccurrences(of: ",", with: ".")), v > 30, v < 300 {
                        store.addWeight(v); input = ""; Haptics.success()
                    }
                }
                .font(.subheadline.weight(.bold)).foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 10).background(Color.lime, in: RoundedRectangle(cornerRadius: 10))
            }
            Text("Rechnerisches Tempo: ca. \(String(format: "%.2f", d.perWeek).replacingOccurrences(of: ".", with: ",")) kg pro Woche · Ziel \(fmtKg(store.s.body.goalKg)) kg am \(DateUtil.format(store.s.body.goalDate, "dMMMyyyy"))")
                .font(.footnote).foregroundStyle(Color.mut)
            if let auto = store.calorieAuto {
                Label(auto.text, systemImage: "wand.and.stars")
                    .font(.footnote).foregroundStyle(auto.adjust == 0 ? Color.lime : auto.adjust < 0 ? Color.orange : Color.cyan)
            } else if store.s.autoCalories {
                Label("Automatik startet, sobald du in 10 Tagen mindestens 3× gewogen hast (Waage über Apple Health zählt mit).",
                      systemImage: "wand.and.stars")
                    .font(.footnote).foregroundStyle(Color.mut)
            }
            if d.need > 1000 {
                Text("Ehrlich: Für dein Zieldatum wären \(Int(d.need)) kcal Defizit pro Tag nötig – zu viel. Ich rechne mit \(d.perDay) kcal. Verschiebe sonst das Zieldatum im Profil.")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
        .card()
    }

    private func value(_ v: String, _ label: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(v).font(.sport(28)).foregroundStyle(c)
            Text(label).font(.caption).foregroundStyle(Color.mut)
        }
    }
}

/// Kalorienziel und Verbrauch heute
struct CaloriesCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let target = store.calorieTarget(on: Date())
        let eaten = store.eatenKcal(on: Date()).kcal
        HStack(spacing: 14) {
            Image(systemName: "fork.knife").font(.title3).foregroundStyle(.black)
                .frame(width: 46, height: 46).background(Color.lime, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("Noch \(max(0, target - eaten)) kcal").font(.headline)
                Text("Ziel heute \(target) kcal · \(store.proteinTarget) g Eiweiß · max. 100 g KH").font(.caption).foregroundStyle(Color.mut)
                ProgressView(value: Double(min(eaten, target)), total: Double(max(target, 1))).tint(.lime)
            }
        }
        .card()
    }
}

/// Dienstplan: 5 Wochen, Tippen wechselt frei → Spät → Früh/Nacht → leer
struct ShiftCalendarView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let start = DateUtil.weekStart(Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tippe auf einen Tag: frei → Spät → Früh/Nacht → leer. Dein 4-Tage-Rhythmus (frei, frei, Spät, Früh/Nacht) ist vorausgefüllt.")
                    .font(.subheadline).foregroundStyle(Color.mut)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(DateUtil.weekdaysShort, id: \.self) { Text($0).font(.caption.weight(.semibold)).foregroundStyle(Color.mut) }
                    ForEach(0..<35, id: \.self) { i in
                        let d = DateUtil.calendar.date(byAdding: .day, value: i, to: start) ?? start
                        let sh = store.shift(on: d)
                        let today = DateUtil.calendar.isDateInToday(d)
                        let past = d < DateUtil.calendar.startOfDay(for: Date())
                        Button { store.cycleShift(d); Haptics.tap() } label: {
                            VStack(spacing: 1) {
                                Text("\(DateUtil.calendar.component(.day, from: d))").font(.headline)
                                Text(sh == "F" ? "frei" : sh == "D" ? "Spät" : sh == "N" ? "F/N" : "–").font(.system(size: 10, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(sh == nil ? Color.mut : color(sh))
                            .background(color(sh).opacity(sh == nil ? 0.06 : 0.16), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(today ? Color.lime : .clear, lineWidth: 2))
                            .opacity(past ? 0.45 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Früh/Nacht = Frühdienst 5:30–12:30 und Nachtdienst 18:30–5:30. Spät = 12:30–18:30. An Früh/Nacht-Tagen wählt die App automatisch die kurze Trainingsvariante, die Mahlzeiten passen sich den Diensten an.")
                    .font(.footnote).foregroundStyle(Color.mut)
                Button("Änderungen zurücksetzen") { store.s.shifts = [:] }.buttonStyle(LimeButton(secondary: true))
            }
            .padding(16)
        }
        .background(Color.bg)
        .navigationTitle("Dienstplan")
    }

    private func color(_ sh: String?) -> Color {
        switch sh {
        case "D": return .yellow
        case "N": return .purple
        case "F": return .green
        default: return .white
        }
    }
}

/// Körperdaten fürs Abnehmen
struct BodySettingsSection: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Section {
            numberRow("Größe (cm)", value: $store.s.body.heightCm, step: 1)
            Stepper("Alter: \(store.s.body.age)", value: $store.s.body.age, in: 14...90)
            numberRow("Startgewicht (kg)", value: $store.s.body.startKg, step: 0.5)
            DatePicker("Startdatum", selection: $store.s.body.startDate, displayedComponents: .date)
            numberRow("Zielgewicht (kg)", value: $store.s.body.goalKg, step: 0.5)
            DatePicker("Zieldatum", selection: $store.s.body.goalDate, displayedComponents: .date)
            Stepper("Schrittziel: \(store.s.body.stepGoal)", value: $store.s.body.stepGoal, in: 3000...30000, step: 500)
            Toggle("Kalorienziel automatisch anpassen", isOn: $store.s.autoCalories)
            Stepper("Eigene Anpassung: \(store.s.body.calorieAdjust > 0 ? "+" : "")\(store.s.body.calorieAdjust) kcal",
                    value: $store.s.body.calorieAdjust, in: -300...300, step: 50)
            NavigationLink("Dienstplan") { ShiftCalendarView() }
        } header: { Text("Abnehmen & Dienstplan") } footer: {
            Text("Grundumsatz nach Mifflin-St Jeor × 1,2 plus Schritte, Defizit aus Ziel und Zieldatum (400–900 kcal/Tag), nie unter 1.800 kcal. An Trainingstagen kommt die Hälfte des Trainingsverbrauchs dazu. Die Automatik vergleicht jeden Montag deinen Gewichtstrend der letzten 4 Wochen mit dem Plan und passt das Ziel um höchstens −300 bis +200 kcal an. Kein Ersatz für ärztliche Beratung.")
        }
    }

    private func numberRow(_ title: String, value: Binding<Double>, step: Double) -> some View {
        Stepper(value: value, step: step) {
            HStack { Text(title); Spacer(); Text(fmtKg(value.wrappedValue)).foregroundStyle(Color.mut) }
        }
    }
}
