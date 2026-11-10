import SwiftUI
import PhotosUI

/// Liste „Zusätzlich gegessen“ im Essensplan
struct FoodLogCard: View {
    @EnvironmentObject var store: Store
    let day: Date
    @State private var capture = false

    var body: some View {
        let items = store.foods(on: day)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zusätzlich gegessen").sectionTitle()
                Spacer()
                if !items.isEmpty {
                    Text("\(items.reduce(0) { $0 + $1.kcal }) kcal").font(.subheadline.weight(.bold)).foregroundStyle(Color.lime)
                }
            }
            if items.isEmpty {
                Text("Döner, Kantine, Snack zwischendurch? Foto machen – der Coach schätzt Kalorien und Eiweiß.")
                    .font(.footnote).foregroundStyle(Color.mut)
            }
            ForEach(items) { e in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(.subheadline.weight(.semibold))
                        Text("\(e.kcal) kcal · \(e.protein) g Eiweiß · \(e.carbs) g KH · \(e.fat) g Fett")
                            .font(.caption).foregroundStyle(Color.mut)
                    }
                    Spacer()
                    Text(DateUtil.format(e.date, "HHmm")).font(.caption).foregroundStyle(Color.mut)
                    Button { store.deleteFood(e); Haptics.tap() } label: {
                        Image(systemName: "trash").font(.caption).foregroundStyle(Color.mut)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            Button { capture = true } label: { Label("Essen erfassen (Foto)", systemImage: "camera.fill") }
                .buttonStyle(LimeButton())
        }
        .card()
        .sheet(isPresented: $capture) { FoodCaptureView(day: day).environmentObject(store) }
    }
}

