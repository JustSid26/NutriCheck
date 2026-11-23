import Foundation
import SwiftData

/// Launch arguments for development & screenshots (DEBUG builds only):
///   -seedSampleData        fills the last week with example meals
///   -initialTab <0|1|2|3>  opens Today / Assistant / History / Settings
///   -showSampleResult      opens a sample scan result
///   -chatPrompt "<text>"   sends this message to the Assistant on launch (if the chat is empty)
///   -resetAllData          deletes all logs and chats on launch
enum DebugSupport {
    static var initialTab: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "initialTab")
        #else
        return 0
        #endif
    }

    static var showSampleResult: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showSampleResult")
        #else
        return false
        #endif
    }

    #if DEBUG
    @MainActor
    static func prepare(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments
        let context = container.mainContext
        if args.contains("-resetAllData") {
            try? context.delete(model: FoodEntry.self)
            try? context.delete(model: ExerciseEntry.self)
            try? context.delete(model: ChatMessage.self)
            try? context.save()
        }
        guard args.contains("-seedSampleData") else { return }
        try? context.delete(model: FoodEntry.self)
        SampleData.seed(into: context)
        try? context.save()
    }
    #endif
}

#if DEBUG
@MainActor
enum SampleData {
    static func nutrients(_ kcal: Double, _ p: Double, _ c: Double, _ f: Double,
                          fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, caffeine: Double? = nil) -> Nutrients {
        var n = Nutrients.zero
        n.calories = kcal; n.proteinG = p; n.carbsG = c; n.fatG = f
        n.fiberG = fiber; n.sugarG = sugar; n.sodiumMg = sodium; n.caffeineMg = caffeine
        n.saturatedFatG = (f * 0.35).rounded()
        n.cholesterolMg = 20
        n.calciumMg = 80; n.ironMg = 2.1; n.potassiumMg = 320
        return n
    }

    static func analysis(_ name: String, _ category: FoodCategory, _ serving: String, _ n: Nutrients,
                         items: [FoodItem] = [], score: Int = 6, tags: [String] = [], insights: [String] = []) -> NutritionAnalysis {
        NutritionAnalysis(
            isFood: true, notFoodReason: nil, inputType: .foodPhoto, name: name,
            summary: "A typical serving of \(name.lowercased()).", category: category,
            items: items, servingDescription: serving, estimatedWeightGrams: nil, servingsPerContainer: nil,
            nutrients: n, ingredients: [], allergens: [], dietaryTags: tags,
            processingLevel: .minimallyProcessed, glycemicImpact: .medium, healthScore: score,
            confidence: .medium, insights: insights
        )
    }

    static let biryani = NutritionAnalysis(
        isFood: true, notFoodReason: nil, inputType: .foodPhoto,
        name: "Chicken Biryani with Raita",
        summary: "A restaurant-style plate of chicken dum biryani (about 350 g) with a small bowl of cucumber raita.",
        category: .restaurant,
        items: [
            FoodItem(name: "Chicken biryani rice", portion: "1.5 cups (280 g)", calories: 520, proteinG: 16, carbsG: 72, fatG: 18),
            FoodItem(name: "Chicken pieces (bone-in)", portion: "2 pieces (110 g edible)", calories: 210, proteinG: 26, carbsG: 2, fatG: 11),
            FoodItem(name: "Cucumber raita", portion: "1 katori (100 g)", calories: 70, proteinG: 3.5, carbsG: 6, fatG: 3.5),
            FoodItem(name: "Fried onions & ghee", portion: "1 tbsp", calories: 80, proteinG: 0.5, carbsG: 4, fatG: 7),
        ],
        servingDescription: "1 plate (~490 g)", estimatedWeightGrams: 490, servingsPerContainer: nil,
        nutrients: Nutrients(
            calories: 880, proteinG: 46, carbsG: 84, fatG: 39.5, fiberG: 4.5, sugarG: 9, addedSugarG: 1,
            saturatedFatG: 14, transFatG: 0.3, cholesterolMg: 160, sodiumMg: 1650, potassiumMg: 780,
            calciumMg: 190, ironMg: 3.8, vitaminAMcg: 120, vitaminCMg: 9, vitaminDMcg: 0.4, caffeineMg: 0, alcoholG: 0
        ),
        ingredients: ["Basmati rice", "Chicken", "Yogurt", "Onion", "Ghee", "Biryani masala", "Saffron", "Mint", "Cucumber"],
        allergens: ["Milk"],
        dietaryTags: ["high-protein", "high-sodium"],
        processingLevel: .processed, glycemicImpact: .high, healthScore: 5, confidence: .medium,
        insights: [
            "Good protein (46 g) from the chicken, but the ghee and fried onions add about 18 g of fat.",
            "Sodium is about 72% of your daily limit, so keep other meals today lighter on salt.",
            "Tip: swap half the rice for a side salad to cut about 200 kcal and add fiber.",
        ]
    )

    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let meals: [(MealType, NutritionAnalysis, Double)] = [
            (.breakfast, analysis("Masala Oats with Veggies", .homeCooked, "1 bowl (250 g)", nutrients(310, 11, 48, 8, fiber: 7, sugar: 4, sodium: 520), score: 8, tags: ["vegetarian", "high-fiber"]), 1),
            (.breakfast, analysis("Masala Chai", .beverage, "1 cup (150 ml)", nutrients(95, 3, 13, 3.5, fiber: 0, sugar: 12, sodium: 40, caffeine: 40), score: 5), 1),
            (.lunch, biryani, 1),
            (.snack, analysis("Greek Yogurt, Blueberry", .packaged, "1 cup (100 g)", nutrients(105, 9, 13, 2, fiber: 0.5, sugar: 11, sodium: 45), score: 7, tags: ["high-protein"]), 1),
            (.dinner, analysis("Dal Tadka, 2 Rotis & Salad", .homeCooked, "1 plate (~400 g)", nutrients(540, 22, 78, 15, fiber: 14, sugar: 6, sodium: 780), score: 8, tags: ["vegetarian", "high-fiber"]), 1),
        ]

        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            for (index, meal) in meals.enumerated() {
                // Leave dinner off today so the screen looks mid-day; vary other days.
                if dayOffset == 0 && meal.0 == .dinner { continue }
                if dayOffset > 0 && (index + dayOffset) % 4 == 0 { continue }
                let date = cal.date(bySettingHour: meal.0.defaultHour, minute: 10 * index, second: 0, of: day) ?? day
                let servings = dayOffset == 2 && meal.0 == .lunch ? 1.5 : meal.2
                context.insert(FoodEntry(analysis: meal.1, name: meal.1.name, servings: servings,
                                         mealType: meal.0, date: date, imageData: nil, note: nil))
            }
        }
    }
}
#endif
