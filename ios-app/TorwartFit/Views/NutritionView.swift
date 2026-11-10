import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var store: Store
    @State private var day = DateUtil.calendar.startOfDay(for: Date())
    @State private var recipe: PlannedMeal?
    @State private var picking: PlannedMeal?
    @State private var showShopping = false

    private var days: [Date] {
        (0..<10).compactMap { DateUtil.calendar.date(byAdding: .day, value: $0, to: DateUtil.calendar.startOfDay(for: Date())) }
    }

    var body: some View {
        let meals = store.meals(on: day)
        let target = store.calorieTarget(on: day)
        let eaten = store.eatenKcal(on: day)
        let kind = store.dayKind(day)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ernährung").font(.sport(40)).textCase(.uppercase).padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(days, id: \.self) { d in
                                let on = DateUtil.calendar.isDate(d, inSameDayAs: day)
                                Button { day = d; Haptics.tap() } label: {
                                    VStack(spacing: 2) {
                                        Text(DateUtil.weekdaysShort[DateUtil.dayIndex(d)]).font(.caption2.weight(.semibold))
                                        Text("\(DateUtil.calendar.component(.day, from: d))").font(.title3.weight(.semibold))
                                        Text(ShiftChip.short(store.dayKind(d))).font(.system(size: 10))
                                    }
                                    .frame(width: 52, height: 66)
                                    .foregroundStyle(on ? Color.black : .white)
                                    .background(on ? Color.lime : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(DateUtil.format(day, "EEEEdM")).font(.sport(24)).textCase(.uppercase)
                            Spacer()
                            ShiftChip(kind: kind)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(eaten.kcal)").font(.sport(40))
                            Text("von \(target) kcal gegessen").font(.subheadline).foregroundStyle(Color.mut)
                        }
                        ProgressView(value: Double(min(eaten.kcal, target)), total: Double(max(target, 1))).tint(.lime)
                        macro("Eiweiß", eaten.protein, store.proteinTarget, "g", .cyan)
                        macro("Kohlenhydrate", eaten.carbs, 100, "g (max.)", eaten.carbs > 100 ? .red : .purple)
                        if let p = store.plan(for: DateUtil.dayIndex(day)), let se = store.catalog.session(p) {
                            Text("Training: \(se.name) – dafür ca. \(target - store.baseIntake) kcal extra eingeplant.")
                                .font(.footnote).foregroundStyle(Color.mut)
                        }
                    }
                    .card()

                    if let tip = store.nutrition.tips[kind] {
                        Text(tip).font(.subheadline)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.lime.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lime.opacity(0.2)))
                    }

                    ForEach(meals) { m in mealCard(m) }

                    Button { showShopping = true } label: { Label("Einkaufsliste für 7 Tage", systemImage: "cart") }
                        .buttonStyle(LimeButton(secondary: true))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wenn der Hunger kommt").sectionTitle()
                        ForEach(store.nutrition.snacks, id: \.name) { s in
                            HStack { Text(s.name); Spacer(); Text(s.info).font(.footnote).foregroundStyle(Color.mut) }
                        }
                    }
                    .card()
                }
                .padding(16)
            }
            .background(Color.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $recipe) { m in RecipeSheet(meal: m).environmentObject(store) }
            .sheet(item: $picking) { m in MealPickSheet(meal: m).environmentObject(store) }
            .sheet(isPresented: $showShopping) { ShoppingSheet(from: day).environmentObject(store) }
        }
    }

    private func macro(_ name: String, _ v: Int, _ goal: Int, _ unit: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.subheadline).frame(width: 110, alignment: .leading)
            ProgressView(value: Double(min(v, goal)), total: Double(max(goal, 1))).tint(c)
            Text("\(v) / \(goal) \(unit)").font(.caption).foregroundStyle(Color.mut).frame(width: 96, alignment: .trailing)
        }
    }

    private func mealCard(_ m: PlannedMeal) -> some View {
        let eaten = store.s.eaten.contains(m.key)
        return VStack(alignment: .leading, spacing: 10) {
            if FoodPhoto.has(m.recipe) {
                Button { recipe = m } label: {
                    FoodPhoto(recipe: m.recipe, height: 190)
                        .overlay(alignment: .topLeading) {
                            Text("\(m.slot.name) · \(m.slot.time) Uhr").font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial, in: Capsule()).padding(10)
                        }
                        .overlay(alignment: .topTrailing) {
                            Text("⏱ \(m.recipe.minutes) Min.").font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial, in: Capsule()).padding(10)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if eaten {
                                Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(Color.lime)
                                    .background(Circle().fill(.black)).padding(10)
                            }
                        }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text("\(m.slot.name) · \(m.slot.time) Uhr").font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.card2, in: Capsule())
                    Spacer()
                    Text("⏱ \(m.recipe.minutes) Min.").font(.caption).foregroundStyle(Color.mut)
                }
            }
            HStack(spacing: 14) {
                if !FoodPhoto.has(m.recipe) { Plate(emoji: m.recipe.emoji) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.recipe.name).font(.headline)
                    Text("\(m.kcal) kcal · \(m.protein) g Eiweiß · \(m.carbs) g KH").font(.footnote).foregroundStyle(Color.mut)
                    HStack(spacing: 4) {
                        ForEach(m.recipe.devices, id: \.self) { d in
                            Text(d).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.card2, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button { store.toggleEaten(m); Haptics.tap() } label: {
                    Label(eaten ? "Gegessen" : "Gegessen?", systemImage: eaten ? "checkmark.circle.fill" : "circle")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(eaten ? Color.black : .white)
                .background(eaten ? Color.lime : Color.card2, in: Capsule())
                Button("Rezept") { recipe = m }.font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.card2, in: Capsule())
                Button("Tauschen") { picking = m }.font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.card2, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .card()
    }
}

struct Plate: View {
    let emoji: [String]
    var size: CGFloat = 76
    var body: some View {
        ZStack {
            Circle().fill(Color.card2)
            Circle().fill(Color.card).padding(size * 0.12)
            Text(emoji.first ?? "🍽").font(.system(size: size * 0.32))
            if emoji.count > 1 { Text(emoji[1]).font(.system(size: size * 0.18)).offset(x: -size * 0.2, y: -size * 0.18) }
            if emoji.count > 2 { Text(emoji[2]).font(.system(size: size * 0.18)).offset(x: size * 0.2, y: size * 0.2) }
        }
        .frame(width: size, height: size)
    }
}

/// Echtes Foto eines Gerichts (Assets: Food/food_<id>)
struct FoodPhoto: View {
    let recipe: Recipe
    var height: CGFloat = 190

    static func has(_ r: Recipe) -> Bool { UIImage(named: "food_" + r.id) != nil }

    var body: some View {
        Color.card2
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay { Image("food_" + recipe.id).resizable().scaledToFill() }
            .clipShape(RoundedRectangle(cornerRadius: height < 80 ? 10 : 16, style: .continuous))
    }
}

struct ShiftChip: View {
    let kind: String
    static func short(_ k: String) -> String { ["F": "frei", "F1": "frei", "D": "Spät", "N": "F/N"][k] ?? "" }
    var body: some View {
        let text = NutritionData.shared.kindNames[kind] ?? kind
        let color: Color = kind == "N" ? .purple : kind == "D" ? .yellow : .green
        Text(text).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color).background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct RecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if FoodPhoto.has(meal.recipe) {
                        FoodPhoto(recipe: meal.recipe, height: 260)
                        Text("Beispielfoto – so ungefähr sieht deine Portion aus.").font(.caption2).foregroundStyle(Color.mut)
                    }
                    HStack(spacing: 14) {
                        if !FoodPhoto.has(meal.recipe) { Plate(emoji: meal.recipe.emoji, size: 90) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(meal.kcal) kcal").font(.sport(30))
                            Text("\(meal.protein) g Eiweiß · \(meal.carbs) g KH · \(meal.fat) g Fett").font(.footnote).foregroundStyle(Color.mut)
                            Text("⏱ \(meal.recipe.minutes) Min. · \(meal.recipe.devices.joined(separator: ", "))").font(.footnote).foregroundStyle(Color.mut)
                        }
                    }
                    Text("Zutaten für 1 Portion").sectionTitle()
                    VStack(spacing: 8) {
                        ForEach(Array(meal.ingredients.enumerated()), id: \.offset) { _, i in
                            HStack {
                                Text(i.name).foregroundStyle(i.qty > 0 ? Color.white : Color.mut)
                                Spacer()
                                Text(i.qty > 0 ? Nutrition.format(i.qty, i.unit) : "nach Geschmack")
                                    .fontWeight(.semibold).foregroundStyle(i.qty > 0 ? Color.white : Color.mut)
                            }
                        }
                    }
                    .card()
                    Text("Zubereitung").sectionTitle()
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(meal.recipe.steps.enumerated()), id: \.offset) { n, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(n + 1)").font(.footnote.weight(.bold)).foregroundStyle(.black)
                                    .frame(width: 24, height: 24).background(Color.lime, in: Circle())
                                Text(step).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .card()
                    Text("Die Mengen sind auf dein Kalorienziel für diese Mahlzeit angepasst. Nährwerte sind Schätzungen.")
                        .font(.footnote).foregroundStyle(Color.mut)
                }
                .padding(16)
            }
            .background(Color.bg)
            .navigationTitle(meal.recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
        }
    }
}

