import Foundation
import SwiftData

/// Builds the plain-text snapshot of the user's data that the assistant sees on every message.
@MainActor
enum AssistantContext {
    static func build(modelContext: ModelContext, appState: AppState, now: Date = .now) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today

        let foods = (try? modelContext.fetch(FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.date >= weekStart },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        let exercises = (try? modelContext.fetch(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { $0.date >= weekStart },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []

        let todaysFoods = foods.filter { cal.isDate($0.date, inSameDayAs: now) }
        let todaysExercise = exercises.filter { cal.isDate($0.date, inSameDayAs: now) }
        let eaten = todaysFoods.reduce(Nutrients.zero) { $0 + $1.totalNutrients }
        let burned = todaysExercise.reduce(0) { $0 + $1.caloriesBurned }
        let budget = appState.budget(burned: burned)

        var lines: [String] = []
        lines.append("=== USER SNAPSHOT (live data from the app) ===")
        lines.append("Now: \(now.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute()))")

        // Profile
        var profile = "Weight \(appState.weightKg.clean) kg"
        if appState.profileComplete {
            profile += "; height \(appState.heightCm.clean) cm; age \(appState.age); sex \(appState.sex.rawValue)"
            profile += "; activity: \(appState.activity.title.lowercased()) (\(appState.activity.detail.lowercased()))"
            profile += "; goal: \(appState.weightGoal.title.lowercased())"
        } else {
            profile += "; height, age, sex, activity level and weight goal not provided yet"
        }
        lines.append("Profile: \(profile).")

        lines.append("Daily goals: \(appState.calorieGoal.kcal) kcal; protein \(appState.proteinGoal.clean) g; carbs \(appState.carbsGoal.clean) g; fat \(appState.fatGoal.clean) g.")
        lines.append("Exercise calories count toward the daily budget: \(appState.countExerciseCalories ? "yes" : "no").")

        // Today
        lines.append("")
        lines.append("TODAY: eaten \(eaten.calories.kcal) kcal (protein \(eaten.proteinG.clean) g, carbs \(eaten.carbsG.clean) g, fat \(eaten.fatG.clean) g\(optional(", fiber", eaten.fiberG, "g"))\(optional(", sugar", eaten.sugarG, "g"))\(optional(", sodium", eaten.sodiumMg, "mg"))\(optional(", caffeine", eaten.caffeineMg, "mg"))).")
        lines.append("Exercise burned today: \(burned.kcal) kcal. Calories left today: \((budget - eaten.calories).kcal) kcal. Protein left: \(max(0, appState.proteinGoal - eaten.proteinG).clean) g.")

        lines.append("Today's food log:")
        if todaysFoods.isEmpty {
            lines.append("- (nothing logged yet)")
        } else {
            for entry in todaysFoods {
                let amount = entry.servings == 1 ? entry.servingDescription : "\(entry.servings.clean) × \(entry.servingDescription)"
                lines.append("- \(entry.date.formatted(date: .omitted, time: .shortened)) \(entry.mealType.title): \(entry.name) (\(amount)): \(entry.calories.kcal) kcal, P \(entry.protein.clean) g, C \(entry.carbs.clean) g, F \(entry.fat.clean) g")
            }
        }

        lines.append("Today's exercise:")
        if todaysExercise.isEmpty {
            lines.append("- (none logged)")
        } else {
            for ex in todaysExercise {
                lines.append("- \(ex.date.formatted(date: .omitted, time: .shortened)) \(ex.name), \(ex.durationMinutes.clean) min: \(ex.caloriesBurned.kcal) kcal")
            }
        }

        // Last 7 days
        lines.append("")
        lines.append("Last 7 days (kcal eaten / kcal burned / protein g):")
        for offset in (1...6).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayFoods = foods.filter { cal.isDate($0.date, inSameDayAs: day) }
            let dayEx = exercises.filter { cal.isDate($0.date, inSameDayAs: day) }
            let label = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            if dayFoods.isEmpty && dayEx.isEmpty {
                lines.append("- \(label): nothing logged")
            } else {
                let kcal = dayFoods.reduce(0) { $0 + $1.calories }
                let protein = dayFoods.reduce(0) { $0 + $1.protein }
                let burnedDay = dayEx.reduce(0) { $0 + $1.caloriesBurned }
                lines.append("- \(label): \(kcal.kcal) / \(burnedDay.kcal) / \(protein.clean)")
            }
        }
        lines.append("=== END SNAPSHOT ===")
        return lines.joined(separator: "\n")
    }

    private static func optional(_ label: String, _ value: Double?, _ unit: String) -> String {
        guard let value, value > 0 else { return "" }
        return "\(label) \(value.clean) \(unit)"
    }
}
