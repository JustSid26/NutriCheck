import Foundation
import Observation

struct ModelPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
}

/// App-wide settings: OpenAI credentials (Keychain), profile and daily goals (UserDefaults).
@MainActor
@Observable
final class AppState {
    static let modelPresets: [ModelPreset] = [
        ModelPreset(id: "gpt-5.6-sol", title: "GPT-5.6 Sol", detail: "Most accurate. Best for mixed dishes and hard-to-read labels."),
        ModelPreset(id: "gpt-5.6-luna", title: "GPT-5.6 Luna", detail: "Faster and much cheaper per scan. Great for labels and simple foods."),
    ]
    static let defaultModel = "gpt-5.6-sol"

    private enum Keys {
        static let apiKey = "openai_api_key"
        static let secretsImported = "secrets.imported"
        static let model = "settings.model"
        static let countExercise = "settings.countExercise"
        static let calorieGoal = "goal.calories"
        static let proteinGoal = "goal.protein"
        static let carbsGoal = "goal.carbs"
        static let fatGoal = "goal.fat"
        static let weightKg = "profile.weightKg"
        static let heightCm = "profile.heightCm"
        static let age = "profile.age"
        static let sex = "profile.sex"
        static let activity = "profile.activity"
        static let weightGoal = "profile.goal"
        static let profileComplete = "profile.complete"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    // MARK: OpenAI
    var apiKey: String {
        didSet { KeychainStore.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: Keys.apiKey) }
    }
    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    // MARK: Goals
    var calorieGoal: Double { didSet { defaults.set(calorieGoal, forKey: Keys.calorieGoal) } }
    var proteinGoal: Double { didSet { defaults.set(proteinGoal, forKey: Keys.proteinGoal) } }
    var carbsGoal: Double { didSet { defaults.set(carbsGoal, forKey: Keys.carbsGoal) } }
    var fatGoal: Double { didSet { defaults.set(fatGoal, forKey: Keys.fatGoal) } }
    /// Add calories burned by exercise to the day's budget.
    var countExerciseCalories: Bool { didSet { defaults.set(countExerciseCalories, forKey: Keys.countExercise) } }

    // MARK: Profile
    var weightKg: Double { didSet { defaults.set(weightKg, forKey: Keys.weightKg) } }
    var heightCm: Double { didSet { defaults.set(heightCm, forKey: Keys.heightCm) } }
    var age: Int { didSet { defaults.set(age, forKey: Keys.age) } }
    var sex: BiologicalSex { didSet { defaults.set(sex.rawValue, forKey: Keys.sex) } }
    var activity: ActivityLevel { didSet { defaults.set(activity.rawValue, forKey: Keys.activity) } }
    var weightGoal: WeightGoal { didSet { defaults.set(weightGoal.rawValue, forKey: Keys.weightGoal) } }
    /// True once height/age/sex have been confirmed in the Goal Calculator.
    var profileComplete: Bool { didSet { defaults.set(profileComplete, forKey: Keys.profileComplete) } }

    init() {
        let d = UserDefaults.standard
        var key = KeychainStore.string(for: Keys.apiKey) ?? ""
        if key.isEmpty, !d.bool(forKey: Keys.secretsImported), let bundled = Self.bundledAPIKey() {
            // First launch: import the key from Secrets.plist (personal builds only).
            key = bundled
            KeychainStore.set(bundled, for: Keys.apiKey)
            d.set(true, forKey: Keys.secretsImported)
        }
        apiKey = key
        let storedModel = d.string(forKey: Keys.model)
        // "gpt-5.6" is an alias of Sol; store the full ID so Test Connection can look it up.
        model = (storedModel == nil || storedModel == "gpt-5.6") ? Self.defaultModel : storedModel!

        calorieGoal = d.object(forKey: Keys.calorieGoal) as? Double ?? 2000
        proteinGoal = d.object(forKey: Keys.proteinGoal) as? Double ?? 150
        carbsGoal = d.object(forKey: Keys.carbsGoal) as? Double ?? 200
        fatGoal = d.object(forKey: Keys.fatGoal) as? Double ?? 62
        countExerciseCalories = d.object(forKey: Keys.countExercise) as? Bool ?? true

        weightKg = d.object(forKey: Keys.weightKg) as? Double ?? 112
        heightCm = d.object(forKey: Keys.heightCm) as? Double ?? 175
        age = d.object(forKey: Keys.age) as? Int ?? 30
        sex = d.string(forKey: Keys.sex).flatMap(BiologicalSex.init(rawValue:)) ?? .male
        activity = d.string(forKey: Keys.activity).flatMap(ActivityLevel.init(rawValue:)) ?? .light
        weightGoal = d.string(forKey: Keys.weightGoal).flatMap(WeightGoal.init(rawValue:)) ?? .lose
        profileComplete = d.bool(forKey: Keys.profileComplete)
    }

    var trimmedAPIKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasAPIKey: Bool { !trimmedAPIKey.isEmpty }

    var resolvedModel: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? Self.defaultModel : m
    }

    func makeService() -> OpenAIService {
        OpenAIService(apiKey: trimmedAPIKey, model: resolvedModel)
    }

    /// Calories available today: goal (+ exercise if enabled).
    func budget(burned: Double) -> Double {
        calorieGoal + (countExerciseCalories ? burned : 0)
    }

    private static func bundledAPIKey() -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let key = dict["OPENAI_API_KEY"] as? String else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
