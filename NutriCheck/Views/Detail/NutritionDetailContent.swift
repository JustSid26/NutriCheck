import SwiftUI

/// The full breakdown of an analysis. Used for fresh scan results and for logged entries.
struct NutritionDetailContent: View {
    let analysis: NutritionAnalysis
    let image: UIImage?
    let title: String
    @Binding var servings: Double

    private var totals: Nutrients { analysis.nutrients.scaled(by: servings) }

    var body: some View {
        VStack(spacing: 16) {
            header
            CaloriesCard(analysis: analysis, totals: totals, servings: $servings)
            HealthCard(analysis: analysis)
            if !analysis.items.isEmpty {
                ItemsCard(items: analysis.items, servings: servings)
            }
            NutritionFactsCard(totals: totals, servingText: servingText)
            if !analysis.allergens.isEmpty || !analysis.ingredients.isEmpty {
                IngredientsCard(analysis: analysis)
            }
            if !analysis.insights.isEmpty {
                InsightsCard(insights: analysis.insights)
            }
            Label("AI estimate. Actual values can vary with recipe and portion size. Not medical advice.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var servingText: String {
        servings == 1 ? analysis.servingDescription : "\(servings.clean) × \(analysis.servingDescription)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image {
                Color.clear
                    .frame(height: 230)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(title.isEmpty ? analysis.name : title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if !analysis.summary.isEmpty {
                    Text(analysis.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FlowLayout(spacing: 6) {
                    Chip(text: analysis.category.title, icon: analysis.category.icon, tint: analysis.category.tint)
                    Chip(text: analysis.inputType.title, icon: analysis.inputType.icon, tint: .blue)
                    Chip(text: "\(analysis.confidence.title) confidence", icon: "checkmark.seal.fill", tint: analysis.confidence.color)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Calories & macros

private struct CaloriesCard: View {
    let analysis: NutritionAnalysis
    let totals: Nutrients
    @Binding var servings: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calories")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(totals.calories.kcal)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: totals.calories))
                        Text("kcal")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ServingsStepper(servings: $servings)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Serving: \(analysis.servingDescription)")
                if let grams = analysis.estimatedWeightGrams, grams > 0 {
                    Text("≈ \((grams * servings).clean) g / ml in total")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let perPack = analysis.servingsPerContainer, perPack > 1 {
                HStack {
                    Image(systemName: "shippingbox")
                    Text("\(perPack.clean) servings per pack")
                    Spacer()
                    Button("Whole pack") {
                        withAnimation { servings = perPack }
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            MacroSplitBar(protein: totals.proteinG, carbs: totals.carbsG, fat: totals.fatG)

            HStack(spacing: 10) {
                MacroTile(name: "Protein", grams: totals.proteinG, kcalPerGram: 4, totalKcal: macroKcal, color: .protein)
                MacroTile(name: "Carbs", grams: totals.carbsG, kcalPerGram: 4, totalKcal: macroKcal, color: .carbs)
                MacroTile(name: "Fat", grams: totals.fatG, kcalPerGram: 9, totalKcal: macroKcal, color: .fat)
            }
        }
        .card()
        .animation(.snappy, value: servings)
    }

    private var macroKcal: Double { totals.proteinG * 4 + totals.carbsG * 4 + totals.fatG * 9 }
}

private struct MacroTile: View {
    let name: String
    let grams: Double
    let kcalPerGram: Double
    let totalKcal: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(grams.clean)g")
                .font(.title3.bold())
                .contentTransition(.numericText(value: grams))
            Text(totalKcal > 0 ? "\(Int((grams * kcalPerGram / totalKcal * 100).rounded()))% of kcal" : "–")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ServingsStepper: View {
    @Binding var servings: Double
    private let step = 0.25

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Button {
                    servings = max(step, servings - (servings > 1 ? 0.5 : step))
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 36)
                }
                .disabled(servings <= step)

                Text("\(servings.clean)×")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 48)
                    .contentTransition(.numericText(value: servings))

                Button {
                    servings = min(50, servings + (servings >= 1 ? 0.5 : step))
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
            }
            .font(.subheadline.weight(.bold))
            .background(Color(.tertiarySystemFill), in: Capsule())
            .sensoryFeedback(.selection, trigger: servings)

            Text(servings == 1 ? "serving" : "servings")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Health

private struct HealthCard: View {
    let analysis: NutritionAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                HealthScoreBadge(score: analysis.healthScore, size: 68)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Health score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(analysis.healthVerdict)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Chip(text: analysis.processingLevel.title, tint: analysis.processingLevel.color)
                        if analysis.glycemicImpact != .notApplicable {
                            Chip(text: "\(analysis.glycemicImpact.title) GI", tint: analysis.glycemicImpact.color)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if !analysis.dietaryTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(analysis.dietaryTags, id: \.self) { tag in
                        Chip(text: tag.capitalized, tint: tagColor(tag))
                    }
                }
            }
        }
        .card()
    }

    private func tagColor(_ tag: String) -> Color {
        let t = tag.lowercased()
        if ["high-sugar", "high-sodium", "deep-fried", "fried", "high sugar", "high sodium"].contains(where: t.contains) { return .orange }
        return .accentColor
    }
}

// MARK: - Items

private struct ItemsCard: View {
    let items: [FoodItem]
    let servings: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "What's in it", icon: "list.bullet.rectangle.portrait.fill")
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                        Text(item.portion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            macro("P", item.proteinG * servings, .protein)
                            macro("C", item.carbsG * servings, .carbs)
                            macro("F", item.fatG * servings, .fat)
                        }
                    }
                    Spacer()
                    Text("\((item.calories * servings).kcal) kcal")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                if index < items.count - 1 { Divider() }
            }
        }
        .card()
    }

    private func macro(_ letter: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(letter) \(value.clean)g")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Nutrition facts label

private struct NutritionFactsCard: View {
    let totals: Nutrients
    let servingText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nutrition Facts")
                .font(.system(size: 30, weight: .black))
            Text("Per \(servingText)")
                .font(.footnote)
                .padding(.bottom, 4)
            rule(8)
            HStack(alignment: .lastTextBaseline) {
                Text("Calories").font(.title3.weight(.heavy))
                Spacer()
                Text(totals.calories.kcal).font(.system(size: 30, weight: .black))
            }
            rule(4)
            HStack {
                Spacer()
                Text("% Daily Value*").font(.caption.bold())
            }
            .padding(.vertical, 3)
            Divider()

            ForEach(NutrientCatalog.facts) { info in
                row(info)
            }

            let micros = NutrientCatalog.micros.filter { $0.value(totals) != nil }
            if !micros.isEmpty {
                rule(8)
                ForEach(micros) { info in row(info) }
            }

            let others = NutrientCatalog.other.filter { ($0.value(totals) ?? 0) > 0 }
            if !others.isEmpty {
                rule(4)
                ForEach(others) { info in row(info) }
            }

            rule(4)
            Text("* The % Daily Value tells you how much a nutrient in a serving contributes to a daily diet. 2,000 calories a day is used for general nutrition advice. Caffeine % is of the 400 mg daily limit.")
                .font(.caption2)
                .padding(.top, 6)
        }
        .fontDesign(.default)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func rule(_ height: CGFloat) -> some View {
        Rectangle().fill(.primary).frame(height: height).padding(.vertical, 2)
    }

    private func row(_ info: NutrientInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(info.name)
                    .fontWeight(info.indented ? .regular : .bold)
                Text(info.value(totals).map { "\($0.clean)\(info.unit)" } ?? "–")
                Spacer()
                if let pct = info.percentDV(for: totals) {
                    Text("\(pct)%")
                        .fontWeight(.bold)
                        .foregroundStyle(pct >= 100 ? Color.red : Color.primary)
                }
            }
            .font(.subheadline)
            .padding(.leading, info.indented ? 16 : 0)
            .padding(.vertical, 5)
            Divider()
        }
    }
}

// MARK: - Ingredients & allergens

private struct IngredientsCard: View {
    let analysis: NutritionAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !analysis.allergens.isEmpty {
                CardTitle(title: "Contains allergens", icon: "exclamationmark.triangle.fill", tint: .red)
                FlowLayout(spacing: 6) {
                    ForEach(analysis.allergens, id: \.self) { allergen in
                        Chip(text: allergen.capitalized, tint: .red)
                    }
                }
            }
            if !analysis.allergens.isEmpty && !analysis.ingredients.isEmpty {
                Divider()
            }
            if !analysis.ingredients.isEmpty {
                CardTitle(
                    title: analysis.inputType == .nutritionLabel ? "Ingredients (from label)" : "Likely ingredients",
                    icon: "leaf.fill"
                )
                Text(analysis.ingredients.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

private struct InsightsCard: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Insights", icon: "sparkles", tint: .purple)
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(insight)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }
}
