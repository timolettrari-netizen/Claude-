import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(Store.self) private var store
    @State private var day = Store.calendar.startOfDay(for: .now)
    @State private var openMeal: PlannedMeal?
    @State private var swapMeal: PlannedMeal?
    @State private var showShopping = false
    @State private var showGoal = false
    @State private var showAddFood = false

    var body: some View {
        let meals = store.meals(on: day)
        let type = store.dayType(day)

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NutritionDayStrip(selected: $day)

                    if !store.profile.configured {
                        GoalSetupCard { showGoal = true }
                    }

                    DaySummaryCard(day: day)

                    SectionTitle(text: "Mahlzeiten", trailing: type.title)
                    ForEach(meals) { meal in
                        MealCard(meal: meal,
                                 eaten: store.isEaten(meal),
                                 onToggle: { store.toggleEaten(meal) },
                                 onSwap: { swapMeal = meal })
                            .contentShape(Rectangle())
                            .onTapGesture { openMeal = meal }
                    }

                    FoodLogCard(day: day) { showAddFood = true }

                    SnackIdeasCard()

                    Text(tip(for: type))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .glassCard(padding: 14, radius: 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Essen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Einkaufsliste", systemImage: "cart") { showShopping = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ziel", systemImage: "target") { showGoal = true }
                }
            }
            .sheet(item: $openMeal) { meal in
                RecipeView(meal: meal)
            }
            .sheet(item: $swapMeal) { meal in
                RecipeSwapSheet(meal: meal)
            }
            .sheet(isPresented: $showShopping) {
                ShoppingListView(start: day)
            }
            .sheet(isPresented: $showGoal) {
                GoalView()
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodSheet(day: day)
            }
        }
    }

    private func tip(for type: DayType) -> String {
        switch (type, store.goalDirection) {
        case (.training, .lose):
            return "Trainingstag: etwas mehr Kalorien, damit du stark trainierst. Kohlenhydrate am besten vor und nach dem Training, Eiweiß zu jeder Mahlzeit."
        case (.rest, .lose):
            return "Ruhetag: kohlenhydratärmere Gerichte, viel Gemüse und Eiweiß. Trink 2,5–3 Liter Wasser oder ungesüßten Tee."
        case (.training, _):
            return "Trainingstag: Iss 1–2 Stunden vorher eine Mahlzeit mit Kohlenhydraten und nach dem Training Eiweiß plus Kohlenhydrate."
        case (.rest, .gain):
            return "Ruhetag: Auch heute wachsen die Muskeln – genug Eiweiß und Kalorien sind wichtig."
        case (.rest, _):
            return "Ruhetag: Eiweiß zu jeder Mahlzeit, viel Gemüse und ausreichend trinken."
        }
    }
}

// MARK: - Foto eines Gerichts

struct FoodImage: View {
    let recipe: Recipe

    var body: some View {
        if UIImage(named: recipe.imageName) != nil {
            Image(recipe.imageName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [Theme.accent.opacity(0.55), Theme.accent2.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(recipe.emoji.prefix(2).joined())
                    .font(.system(size: 30))
            }
        }
    }
}

// MARK: - Tage

private struct NutritionDayStrip: View {
    @Environment(Store.self) private var store
    @Binding var selected: Date

    var body: some View {
        let cal = Store.calendar
        let today = cal.startOfDay(for: .now)
        let days = (0..<10).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        let on = cal.isDate(d, inSameDayAs: selected)
                        Button {
                            selected = d
                        } label: {
                            VStack(spacing: 3) {
                                Text(Fmt.weekdayName(Store.weekdayIndex(d), short: true))
                                    .font(.caption2.weight(.semibold))
                                Text("\(cal.component(.day, from: d))")
                                    .font(.title3.weight(.bold))
                                Image(systemName: store.dayType(d).icon)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .frame(width: 50, height: 70)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(Glass.make(tint: on ? Theme.accent : nil, interactive: true), in: .rect(cornerRadius: 18))
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
    }
}

// MARK: - Tageszusammenfassung

private struct DaySummaryCard: View {
    @Environment(Store.self) private var store
    let day: Date

    var body: some View {
        let target = store.calorieTarget(on: day)
        let totals = store.eatenTotals(on: day)
        let type = store.dayType(day)
        let left = target - totals.kcal
        let progress = min(1, Double(totals.kcal) / Double(max(1, target)))
        let proteinProgress = min(1, Double(totals.protein) / Double(max(1, store.proteinTarget)))

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Badge(text: type.title, icon: type.icon, tint: type == .training ? Theme.accent : .green)
                if type == .training {
                    Badge(text: "+\(store.trainingBonus) kcal", icon: "bolt.fill", tint: .orange)
                }
                Spacer()
            }

            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.1), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(left < 0 ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.accent.gradient),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring, value: progress)
                    VStack(spacing: 0) {
                        Text("\(abs(left))")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(left >= 0 ? "übrig" : "drüber")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 10) {
                    macroRow(title: "Kalorien", value: "\(totals.kcal) / \(target) kcal", progress: progress, color: Theme.accent)
                    macroRow(title: "Eiweiß", value: "\(totals.protein) / \(store.proteinTarget) g", progress: proteinProgress, color: .blue)
                    Text("Kohlenhydrate: \(totals.carbs) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let auto = store.calorieAuto, store.profile.configured {
                Label(auto.text, systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard(padding: 18, radius: 28)
    }

    private func macroRow(title: String, value: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(color)
        }
    }
}

private struct GoalSetupCard: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .glassEffect(Glass.make(tint: Theme.accent), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Gewichtsziel festlegen").font(.headline)
                Text("Daraus berechnet die App dein Kalorienziel und passt die Portionen an.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Los", action: action)
                .buttonStyle(.glassProminent)
        }
        .glassCard()
    }
}

