import Foundation

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Very active"
        case .veryActive: "Athlete"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Desk job, little exercise"
        case .light: "Exercise 1–3 days/week"
        case .moderate: "Exercise 3–5 days/week"
        case .active: "Hard exercise 6–7 days/week"
        case .veryActive: "Physical job or 2× training/day"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

enum WeightGoal: String, CaseIterable, Identifiable {
    case lose, loseSlowly, maintain, gain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: "Lose weight"
        case .loseSlowly: "Lose slowly"
        case .maintain: "Maintain"
        case .gain: "Build muscle"
        }
    }

    var detail: String {
        switch self {
        case .lose: "About 0.5 kg per week"
        case .loseSlowly: "About 0.25 kg per week"
        case .maintain: "Keep your current weight"
        case .gain: "Lean surplus for muscle gain"
        }
    }

    var calorieDelta: Double {
        switch self {
        case .lose: -500
        case .loseSlowly: -250
        case .maintain: 0
        case .gain: 300
        }
    }

    var proteinPerKg: Double {
        switch self {
        case .lose, .loseSlowly: 2.0
        case .maintain: 1.6
        case .gain: 1.8
        }
    }
}

/// Mifflin–St Jeor BMR → TDEE → calorie & macro targets.
struct GoalPlan {
    let bmr: Double
    let tdee: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    static func calculate(sex: BiologicalSex, age: Int, heightCm: Double, weightKg: Double,
                          activity: ActivityLevel, goal: WeightGoal) -> GoalPlan {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        let bmr = base + (sex == .male ? 5 : -161)
        let tdee = bmr * activity.multiplier
        let floor: Double = sex == .male ? 1500 : 1200
        let calories = (max(tdee + goal.calorieDelta, floor) / 10).rounded() * 10
        let protein = (weightKg * goal.proteinPerKg).rounded()
        let fat = (calories * 0.28 / 9).rounded()
        let carbs = max(((calories - protein * 4 - fat * 9) / 4).rounded(), 50)
        return GoalPlan(bmr: bmr, tdee: tdee, calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}
