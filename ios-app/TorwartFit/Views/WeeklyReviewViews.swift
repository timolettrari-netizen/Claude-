import SwiftUI

/// Karte auf „Heute“: Sonntag ab 17 Uhr bis Mittwoch
struct WeeklyReviewCard: View {
    @EnvironmentObject var store: Store
    @State private var open = false

    var body: some View {
        let ws = store.reviewWeekStart
        let done = store.review(for: ws) != nil
        if store.reviewWindowOpen {
            Button { open = true } label: {
                HStack(spacing: 14) {
                    Text("📋").font(.system(size: 24))
                        .frame(width: 46, height: 46).background(Color.lime.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(done ? "Dein Wochenrückblick" : "Wochenrückblick bereit").font(.headline).foregroundStyle(.white)
                        Text(done ? "\(store.weekTitle(ws)) · Fokus für diese Woche ansehen"
                                  : "\(store.weekTitle(ws)) · Coach wertet deine Woche aus")
                            .font(.caption).foregroundStyle(Color.mut)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.mut)
                }
                .card()
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(done ? Color.clear : Color.lime.opacity(0.5), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $open) { WeeklyReviewView(weekStart: ws, autoStart: true).environmentObject(store) }
        }
    }
}

/// Rückblick einer Woche erstellen/ansehen, darunter frühere Rückblicke
struct WeeklyReviewView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let weekStart: Date
    /// true, wenn über die Karte geöffnet: dann sofort erstellen
    var autoStart = false

    @State private var streaming: String?
    @State private var errorText: String?
    @State private var task: Task<Void, Never>?

    private var saved: WeeklyReview? { store.review(for: weekStart) }
    private var older: [WeeklyReview] {
        store.s.reviews.filter { !DateUtil.calendar.isDate($0.weekStart, inSameDayAs: weekStart) }.reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.weekTitle(weekStart)).font(.sport(24)).textCase(.uppercase)
                    if let text = streaming {
                        if text.isEmpty {
                            HStack(spacing: 10) { ProgressView(); Text("Coach wertet deine Woche aus …").font(.subheadline) }.card()
                        } else {
                            MarkdownText(text).card()
                        }
                    } else if let r = saved {
                        MarkdownText(r.text).card()
                        Text("Erstellt \(DateUtil.format(r.created, "EEEEdMMMMHHmm"))").font(.caption2).foregroundStyle(Color.mut)
                        Button("Neu erstellen") { generate() }.buttonStyle(LimeButton(secondary: true))
                    } else {
                        Text("Der Coach schaut sich deine Trainings, Läufe und Garmin-Aktivitäten, Schritte, Gewicht, Essen und Tagesform der Woche an und plant mit dir die nächste.")
                            .font(.subheadline).foregroundStyle(Color.mut)
                        Button { generate() } label: { Label("Rückblick erstellen", systemImage: "sparkles") }
                            .buttonStyle(LimeButton())
                    }
                    if let e = errorText {
                        Text(e).font(.footnote).foregroundStyle(.orange)
                    }
                    if !older.isEmpty && streaming == nil {
                        Text("Frühere Rückblicke").sectionTitle().padding(.top, 8)
                        ForEach(older) { r in
                            DisclosureGroup {
                                MarkdownText(r.text).padding(.top, 6)
                            } label: {
                                Text(store.weekTitle(r.weekStart)).font(.subheadline)
                            }
                            .card(padding: 12)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle("Wochenrückblick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { task?.cancel(); dismiss() } } }
            .onAppear { if autoStart && saved == nil && streaming == nil { generate() } }
        }
        .onDisappear { task?.cancel() }
    }

    private func generate() {
        task?.cancel()
        errorText = nil
        streaming = ""
        let ws = weekStart
        task = Task {
            var steps: [(date: Date, steps: Int)] = []
            if store.s.healthEnabled { steps = await HealthService.shared.dailySteps(from: ws, days: 7) }
            let report = store.weekReport(ws, steps: steps)
            let msg: [String: Any] = ["role": "user", "content": "Hier sind meine Daten der Woche:\n\n\(report)\n\nBitte schreib meinen Wochenrückblick."]
            do {
                let text = try await ClaudeClient.stream(system: Store.reviewSystemPrompt, rawMessages: [msg],
                                                         effort: "medium", maxTokens: 4000) { t in streaming = t }
                if Task.isCancelled { return }
                store.saveReview(weekStart: ws, text: text)
                Haptics.success()
            } catch {
                if !Task.isCancelled { errorText = error.localizedDescription }
            }
            streaming = nil
        }
    }
}
