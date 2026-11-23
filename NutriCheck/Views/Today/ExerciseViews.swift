import SwiftData
import SwiftUI

struct ExerciseRow: View {
    let exercise: ExerciseEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 50, height: 50)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 13.5, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text("−\(exercise.caloriesBurned.kcal)")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let time = exercise.date.formatted(date: .omitted, time: .shortened)
        return exercise.durationMinutes > 0 ? "\(time) · \(exercise.durationMinutes.clean) min" : time
    }
}

/// Quick manual workout logger with a MET-based estimate from the user's weight.
struct ExerciseLogSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var preset: ExercisePreset = ExercisePreset.all[1]
    @State private var customName = ""
    @State private var useCustom = false
    @State private var minutes: Double = 30
    @State private var manualCalories = false
    @State private var calories: Double = 0

    private var estimate: Double {
        ExercisePreset.netCalories(met: preset.met, weightKg: appState.weightKg, minutes: minutes)
    }

    private var finalCalories: Double { manualCalories ? calories : estimate.rounded() }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Activity", selection: $preset) {
                        ForEach(ExercisePreset.all) { p in
                            Label(p.name, systemImage: p.icon).tag(p)
                        }
                    }
                    Toggle("Rename", isOn: $useCustom)
                    if useCustom {
                        TextField("e.g. Evening walk with dog", text: $customName)
                    }
                }

                Section("Duration") {
                    Stepper(value: $minutes, in: 5...600, step: 5) {
                        LabeledContent("Minutes", value: minutes.clean)
                    }
                }

                Section {
                    Toggle("Enter calories myself", isOn: $manualCalories)
                    if manualCalories {
                        HStack {
                            Text("Calories burned")
                            Spacer()
                            TextField("kcal", value: $calories, format: .number.precision(.fractionLength(0)))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text("kcal").foregroundStyle(.secondary)
                        }
                    } else {
                        LabeledContent("Estimated burn") {
                            Text("\(estimate.kcal) kcal")
                                .font(.headline)
                                .foregroundStyle(.orange)
                                .contentTransition(.numericText(value: estimate))
                        }
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text(manualCalories
                         ? "Use the number from your watch or gym machine."
                         : "Estimated from your weight (\(appState.weightKg.clean) kg) and the activity's MET value. Counts only calories above your resting burn.")
                }
            }
            .navigationTitle("Log Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(finalCalories <= 0)
                }
            }
            .onChange(of: manualCalories) { _, manual in
                if manual { calories = estimate.rounded() }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let name = useCustom && !customName.trimmingCharacters(in: .whitespaces).isEmpty
            ? customName.trimmingCharacters(in: .whitespaces)
            : preset.name
        modelContext.insert(ExerciseEntry(name: name, durationMinutes: minutes, caloriesBurned: finalCalories, date: date))
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
