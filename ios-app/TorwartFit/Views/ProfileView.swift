import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var showGoal = false
    @State private var showPlan = false
    @State private var apiKey = Keychain.get("anthropic_api_key") ?? ""
    @State private var importing = false
    @State private var message: String?
    @State private var confirmReset = false

    private var reminderTime: Binding<Date> {
        Binding(get: {
            DateUtil.calendar.date(bySettingHour: store.s.reminderHour, minute: store.s.reminderMinute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            store.s.reminderHour = DateUtil.calendar.component(.hour, from: d)
            store.s.reminderMinute = DateUtil.calendar.component(.minute, from: d)
            Reminders.reschedule(store)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.s.name)
                    Button { if store.program != nil { showPlan = true } else { showGoal = true } } label: {
                        HStack {
                            Text("Plan / Ziel").foregroundStyle(.white)
                            Spacer()
                            Text(store.program.map { "\($0.goal.icon) \($0.goal.name) · \($0.weekText)" } ?? "Kein Plan").foregroundStyle(Color.mut)
                        }
                    }
                    Picker("Spieltag", selection: $store.s.gameDay) {
                        Text("Kein fester Spieltag").tag(-1)
                        ForEach(0..<7, id: \.self) { Text(DateUtil.weekdays[$0]).tag($0) }
                    }
                } footer: {
                    Text("Der Plan richtet sich nach deinem Spieltag: Kraft früh in der Woche, kurz vor dem Spiel nur Aktivierung.")
                }

                BodySettingsSection()

                Section("Training") {
                    Picker("Ort", selection: $store.s.place) {
                        Text("🏋️ Studio").tag("gym")
                        Text("🏠 Zuhause").tag("home")
                    }
                    .pickerStyle(.segmented)
                    Picker("Einheiten pro Woche", selection: $store.s.days) {
                        ForEach(2...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Picker("Läufe pro Woche", selection: $store.s.runsPerWeek) {
                        Text("Aus").tag(0)
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Button("Laufplan neu starten (Woche 1)") { store.s.runPlanStart = DateUtil.weekStart(Date()) }
                    Picker("Woche im 4-Wochen-Block", selection: Binding(get: { store.weekIndex }, set: { store.setWeekIndex($0) })) {
                        ForEach(0..<4, id: \.self) { Text("\($0 + 1) – \(BlockWeek.all[$0].name)").tag($0) }
                    }
                }

                Section {
                    Toggle("Sprachansagen beim Laufen", isOn: $store.s.coachVoice)
                    Picker("Pulsquelle", selection: $store.s.hrSource) {
                        Text("Keine").tag("none")
                        Text("Brustgurt / Bluetooth").tag("ble")
                        Text("Apple Watch").tag("watch")
                    }
                    if store.s.hrSource == "ble" {
                        NavigationLink("Pulsgurt koppeln") { HRPairView() }
                    }
                    Stepper(value: $store.s.maxHR, in: 0...230) {
                        HStack {
                            Text("Max. Puls")
                            Spacer()
                            Text(store.s.maxHR == 0 ? "\(store.maxHeartRate) (automatisch)" : "\(store.s.maxHR)").foregroundStyle(Color.mut)
                        }
                    }
                } header: { Text("Lauf-Coach") } footer: {
                    Text("Der Coach sagt Abschnitte, Kilometer und „schneller/langsamer“ an. Lockere Läufe in Zone 2 (60–75 % vom Max-Puls = \(Int(Double(store.maxHeartRate) * 0.6))–\(Int(Double(store.maxHeartRate) * 0.75))). Apple Watch: auf der Uhr gleichzeitig ein Training „Laufen im Freien“ starten und Apple Health verbinden – der Puls kommt dann mit wenigen Sekunden Verzögerung. Max. Puls auf 0 = automatisch (208 − 0,7 × Alter).")
                }

                Section {
                    Toggle("Apple Health verbinden", isOn: Binding(get: { store.s.healthEnabled }, set: { on in
                        if on {
                            Task {
                                let ok = await HealthService.shared.requestAccess()
                                await MainActor.run { store.s.healthEnabled = ok; if !ok { message = "Apple Health ist auf diesem Gerät nicht verfügbar." } }
                                await store.refreshHealth()
                            }
                        } else { store.s.healthEnabled = false }
                    }))
                    if store.s.healthEnabled {
                        Button("Garmin-/Strava-Trainings jetzt übernehmen") {
                            Task {
                                let r = await store.importHealthRuns(days: 365)
                                let k = await store.importHealthStrength(days: 365)
                                await MainActor.run {
                                    message = r + k == 0 ? "Keine neuen Trainings gefunden." : "Übernommen: \(r) Läufe/Touren (Laufen, Gehen, Wandern, Rad) und \(k) weitere Trainings (z. B. Fußball, Kraft)."
                                }
                            }
                        }
                    }
                } header: { Text("Apple Health") } footer: {
                    Text("Liest Schritte, aktive Kalorien, Schlaf, Ruhepuls, Gewicht und Puls und übernimmt alle Aktivitäten aus Garmin Connect und Strava automatisch (Laufen, Rad, Gehen, Wandern, Fußball, Kraft …). Der Schlaf füllt deine Tagesform vor. Dafür in Garmin Connect (Mehr → Einstellungen → Verbundene Apps → Apple Health) bzw. Strava (Einstellungen → Anwendungen, Dienste und Geräte → Health) die Verbindung zu Apple Health einschalten und alle Datenarten erlauben.")
                }

                Section("Erinnerungen") {
                    Toggle("An Trainingstagen erinnern", isOn: Binding(get: { store.s.remindersEnabled }, set: { on in
                        if on {
                            Task {
                                let ok = await Reminders.requestPermission()
                                await MainActor.run { store.s.remindersEnabled = ok; Reminders.reschedule(store) }
                            }
                        } else { store.s.remindersEnabled = false; Reminders.reschedule(store) }
                    }))
                    if store.s.remindersEnabled {
                        DatePicker("Uhrzeit", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    SecureField("Claude API-Schlüssel (sk-ant-…)", text: $apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Schlüssel speichern") {
                        Keychain.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: "anthropic_api_key")
                        message = apiKey.isEmpty ? "Schlüssel entfernt." : "Schlüssel sicher im Schlüsselbund gespeichert."
                    }
                } header: { Text("KI-Coach") } footer: {
                    Text("Den Schlüssel bekommst du unter console.anthropic.com → API Keys. Jede Coach-Antwort kostet ein paar Cent und wird über dein Anthropic-Konto abgerechnet. Der Schlüssel bleibt nur auf diesem iPhone.")
                }

                Section {
                    ShareLink(item: store.exportFile()) { Label("Backup exportieren", systemImage: "square.and.arrow.up") }
                    Button { importing = true } label: { Label("Backup importieren", systemImage: "square.and.arrow.down") }
                    Button("Alle Daten löschen", role: .destructive) { confirmReset = true }
                } header: { Text("Daten") } footer: {
                    Text("Import funktioniert auch mit einem Backup der Web-App (Profil → Backup exportieren). Deine Daten bleiben auf diesem iPhone.")
                }

                Section {
                    Text("Übungsfotos: Free Exercise DB (gemeinfrei, github.com/yuhonas/free-exercise-db)")
                    Text("TorwartFit 1.0").foregroundStyle(Color.mut)
                }
                .font(.footnote)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Profil")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { DismissButton() } }
            .sheet(isPresented: $showGoal) { GoalPickerView(first: false).environmentObject(store) }
            .sheet(isPresented: $showPlan) { PlanSheet().environmentObject(store) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), store.importBackup(data) {
                    message = "Backup geladen: \(store.s.logs.count) Einheiten."
                } else {
                    message = "Datei konnte nicht gelesen werden."
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog("Wirklich alle Trainings und Einstellungen löschen?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) { store.s = AppState() }
            }
            .onChange(of: store.s.days) { _, _ in Reminders.reschedule(store) }
            .onChange(of: store.s.gameDay) { _, _ in Reminders.reschedule(store) }
        }
    }
}

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Fertig") { dismiss() } }
}
