import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Video der Übung hochladen oder filmen → Einzelbilder + Gelenkwinkel → Bewertung durch Claude
struct TechniqueAnalysisView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: String

    enum Phase: Equatable { case idle, reading(Double), thinking, done, failed(String) }

    @State private var phase: Phase = .idle
    @State private var pick: PhotosPickerItem?
    @State private var showCamera = false
    @State private var frames: [AnalyzedFrame] = []
    @State private var result = ""
    @State private var zoom: AnalyzedFrame?
    @State private var task: Task<Void, Never>?

    private var history: [TechniqueLog] { store.s.analyses.filter { $0.exercise == id }.reversed() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch phase {
                    case .idle: intro
                    case .reading(let p): progressCard("Bilder werden ausgewertet …", p)
                    case .thinking, .done: EmptyView()
                    case .failed(let msg):
                        Text(msg).foregroundStyle(.orange).card()
                        sourceButtons
                    }
                    if !frames.isEmpty { frameStrip }
                    if phase == .thinking && result.isEmpty { progressCard("Coach schaut sich die Ausführung an …", nil) }
                    if !result.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Auswertung").sectionTitle()
                            MarkdownText(result).card()
                        }
                    }
                    if phase == .done {
                        Text("KI-Einschätzung aus Einzelbildern – kein Ersatz für einen Trainer. Bei Schmerzen abbrechen.")
                            .font(.caption).foregroundStyle(Color.mut)
                        Button("Neues Video prüfen") { reset() }.buttonStyle(LimeButton(secondary: true))
                    }
                    if phase == .idle && !history.isEmpty { historyList }
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle("Technik: \(store.name(id))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { task?.cancel(); dismiss() } } }
            .onChange(of: pick) { _, item in if let item { load(item) } }
            .fullScreenCover(isPresented: $showCamera) {
                VideoRecorder { url in showCamera = false; if let url { run(url) } }.ignoresSafeArea()
            }
            .sheet(item: $zoom) { f in
                VStack(spacing: 10) {
                    Image(uiImage: f.image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Bild \(f.index) · \(String(format: "%.1f", f.time).replacingOccurrences(of: ".", with: ",")) s").font(.headline)
                    Text(f.measurements.isEmpty ? "Keine Person erkannt" : f.measurements).font(.footnote).foregroundStyle(Color.mut)
                }
                .padding(16)
                .presentationDetents([.medium, .large])
            }
        }
        .onDisappear { task?.cancel() }
    }

    // MARK: Teile

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("So filmst du richtig").font(.headline)
                tip("📐", "Seitlich filmen (bei Kniebeugen auch von vorne), ganzer Körper im Bild.")
                tip("📱", "Handy fest hinstellen, nicht in der Hand halten.")
                tip("💡", "Gutes Licht, ruhiger Hintergrund, enge Kleidung.")
                tip("⏱️", "2–4 Wiederholungen reichen, 5–30 Sekunden.")
            }
            .card()
            sourceButtons
            Text("Die App zieht 12 Einzelbilder aus dem Video und misst die Gelenkwinkel direkt auf dem iPhone. Die Bilder gehen anschließend mit deinem API-Schlüssel an Claude zur Bewertung.")
                .font(.caption).foregroundStyle(Color.mut)
        }
    }

    private var sourceButtons: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $pick, matching: .videos) {
                Label("Video aus Mediathek wählen", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(LimeButton())
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: { Label("Jetzt filmen", systemImage: "video.fill") }
                    .buttonStyle(LimeButton(secondary: true))
            }
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) { Text(icon); Text(text).font(.subheadline) }
    }

    private func progressCard(_ title: String, _ p: Double?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) { ProgressView(); Text(title).font(.subheadline) }
            if let p { ProgressView(value: p).tint(.lime) }
        }
        .card()
    }

    private var frameStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Einzelbilder").sectionTitle()
                Spacer()
                Text("grün = links, orange = rechts").font(.caption2).foregroundStyle(Color.mut)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(frames) { f in
                        Button { zoom = f } label: {
                            Image(uiImage: f.image).resizable().scaledToFill()
                                .frame(width: 92, height: 120).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topLeading) {
                                    Text("\(f.index)").font(.caption2.weight(.heavy)).foregroundStyle(.black)
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color.lime, in: Capsule()).padding(4)
                                }
                                .overlay(alignment: .bottom) {
                                    if !f.personFound {
                                        Text("keine Person").font(.system(size: 9, weight: .bold))
                                            .padding(3).background(.orange, in: Capsule()).padding(4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frühere Analysen").sectionTitle()
            ForEach(history) { h in
                DisclosureGroup {
                    MarkdownText(h.text).padding(.top, 6)
                } label: {
                    Text(DateUtil.format(h.date, "EEEEdMMMMHHmm")).font(.subheadline)
                }
                .card(padding: 12)
                .contextMenu { Button("Löschen", role: .destructive) { store.s.analyses.removeAll { $0.id == h.id } } }
            }
        }
    }

    // MARK: Ablauf

    private func reset() {
        task?.cancel()
        frames = []; result = ""; pick = nil; phase = .idle
    }

    private func load(_ item: PhotosPickerItem) {
        phase = .reading(0)
        task = Task {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    phase = .failed("Das Video konnte nicht geladen werden."); return
                }
                await analyze(movie.url)
            } catch {
                phase = .failed("Das Video konnte nicht geladen werden: \(error.localizedDescription)")
            }
        }
    }

    private func run(_ url: URL) {
        phase = .reading(0)
        task = Task { await analyze(url) }
    }

    @MainActor
    private func analyze(_ url: URL) async {
        frames = []; result = ""
        do {
            let (fs, duration) = try await VideoAnalyzer.analyze(url: url) { p in phase = .reading(p) }
            try? FileManager.default.removeItem(at: url)
            frames = fs
            guard fs.contains(where: \.personFound) else {
                phase = .failed("Auf den Bildern wurde keine Person erkannt. Filme mit mehr Abstand, besserem Licht und dem ganzen Körper im Bild.")
                return
            }
            phase = .thinking
            let text = try await ClaudeClient.stream(system: systemPrompt, rawMessages: [userMessage(fs, duration: duration)],
                                                     effort: "medium", maxTokens: 8000) { t in result = t }
            if Task.isCancelled { return }
            result = text
            store.s.analyses.append(TechniqueLog(exercise: id, date: Date(), text: text))
            phase = .done
            Haptics.success()
        } catch is CancellationError {
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private var systemPrompt: String {
        """
        Du bist ein erfahrener Athletik- und Torwarttrainer und prüfst die Technik deines Athleten anhand von Einzelbildern aus einem Video. \
        Er ist Torwart im Amateurfußball, Anfang 30, schwerer gebaut und will abnehmen. Antworte auf Deutsch, direkt und motivierend, wie ein Trainer am Spielfeldrand.

        Auf den Bildern ist automatisch ein Skelett eingezeichnet (grün = linke Körperseite, orange = rechte). \
        Es und die mitgelieferten Winkel stammen aus einer Haltungserkennung auf dem Handy und können danebenliegen, \
        besonders bei verdeckten Gelenken, schlechtem Licht oder seitlicher Ansicht. Verlass dich vor allem auf das, was du im Bild siehst, \
        und nutze die Winkel nur als Hinweis. Zwischen den Bildern fehlen Bewegungsteile – sag ehrlich, was du nicht beurteilen kannst.

        Wenn auf den Bildern eine andere Übung zu sehen ist, keine Person oder die Qualität zu schlecht ist, sag das kurz und erkläre, wie er besser filmt.

        Aufbau der Antwort (Markdown, knapp):
        **Gesamteindruck** – ein bis zwei Sätze und eine Note von 1 (gefährlich) bis 10 (sauber).
        **Das passt** – 2–3 Punkte.
        **Verbessern** – die wichtigsten Fehler, höchstens 3, nach Wichtigkeit. Je Fehler: was du siehst (mit Bildnummer), warum es wichtig ist, wie er es korrigiert.
        **Fokus für den nächsten Satz** – ein bis zwei kurze Kommandos, die man sich merken kann.
        Wenn etwas verletzungsgefährlich aussieht, nenne es zuerst und deutlich.
        """
    }

    private func userMessage(_ fs: [AnalyzedFrame], duration: Double) -> [String: Any] {
        let e = store.ex(id)
        let d = store.dose(id)
        var content: [[String: Any]] = []
        content.append(["type": "text", "text": """
            Übung: \(store.name(id)) (Kategorie \(store.category(id)), geplant \(d.text))
            Ausrüstung: \(store.equipment(id))
            So soll sie aussehen:
            \(store.steps(id).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
            Typische Fehler: \(store.mistakes(id))
            Ziel der Übung: \(e?.why ?? "")

            Videolänge \(String(format: "%.1f", duration)) s. Es folgen \(fs.count) Einzelbilder in zeitlicher Reihenfolge.
            """])
        for f in fs {
            content.append(["type": "text", "text": "Bild \(f.index) bei \(String(format: "%.1f", f.time)) s – " +
                            (f.personFound ? "Messwerte: \(f.measurements)" : "keine Person erkannt")])
            content.append(ClaudeClient.imageBlock(f.jpeg))
        }
        content.append(["type": "text", "text": "Bitte bewerte jetzt meine Ausführung."])
        return ["role": "user", "content": content]
    }
}

/// Einfache Markdown-Darstellung (Absätze, **fett**, Aufzählungen)
struct MarkdownText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    Color.clear.frame(height: 2)
                } else if t.hasPrefix("#") {
                    Text(inline(t.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))).font(.headline)
                } else if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.lime)
                        Text(inline(String(t.dropFirst(2)))).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(inline(t)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.subheadline)
    }
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }
}

/// Video aus der Fotomediathek als Datei
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { received in
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dst)
            return PickedMovie(url: dst)
        }
    }
}

/// Kamera zum Filmen (max. 30 s)
struct VideoRecorder: UIViewControllerRepresentable {
    let done: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.mediaTypes = [UTType.movie.identifier]
        p.cameraCaptureMode = .video
        p.videoMaximumDuration = 30
        p.videoQuality = .typeMedium
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (URL?) -> Void
        init(done: @escaping (URL?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let src = info[.mediaURL] as? URL else { done(nil); return }
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.copyItem(at: src, to: dst)
            done(dst)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
