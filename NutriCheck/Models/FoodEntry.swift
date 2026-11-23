import Foundation
import SwiftData
import UIKit

/// A logged food. Nutrient values are stored per one serving ("base") and multiplied by `servings`.
@Model
final class FoodEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var mealTypeRaw: String = MealType.snack.rawValue
    var categoryRaw: String = FoodCategory.other.rawValue
    var name: String = ""
    var servingDescription: String = ""
    var servings: Double = 1
    var baseCalories: Double = 0
    var baseProtein: Double = 0
    var baseCarbs: Double = 0
    var baseFat: Double = 0
    var note: String?
    @Attribute(.externalStorage) var imageData: Data?
    /// The full AI analysis, JSON-encoded.
    var analysisData: Data?

    init(
        analysis: NutritionAnalysis,
        name: String,
        servings: Double,
        mealType: MealType,
        date: Date,
        imageData: Data?,
        note: String?
    ) {
        self.id = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.categoryRaw = analysis.category.rawValue
        self.name = name
        self.servingDescription = analysis.servingDescription
        self.servings = servings
        self.baseCalories = analysis.nutrients.calories
        self.baseProtein = analysis.nutrients.proteinG
        self.baseCarbs = analysis.nutrients.carbsG
        self.baseFat = analysis.nutrients.fatG
        self.imageData = imageData
        self.note = note
        self.analysisData = try? JSONEncoder().encode(analysis)
    }
}

extension FoodEntry {
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var category: FoodCategory { FoodCategory(rawValue: categoryRaw) ?? .other }

    var analysis: NutritionAnalysis? {
        guard let analysisData else { return nil }
        return try? JSONDecoder().decode(NutritionAnalysis.self, from: analysisData)
    }

    var calories: Double { baseCalories * servings }
    var protein: Double { baseProtein * servings }
    var carbs: Double { baseCarbs * servings }
    var fat: Double { baseFat * servings }

    /// All nutrients for the logged amount (servings applied).
    var totalNutrients: Nutrients {
        if let analysis { return analysis.nutrients.scaled(by: servings) }
        var n = Nutrients.zero
        n.calories = calories; n.proteinG = protein; n.carbsG = carbs; n.fatG = fat
        return n
    }

    var uiImage: UIImage? { imageData.flatMap(UIImage.init(data:)) }

    /// Creates a copy (used for "Log again").
    func duplicate(at date: Date, mealType: MealType) -> FoodEntry? {
        guard let analysis else { return nil }
        return FoodEntry(
            analysis: analysis, name: name, servings: servings,
            mealType: mealType, date: date, imageData: imageData, note: note
        )
    }
}

enum MealType: String, CaseIterable, Identifiable, Codable, Sendable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snacks"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    var defaultHour: Int {
        switch self {
        case .breakfast: 8
        case .lunch: 13
        case .dinner: 20
        case .snack: 16
        }
    }

    static func suggested(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 18..<23: return .dinner
        default: return .snack
        }
    }
}
