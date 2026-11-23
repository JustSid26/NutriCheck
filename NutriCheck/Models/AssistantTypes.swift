import Foundation

enum ChatRole: String, Codable, Sendable {
    case user, assistant
}

struct ChatTurn: Sendable {
    let role: ChatRole
    let text: String
}

/// The assistant's structured reply: text plus optional one-tap actions.
struct AssistantReply: Codable, Sendable {
    var reply: String
    var actions: [AssistantAction]
}

enum AssistantActionKind: String, FallbackStringEnum {
    case logExercise = "log_exercise"
    case setGoals = "set_goals"
    case updateWeight = "update_weight"
    case unknown
    static var fallback: AssistantActionKind { .unknown }
}

enum AssistantActionStatus: String, Codable, Sendable {
    case applied, dismissed
}

/// An action the assistant proposes. Nothing happens until the user taps it.
struct AssistantAction: Codable, Hashable, Sendable {
    var type: AssistantActionKind
    var exerciseName: String?
    var durationMinutes: Double?
    var caloriesBurned: Double?
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var weightKg: Double?
    /// Set locally once the user applies or dismisses it (not part of the AI schema).
    var status: AssistantActionStatus?

    var isValid: Bool {
        switch type {
        case .logExercise: (caloriesBurned ?? 0) > 0
        case .setGoals: (calories ?? 0) > 0
        case .updateWeight: (weightKg ?? 0) > 20
        case .unknown: false
        }
    }

    /// Short description used when replaying history to the model.
    var summary: String {
        switch type {
        case .logExercise:
            "log exercise \(exerciseName ?? "workout"), \(Int(durationMinutes ?? 0)) min, \(Int(caloriesBurned ?? 0)) kcal"
        case .setGoals:
            "set goals \(Int(calories ?? 0)) kcal, P \(Int(proteinG ?? 0)) g, C \(Int(carbsG ?? 0)) g, F \(Int(fatG ?? 0)) g"
        case .updateWeight:
            "update weight to \(weightKg ?? 0) kg"
        case .unknown:
            "unknown"
        }
    }
}