// MARK: - Mahlzeit

private struct MealCard: View {
    let meal: PlannedMeal
    let eaten: Bool
    let onToggle: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FoodImage(recipe: meal.recipe)
                .frame(width: 86, height: 86)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if eaten {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .green)
                            .padding(5)
                    }
                }
                .saturation(eaten ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(meal.slot.name) · \(meal.slot.time)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(meal.recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .strikethrough(eaten, color: .secondary)
                Text("\(meal.kcal) kcal · \(meal.protein) g Eiweiß · \(meal.recipe.minutes) Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: eaten ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(eaten ? Color.green : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(eaten ? "Gegessen" : "Als gegessen markieren")
                .sensoryFeedback(.success, trigger: eaten)

                Button(action: onSwap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Gericht tauschen")
            }
        }
        .glassCard(padding: 10, radius: 26)
    }
}

// MARK: - Rezept

struct RecipeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    @State private var showSwap = false

    var body: some View {
        let eaten = store.isEaten(meal)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FoodImage(recipe: meal.recipe)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 30))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(meal.slot.name) · \(meal.slot.time)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Text(meal.recipe.name).font(.title2.bold())
                        FlowRow(items: ["\(meal.recipe.minutes) Min"] + meal.recipe.devices)
                    }

                    HStack(spacing: 10) {
                        StatTile(value: "\(meal.kcal)", label: "kcal", icon: "flame.fill")
                        StatTile(value: "\(meal.protein) g", label: "Eiweiß", icon: "bolt.heart.fill", tint: .blue)
                        StatTile(value: "\(meal.carbs) g", label: "Kohlenh.", icon: "leaf.fill", tint: .green)
                        StatTile(value: "\(meal.fat) g", label: "Fett", icon: "drop.fill", tint: .yellow)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Zutaten").font(.headline)
                            Spacer()
                            if abs(meal.factor - 1) > 0.01 {
                                Text("Portion ×\(meal.factor.formatted(.number.precision(.fractionLength(0...2))))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(meal.ingredients, id: \.self) { ing in
                            HStack {
                                Text(ing.name)
                                Spacer()
                                Text(ing.text)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                        Text("Mengen sind an dein Kalorienziel angepasst.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zubereitung").font(.headline)
                        ForEach(Array(meal.recipe.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Theme.accent.gradient, in: Circle())
                                Text(step).font(.subheadline)
                            }
                        }
                    }
                    .glassCard()

                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                store.toggleEaten(meal)
                            } label: {
                                Label(eaten ? "Gegessen" : "Als gegessen markieren",
                                      systemImage: eaten ? "checkmark.circle.fill" : "fork.knife")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.glassProminent)

                            Button {
                                showSwap = true
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel("Gericht tauschen")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showSwap) {
                RecipeSwapSheet(meal: meal) { dismiss() }
            }
        }
    }
}

