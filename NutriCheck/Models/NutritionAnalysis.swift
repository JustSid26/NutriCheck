import Foundation
import SwiftUI

/// The structured result returned by the AI for one photo / label / description.
/// One "serving" is whatever the analysis describes in `servingDescription`
/// (the whole portion in a photo, or the label's serving for packaged food).
struct NutritionAnalysis: Codable, Hashable, Sendable {
    var isFood: Bool
    var notFoodReason: String?
    var inputType: InputType
    var name: String
    var summary: String
    var category: FoodCategory
    var items: [FoodItem]
    var servingDescription: String
    var estimatedWeightGrams: Double?
    var servingsPerContainer: Double?
    var nutrients: Nutrients
    var ingredients: [String]
    var allergens: [String]
    var dietaryTags: [String]
    var processingLevel: ProcessingLevel
    var glycemicImpact: GlycemicImpact
    var healthScore: Int
    var confidence: Confidence
    var insights: [String]
}

struct FoodItem: Codable, Hashable, Sendable {
    var name: String
    var portion: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}

struct Nutrients: Codable, Hashable, Sendable {
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double?
    var sugarG: Double?
    var addedSugarG: Double?
    var saturatedFatG: Double?
    var transFatG: Double?
    var cholesterolMg: Double?
    var sodiumMg: Double?
    var potassiumMg: Double?
    var calciumMg: Double?
    var ironMg: Double?
    var vitaminAMcg: Double?
    var vitaminCMg: Double?
    var vitaminDMcg: Double?
    var caffeineMg: Double?
    var alcoholG: Double?

    static let zero = Nutrients(
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        fiberG: nil, sugarG: nil, addedSugarG: nil, saturatedFatG: nil, transFatG: nil,
        cholesterolMg: nil, sodiumMg: nil, potassiumMg: nil, calciumMg: nil, ironMg: nil,
        vitaminAMcg: nil, vitaminCMg: nil, vitaminDMcg: nil, caffeineMg: nil, alcoholG: nil
    )

    func scaled(by factor: Double) -> Nutrients {
        func s(_ value: Double?) -> Double? { value.map { $0 * factor } }
        return Nutrients(
            calories: calories * factor, proteinG: proteinG * factor, carbsG: carbsG * factor, fatG: fatG * factor,
            fiberG: s(fiberG), sugarG: s(sugarG), addedSugarG: s(addedSugarG), saturatedFatG: s(saturatedFatG),
            transFatG: s(transFatG), cholesterolMg: s(cholesterolMg), sodiumMg: s(sodiumMg),
            potassiumMg: s(potassiumMg), calciumMg: s(calciumMg), ironMg: s(ironMg),
            vitaminAMcg: s(vitaminAMcg), vitaminCMg: s(vitaminCMg), vitaminDMcg: s(vitaminDMcg),
            caffeineMg: s(caffeineMg), alcoholG: s(alcoholG)
        )
    }

    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        func add(_ x: Double?, _ y: Double?) -> Double? {
            if x == nil && y == nil { return nil }
            return (x ?? 0) + (y ?? 0)
        }
        return Nutrients(
            calories: a.calories + b.calories, proteinG: a.proteinG + b.proteinG,
            carbsG: a.carbsG + b.carbsG, fatG: a.fatG + b.fatG,
            fiberG: add(a.fiberG, b.fiberG), sugarG: add(a.sugarG, b.sugarG),
            addedSugarG: add(a.addedSugarG, b.addedSugarG), saturatedFatG: add(a.saturatedFatG, b.saturatedFatG),
            transFatG: add(a.transFatG, b.transFatG), cholesterolMg: add(a.cholesterolMg, b.cholesterolMg),
            sodiumMg: add(a.sodiumMg, b.sodiumMg), potassiumMg: add(a.potassiumMg, b.potassiumMg),
            calciumMg: add(a.calciumMg, b.calciumMg), ironMg: add(a.ironMg, b.ironMg),
            vitaminAMcg: add(a.vitaminAMcg, b.vitaminAMcg), vitaminCMg: add(a.vitaminCMg, b.vitaminCMg),
            vitaminDMcg: add(a.vitaminDMcg, b.vitaminDMcg), caffeineMg: add(a.caffeineMg, b.caffeineMg),
            alcoholG: add(a.alcoholG, b.alcoholG)
        )
    }
}

