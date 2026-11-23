import Foundation

/// Display metadata for nutrients, with FDA daily values (2,000 kcal reference diet).
struct NutrientInfo: Identifiable {
    let id: String
    let name: String
    let unit: String
    let dailyValue: Double?
    let indented: Bool
    let value: (Nutrients) -> Double?

    init(_ id: String, _ name: String, _ unit: String, dv: Double?, indented: Bool = false, value: @escaping (Nutrients) -> Double?) {
        self.id = id
        self.name = name
        self.unit = unit
        self.dailyValue = dv
        self.indented = indented
        self.value = value
    }

    func percentDV(for nutrients: Nutrients) -> Int? {
        guard let dailyValue, dailyValue > 0, let v = value(nutrients) else { return nil }
        return Int((v / dailyValue * 100).rounded())
    }
}

enum NutrientCatalog {
    /// The main "Nutrition Facts" rows.
    static var facts: [NutrientInfo] {
        [
            NutrientInfo("fat", "Total Fat", "g", dv: 78) { $0.fatG },
            NutrientInfo("satFat", "Saturated Fat", "g", dv: 20, indented: true) { $0.saturatedFatG },
            NutrientInfo("transFat", "Trans Fat", "g", dv: nil, indented: true) { $0.transFatG },
            NutrientInfo("cholesterol", "Cholesterol", "mg", dv: 300) { $0.cholesterolMg },
            NutrientInfo("sodium", "Sodium", "mg", dv: 2300) { $0.sodiumMg },
            NutrientInfo("carbs", "Total Carbohydrate", "g", dv: 275) { $0.carbsG },
            NutrientInfo("fiber", "Dietary Fiber", "g", dv: 28, indented: true) { $0.fiberG },
            NutrientInfo("sugar", "Total Sugars", "g", dv: nil, indented: true) { $0.sugarG },
            NutrientInfo("addedSugar", "Added Sugars", "g", dv: 50, indented: true) { $0.addedSugarG },
            NutrientInfo("protein", "Protein", "g", dv: 50) { $0.proteinG },
        ]
    }

    /// Vitamins & minerals.
    static var micros: [NutrientInfo] {
        [
            NutrientInfo("vitD", "Vitamin D", "mcg", dv: 20) { $0.vitaminDMcg },
            NutrientInfo("calcium", "Calcium", "mg", dv: 1300) { $0.calciumMg },
            NutrientInfo("iron", "Iron", "mg", dv: 18) { $0.ironMg },
            NutrientInfo("potassium", "Potassium", "mg", dv: 4700) { $0.potassiumMg },
            NutrientInfo("vitA", "Vitamin A", "mcg", dv: 900) { $0.vitaminAMcg },
            NutrientInfo("vitC", "Vitamin C", "mg", dv: 90) { $0.vitaminCMg },
        ]
    }

    /// Stimulants etc. Caffeine "DV" is the 400 mg/day safe-limit guidance for adults.
    static var other: [NutrientInfo] {
        [
            NutrientInfo("caffeine", "Caffeine", "mg", dv: 400) { $0.caffeineMg },
            NutrientInfo("alcohol", "Alcohol", "g", dv: nil) { $0.alcoholG },
        ]
    }
}
