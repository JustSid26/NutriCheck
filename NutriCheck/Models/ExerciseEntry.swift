import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var name: String = ""
    var durationMinutes: Double = 0
    var caloriesBurned: Double = 0

    init(name: String, durationMinutes: Double, caloriesBurned: Double, date: Date) {
        self.id = UUID()
        self.name = name
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.date = date
    }
}

/// Common activities with MET values (Compendium of Physical Activities).
struct ExercisePreset: Identifiable, Hashable {
    let name: String
    let met: Double
    let icon: String
    var id: String { name }

    static let all: [ExercisePreset] = [
        ExercisePreset(name: "Walking (easy)", met: 3.0, icon: "figure.walk"),
        ExercisePreset(name: "Walking (brisk)", met: 4.3, icon: "figure.walk.motion"),
        ExercisePreset(name: "Running (8 km/h)", met: 8.3, icon: "figure.run"),
        ExercisePreset(name: "Running (10 km/h)", met: 9.8, icon: "figure.run"),
        ExercisePreset(name: "Cycling (moderate)", met: 6.8, icon: "figure.outdoor.cycle"),
        ExercisePreset(name: "Swimming", met: 6.0, icon: "figure.pool.swim"),
        ExercisePreset(name: "Strength training", met: 5.0, icon: "dumbbell.fill"),
        ExercisePreset(name: "HIIT", met: 8.0, icon: "flame.fill"),
        ExercisePreset(name: "Yoga", met: 2.5, icon: "figure.yoga"),
        ExercisePreset(name: "Dancing", met: 5.0, icon: "figure.dance"),
        ExercisePreset(name: "Badminton", met: 5.5, icon: "figure.badminton"),
        ExercisePreset(name: "Cricket", met: 4.8, icon: "figure.cricket"),
        ExercisePreset(name: "Football", met: 7.0, icon: "figure.soccer"),
        ExercisePreset(name: "Stair climbing", met: 8.8, icon: "figure.stairs"),
        ExercisePreset(name: "Housework", met: 3.3, icon: "house.fill"),
    ]

    /// Net calories above resting: (MET − 1) × kg × hours.
    static func netCalories(met: Double, weightKg: Double, minutes: Double) -> Double {
        max(0, (met - 1) * weightKg * minutes / 60)
    }
}