// MARK: - Enums (decode unknown values to a safe fallback)

protocol FallbackStringEnum: RawRepresentable, CaseIterable, Codable, Sendable where RawValue == String {
    static var fallback: Self { get }
}

extension FallbackStringEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.fallback
    }
}

enum InputType: String, FallbackStringEnum {
    case foodPhoto = "food_photo"
    case nutritionLabel = "nutrition_label"
    case packagedProduct = "packaged_product"
    case textDescription = "text_description"
    static var fallback: InputType { .foodPhoto }

    var title: String {
        switch self {
        case .foodPhoto: "Photo estimate"
        case .nutritionLabel: "Read from label"
        case .packagedProduct: "Product match"
        case .textDescription: "From description"
        }
    }

    var icon: String {
        switch self {
        case .foodPhoto: "camera.fill"
        case .nutritionLabel: "doc.text.viewfinder"
        case .packagedProduct: "barcode.viewfinder"
        case .textDescription: "text.bubble.fill"
        }
    }
}

enum FoodCategory: String, FallbackStringEnum {
    case homeCooked = "home_cooked"
    case restaurant
    case fastFood = "fast_food"
    case packaged
    case beverage
    case fruitVegetable = "fruit_vegetable"
    case snack
    case dessert
    case other
    static var fallback: FoodCategory { .other }

    var title: String {
        switch self {
        case .homeCooked: "Home-cooked"
        case .restaurant: "Restaurant"
        case .fastFood: "Fast food"
        case .packaged: "Packaged"
        case .beverage: "Drink"
        case .fruitVegetable: "Fruit & veg"
        case .snack: "Snack"
        case .dessert: "Dessert"
        case .other: "Food"
        }
    }

    var icon: String {
        switch self {
        case .homeCooked: "frying.pan.fill"
        case .restaurant: "fork.knife"
        case .fastFood: "takeoutbag.and.cup.and.straw.fill"
        case .packaged: "shippingbox.fill"
        case .beverage: "cup.and.saucer.fill"
        case .fruitVegetable: "carrot.fill"
        case .snack: "popcorn.fill"
        case .dessert: "birthday.cake.fill"
        case .other: "fork.knife.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .homeCooked: .orange
        case .restaurant: .indigo
        case .fastFood: .red
        case .packaged: .brown
        case .beverage: .cyan
        case .fruitVegetable: .green
        case .snack: .yellow
        case .dessert: .pink
        case .other: .gray
        }
    }
}

enum Confidence: String, FallbackStringEnum {
    case low, medium, high
    static var fallback: Confidence { .medium }

    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low: .orange
        case .medium: .yellow
        case .high: .green
        }
    }
}

enum ProcessingLevel: String, FallbackStringEnum {
    case unprocessed
    case minimallyProcessed = "minimally_processed"
    case processed
    case ultraProcessed = "ultra_processed"
    static var fallback: ProcessingLevel { .processed }

    var title: String {
        switch self {
        case .unprocessed: "Whole food"
        case .minimallyProcessed: "Minimally processed"
        case .processed: "Processed"
        case .ultraProcessed: "Ultra-processed"
        }
    }

    var color: Color {
        switch self {
        case .unprocessed: .green
        case .minimallyProcessed: .mint
        case .processed: .orange
        case .ultraProcessed: .red
        }
    }
}

enum GlycemicImpact: String, FallbackStringEnum {
    case low, medium, high
    case notApplicable = "not_applicable"
    static var fallback: GlycemicImpact { .notApplicable }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .notApplicable: "N/A"
        }
    }

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        case .notApplicable: .gray
        }
    }
}

extension NutritionAnalysis {
    /// Score → color / label helpers.
    var healthColor: Color { Self.healthColor(for: healthScore) }

    static func healthColor(for score: Int) -> Color {
        switch score {
        case 8...: .green
        case 6..<8: .mint
        case 4..<6: .orange
        default: .red
        }
    }

    var healthVerdict: String {
        switch healthScore {
        case 9...: "Excellent choice"
        case 7..<9: "Good choice"
        case 5..<7: "Fine in moderation"
        case 3..<5: "Treat occasionally"
        default: "Indulgence"
        }
    }
}