/// Foto oder Beschreibung → Schätzung durch Claude → prüfen → speichern
struct FoodCaptureView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var hint = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var estimated = false
    @State private var comment = ""
    // Werte (editierbar)
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    photoArea
                    TextField("Was ist das, wie viel? (optional, z. B. „halber Döner“)", text: $hint, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12).background(Color.card2, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        estimate()
                    } label: {
                        if busy {
                            HStack(spacing: 8) { ProgressView().tint(.black); Text("Coach schätzt …") }
                        } else {
                            Label(estimated ? "Neu schätzen" : "Kalorien schätzen lassen", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(LimeButton(secondary: estimated))
                    .disabled(busy || (image == nil && hint.trimmingCharacters(in: .whitespaces).isEmpty))
                    .opacity(image == nil && hint.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    if let e = errorText {
                        Text(e).font(.footnote).foregroundStyle(.orange)
                    }
                    valuesCard
                    if !comment.isEmpty {
                        Text(comment).font(.footnote).foregroundStyle(Color.mut)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.lime.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Button("Speichern") { save() }
                        .buttonStyle(LimeButton())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                    Text("Schätzwerte – Portionsgrößen auf Fotos sind schwer zu erkennen. Im Zweifel die Werte anpassen.")
                        .font(.caption2).foregroundStyle(Color.mut)
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle("Essen erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Abbrechen") { dismiss() } } }
            .onChange(of: pick) { _, item in if let item { load(item) } }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCamera { img in
                    showCamera = false
                    if let img { image = img; estimated = false }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Teile

    private var photoArea: some View {
        VStack(spacing: 10) {
            if let image {
                Color.black
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button { self.image = nil; pick = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Color.white, Color.black.opacity(0.6))
                        }
                        .padding(8)
                    }
            }
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: { Label("Foto machen", systemImage: "camera") }
                        .buttonStyle(LimeButton(secondary: image != nil))
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Aus Fotos", systemImage: "photo")
                }
                .buttonStyle(LimeButton(secondary: true))
            }
        }
    }

    private var valuesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name des Essens", text: $name)
                .font(.headline)
            HStack(spacing: 8) {
                numberField("kcal", $kcal)
                numberField("Eiweiß g", $protein)
                numberField("KH g", $carbs)
                numberField("Fett g", $fat)
            }
        }
        .card()
    }

    private func numberField(_ label: String, _ value: Binding<String>) -> some View {
        VStack(spacing: 4) {
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.sport(24))
                .padding(.vertical, 8)
                .background(Color.card2, in: RoundedRectangle(cornerRadius: 10))
            Text(label).font(.caption2).foregroundStyle(Color.mut)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(kcal) != nil
    }

    // MARK: Ablauf

    private func load(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                image = img
                estimated = false
            } else {
                errorText = "Das Foto konnte nicht geladen werden."
            }
        }
    }

    private func estimate() {
        busy = true
        errorText = nil
        let jpeg = image.flatMap { FoodCaptureView.jpeg($0) }
        let note = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        let remaining = store.calorieTarget(on: day) - store.eatenKcal(on: day).kcal
        Task {
            do {
                var content: [[String: Any]] = []
                if let jpeg { content.append(ClaudeClient.imageBlock(jpeg)) }
                var text = jpeg == nil ? "Kein Foto, nur Beschreibung." : "Schätze das Essen auf dem Foto."
                if !note.isEmpty { text += " Angabe von mir: \(note)" }
                text += " Mein Kalorienbudget für den Tag ist danach noch ca. \(remaining) kcal (vor diesem Essen)."
                content.append(["type": "text", "text": text])
                let raw = try await ClaudeClient.stream(system: FoodCaptureView.systemPrompt,
                                                        rawMessages: [["role": "user", "content": content]],
                                                        effort: "medium", maxTokens: 2000,
                                                        format: FoodCaptureView.schema) { _ in }
                guard let obj = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any] else {
                    throw ClaudeClient.ClaudeError.http(0, "Antwort nicht lesbar")
                }
                name = obj["name"] as? String ?? ""
                kcal = FoodCaptureView.num(obj["kcal"])
                protein = FoodCaptureView.num(obj["protein"])
                carbs = FoodCaptureView.num(obj["carbs"])
                fat = FoodCaptureView.num(obj["fat"])
                let portion = obj["portion"] as? String ?? ""
                let c = obj["comment"] as? String ?? ""
                comment = [portion.isEmpty ? "" : "Annahme: \(portion)", c].filter { !$0.isEmpty }.joined(separator: "\n")
                estimated = true
                Haptics.success()
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }

    private func save() {
        let entry = FoodEntry(day: DateUtil.dayKey(day), date: entryDate, name: name.trimmingCharacters(in: .whitespaces),
                              kcal: Int(kcal) ?? 0, protein: Int(protein) ?? 0, carbs: Int(carbs) ?? 0, fat: Int(fat) ?? 0,
                              note: comment.isEmpty ? nil : comment)
        store.addFood(entry)
        Haptics.success()
        dismiss()
    }

    /// Heute: jetzt. Anderer Tag: 12 Uhr an diesem Tag.
    private var entryDate: Date {
        if DateUtil.calendar.isDateInToday(day) { return Date() }
        return DateUtil.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    // MARK: Hilfen

    static func num(_ v: Any?) -> String {
        if let i = v as? Int { return String(i) }
        if let d = v as? Double { return String(Int(d.rounded())) }
        if let n = v as? NSNumber { return String(n.intValue) }
        return ""
    }

    /// Foto verkleinern (längste Seite 1024 px) und als JPEG
    static func jpeg(_ img: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return small.jpegData(compressionQuality: 0.7)
    }

    static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": ["type": "string"],
            "portion": ["type": "string"],
            "kcal": ["type": "integer"],
            "protein": ["type": "integer"],
            "carbs": ["type": "integer"],
            "fat": ["type": "integer"],
            "comment": ["type": "string"],
        ],
        "required": ["name", "portion", "kcal", "protein", "carbs", "fat", "comment"],
        "additionalProperties": false,
    ]

    static let systemPrompt = """
    Du schätzt Nährwerte von Essen für die Ernährungs-App eines Fußball-Torwarts (Anfang 30, rund 115 kg), der abnehmen will: \
    viel Eiweiß, höchstens ca. 100 g Kohlenhydrate am Tag, Kaloriendefizit.

    Schätze die gezeigte bzw. beschriebene Portion so genau wie möglich. Nutze Größenhinweise im Bild (Teller, Besteck, Hand, Verpackung). \
    Eine Angabe des Nutzers zur Menge hat Vorrang vor dem Bild. Bei Unsicherheit eher etwas höher schätzen als zu niedrig.

    Felder:
    - name: kurzer deutscher Name des Gerichts (z. B. „Döner mit Soße“).
    - portion: deine Annahme zur Menge in wenigen Worten (z. B. „ganzer Döner, ca. 400 g“).
    - kcal, protein, carbs, fat: ganze Zahlen für die gesamte Portion (Gramm bei den Makros).
    - comment: ein bis zwei kurze Sätze auf Deutsch, per Du: Einordnung zum Tagesbudget und ein konkreter Tipp \
    (z. B. wie es eiweißreicher oder kohlenhydratärmer geht). Nicht belehrend.
    Wenn auf dem Foto kein Essen zu sehen ist: name „Kein Essen erkannt“, alle Zahlen 0, im comment kurz sagen, was zu tun ist.
    """
}

/// Kamera für ein Foto
struct PhotoCamera: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