struct RecipeSwapSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    var onPicked: (() -> Void)? = nil

    var body: some View {
        let slotKcal = Double(meal.kcal)
        NavigationStack {
            List {
                if store.mealPicks[meal.key] != nil {
                    Button("Zurück zum Vorschlag", systemImage: "arrow.uturn.backward") {
                        store.mealPicks[meal.key] = nil
                        store.save()
                        close()
                    }
                    .listRowBackground(Rectangle().fill(.thinMaterial))
                }
                Section("\(meal.slot.name) – \(store.swapOptions(for: meal).count) Gerichte") {
                    ForEach(store.swapOptions(for: meal)) { r in
                        Button {
                            store.pickRecipe(r.id, for: meal)
                            close()
                        } label: {
                            HStack(spacing: 12) {
                                FoodImage(recipe: r)
                                    .frame(width: 58, height: 58)
                                    .clipShape(.rect(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Text("\(r.minutes) Min · \(r.protein * 100 / max(1, r.kcal)) g Eiweiß je 100 kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if r.isCarb {
                                        Text("mit Kohlenhydraten – ideal am Trainingstag")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                Spacer()
                                if r.id == meal.recipe.id {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Rectangle().fill(.thinMaterial))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Gericht tauschen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Die Portion wird automatisch auf ca. \(Int(slotKcal)) kcal angepasst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 6)
            }
        }
    }

    private func close() {
        dismiss()
        onPicked?()
    }
}

// MARK: - Selbst erfasstes Essen

private struct FoodLogCard: View {
    @Environment(Store.self) private var store
    let day: Date
    let onAdd: () -> Void

    var body: some View {
        let entries = store.foods(on: day)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sonstiges Essen", systemImage: "square.and.pencil").font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            if entries.isEmpty {
                Text("Auswärts gegessen oder etwas extra? Hier eintragen, damit die Bilanz stimmt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { e in
                    HStack {
                        Text(e.name).font(.subheadline)
                        Spacer()
                        Text("\(e.kcal) kcal · \(e.protein) g")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            store.deleteFood(e.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Löschen")
                    }
                }
            }
        }
        .glassCard()
    }
}

private struct AddFoodSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Was hast du gegessen?", text: $name)
                HStack {
                    TextField("Kalorien", text: $kcal).keyboardType(.numberPad)
                    Text("kcal").foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Eiweiß", text: $protein).keyboardType(.numberPad)
                    Text("g").foregroundStyle(.secondary)
                }
                Section("Schnell eintragen") {
                    ForEach(quick, id: \.0) { item in
                        Button {
                            name = item.0
                            kcal = "\(item.1)"
                            protein = "\(item.2)"
                        } label: {
                            HStack {
                                Text(item.0)
                                Spacer()
                                Text("\(item.1) kcal").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Essen eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let date = Store.calendar.isDateInToday(day) ? Date.now : day.addingTimeInterval(12 * 3600)
                        store.addFood(FoodEntry(date: date,
                                                name: name.isEmpty ? "Essen" : name,
                                                kcal: Int(kcal) ?? 0,
                                                protein: Int(protein) ?? 0))
                        dismiss()
                    }
                    .disabled(Int(kcal) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var quick: [(String, Int, Int)] {
        [("Hartgekochtes Ei", 75, 6), ("Skyr, 150 g", 95, 16), ("Proteinriegel", 200, 20), ("Banane", 105, 1),
         ("Mandeln, 20 g", 120, 4), ("Döner", 750, 35), ("Pizza (ganze)", 900, 35), ("Bier, 0,5 l", 210, 2)]
    }
}

private struct SnackIdeasCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Snack-Ideen bei Hunger", systemImage: "carrot.fill").font(.headline)
            ForEach(store.recipeBook.snacks, id: \.self) { s in
                HStack {
                    Text(s.name).font(.subheadline)
                    Spacer()
                    Text(s.info).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Einkaufsliste

private struct ShoppingListView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let start: Date
    @State private var days = 7
    @State private var checked: Set<String> = []

    var body: some View {
        let items = store.shoppingList(from: start, days: days)
        NavigationStack {
            List {
                Section {
                    Picker("Zeitraum", selection: $days) {
                        Text("3 Tage").tag(3)
                        Text("7 Tage").tag(7)
                        Text("10 Tage").tag(10)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)

                Section("\(items.count) Zutaten ab \(start.formatted(.dateTime.weekday(.abbreviated).day().month()))") {
                    ForEach(items) { item in
                        Button {
                            if checked.contains(item.id) { checked.remove(item.id) } else { checked.insert(item.id) }
                        } label: {
                            HStack {
                                Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(item.id) ? Color.green : Color.secondary)
                                Text(item.name)
                                    .strikethrough(checked.contains(item.id))
                                    .foregroundStyle(checked.contains(item.id) ? Color.secondary : Color.primary)
                                Spacer()
                                Text(item.text).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Rectangle().fill(.thinMaterial))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Einkaufsliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText(items)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func shareText(_ items: [ShoppingItem]) -> String {
        "Einkaufsliste (\(days) Tage)\n" + items.map { "• \($0.name): \($0.text)" }.joined(separator: "\n")
    }
}