struct MealPickSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.pool(for: meal)) { r in
                    Button {
                        store.s.mealPicks[meal.key] = r.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            if FoodPhoto.has(r) {
                                FoodPhoto(recipe: r, height: 50).frame(width: 66)
                            } else {
                                Plate(emoji: r.emoji, size: 50)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).foregroundStyle(.white)
                                Text("ca. \(Int(Double(r.kcal) * meal.factor)) kcal · \(r.minutes) Min. · \(r.devices.joined(separator: ", "))")
                                    .font(.caption).foregroundStyle(Color.mut)
                            }
                            Spacer()
                            if r.id == meal.recipe.id { Image(systemName: "checkmark").foregroundStyle(Color.lime) }
                        }
                    }
                    .listRowBackground(Color.card)
                }
                Button("Vorschlag des Coaches verwenden") {
                    store.s.mealPicks[meal.key] = nil
                    dismiss()
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("\(meal.slot.name) wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Abbrechen") { dismiss() } } }
        }
    }
}

struct ShoppingSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let from: Date
    @State private var checked: Set<String> = []
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.shoppingList(from: from)) { item in
                        Button {
                            if checked.contains(item.name) { checked.remove(item.name) } else { checked.insert(item.name) }
                        } label: {
                            HStack {
                                Image(systemName: checked.contains(item.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(item.name) ? Color.lime : Color.mut)
                                Text(item.name).strikethrough(checked.contains(item.name)).foregroundStyle(.white)
                                Spacer()
                                Text(item.text).fontWeight(.semibold).foregroundStyle(.white)
                            }
                        }
                        .listRowBackground(Color.card)
                    }
                } footer: {
                    Text("7 Tage ab \(DateUtil.format(from, "dMMMM")). Gewürze, Salz und Öl sind nicht enthalten.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Einkaufsliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: store.shoppingList(from: from).map { "• \($0.name): \($0.text)" }.joined(separator: "\n")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
            }
        }
    }
}
