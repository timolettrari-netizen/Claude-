import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var confirmReset = false
    @State private var message: String?

    var body: some View {
        @Bindable var store = store
        List {
            Section("Trainingsplan") {
                if let plan = store.plan {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title).font(.headline)
                        Text("\(plan.split) · seit \(plan.created.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Neuen Plan erstellen", systemImage: "wand.and.stars") {
                    store.showGenerator = true
                }
            }
            .listRowBackground(Rectangle().fill(.thinMaterial))

            Section {
                Toggle(isOn: $store.restAlerts) {
                    Label("Mitteilung bei Pausenende", systemImage: "bell.badge")
                }
            } header: {
                Text("Training")
            } footer: {
                Text("Meldet sich mit Ton, wenn die Satzpause vorbei ist – auch wenn das iPhone gesperrt ist.")
            }
            .listRowBackground(Rectangle().fill(.thinMaterial))

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Backup exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Backup importieren", systemImage: "square.and.arrow.down") {
                    importing = true
                }
                Button("Alle Daten löschen", systemImage: "trash", role: .destructive) {
                    confirmReset = true
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("Alle Daten bleiben nur auf deinem iPhone. Mit dem Backup kannst du sie sichern oder auf ein neues Gerät übertragen.")
            }
            .listRowBackground(Rectangle().fill(.thinMaterial))

            Section("So funktioniert die Progression") {
                Text("Schaffst du in allen Sätzen die obere Wiederholungszahl, schlägt die App beim nächsten Mal mehr Gewicht vor. Sonst steigerst du zuerst die Wiederholungen. Jede 4. Woche ist eine Entlastungswoche mit einem Satz weniger.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Rectangle().fill(.thinMaterial))
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Einstellungen")
        .onAppear { exportURL = store.exportBackup() }
        .onChange(of: store.restAlerts) {
            store.save()
            if store.restAlerts { RestNotifier.shared.requestAuthorization() }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    try store.importBackup(from: url)
                    message = "Backup wurde geladen."
                } catch {
                    message = "Die Datei konnte nicht gelesen werden."
                }
            case .failure:
                message = "Import abgebrochen."
            }
        }
        .confirmationDialog("Wirklich alle Daten löschen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Alles löschen", role: .destructive) {
                store.resetAll()
                store.showGenerator = true
            }
        } message: {
            Text("Plan, Trainingsverlauf und Körpergewicht werden entfernt.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}
