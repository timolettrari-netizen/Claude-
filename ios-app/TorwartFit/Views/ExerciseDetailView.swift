import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: String
    var short = false
    @State private var showAnalysis = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExerciseMedia(id: id)
                    let d = store.dose(id, short: short)
                    HStack(spacing: 8) {
                        Pill(text: d.text, highlight: true)
                        Pill(text: "Pause \(store.rest(id)) s")
                        Pill(text: store.category(id))
                        let b = store.bestKg(id)
                        if b > 0 { Pill(text: "Bestwert \(fmtKg(b)) kg") }
                    }
                    if let pr = store.progression(id, short: short) {
                        Text(pr.text + (pr.up.map { "\n↑ Bereit für \(fmtKg($0)) kg" } ?? ""))
                            .font(.subheadline.weight(pr.up == nil ? .regular : .semibold))
                            .foregroundStyle(pr.up == nil ? Color.white : Color.lime)
                            .card(padding: 12)
                    }
                    section("Ausrüstung") { row("🏋️", store.equipment(id), .gray) }
                    section("So geht's") {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(store.steps(id).enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)").font(.footnote.weight(.bold)).foregroundStyle(.black)
                                        .frame(width: 24, height: 24).background(Color.lime, in: Circle())
                                    Text(step).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 10)
                                if i < store.steps(id).count - 1 { Divider().overlay(Color.line).padding(.leading, 36) }
                            }
                        }
                    }
                    section("Achte auf") { row("!", store.mistakes(id), .orange) }
                    section("Warum") { row("🧤", store.ex(id)?.why ?? "", .lime) }
                    Button { showAnalysis = true } label: {
                        Label("Technik per Video prüfen", systemImage: "video.badge.checkmark")
                    }
                    .buttonStyle(LimeButton())
                    let n = store.s.analyses.filter { $0.exercise == id }.count
                    if n > 0 {
                        Text("\(n) frühere Analyse\(n == 1 ? "" : "n") gespeichert").font(.caption).foregroundStyle(Color.mut)
                    }
                    if let url = URL(string: "https://www.youtube.com/results?search_query=" +
                                     (store.name(id) + " Ausführung").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                        Link(destination: url) { Label("Video auf YouTube", systemImage: "play.rectangle.fill") }
                            .buttonStyle(LimeButton(secondary: true))
                    }
                    if let p = store.photo(id) {
                        Text(p.hasPrefix("Gen_") ? "Fotos: KI-generierte Beispielbilder" : "Fotos: Free Exercise DB (gemeinfrei)")
                            .font(.caption2).foregroundStyle(Color.mut)
                    }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle(store.name(id))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
            .sheet(isPresented: $showAnalysis) { TechniqueAnalysisView(id: id).environmentObject(store) }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.footnote).foregroundStyle(Color.mut).padding(.leading, 4)
            content().card(padding: 14)
        }
    }

    private func row(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon).font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                .frame(width: 28, height: 28).background(color, in: RoundedRectangle(cornerRadius: 7))
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
