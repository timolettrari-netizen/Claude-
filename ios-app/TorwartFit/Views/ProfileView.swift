import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var showGoal = false
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
                    Button { showGoal = true } label: {
                        HStack {
                            Text("Ziel").foregroundStyle(.white)
                            Spacer()
                            Text(store.goal.map { "\($0.icon) \($0.name)" } ?? "–").foregroundStyle(Color.mut)
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
                    Picker("Woche im 4-Wochen-Block", selection: Binding(get: { store.weekIndex }, set: { store.setWeekIndex($0) })) {
                        ForEach(0..<4, id: \.self) { Text("\($0 + 1) – \(BlockWeek.all[$0].name)").tag($0) }
                    }
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
                } header: { Text("Apple Health") } footer: {
                    Text("Liest Schritte und Gewicht, speichert jede Einheit als Krafttraining in Health.")
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
