import SwiftUI

struct GoalCalculatorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var plan: GoalPlan {
        GoalPlan.calculate(sex: appState.sex, age: appState.age, heightCm: appState.heightCm,
                           weightKg: appState.weightKg, activity: appState.activity, goal: appState.weightGoal)
    }

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("About you") {
                Picker("Sex", selection: $state.sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Stepper(value: $state.age, in: 13...100) {
                    LabeledContent("Age", value: "\(appState.age) years")
                }
                measurementRow("Height", value: $state.heightCm, unit: "cm")
                measurementRow("Weight", value: $state.weightKg, unit: "kg")
            }

            Section("Activity") {
                Picker("Activity", selection: $state.activity) {
                    ForEach(ActivityLevel.allCases) { level in
                        VStack(alignment: .leading) {
                            Text(level.title)
                            Text(level.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Goal") {
                Picker("Goal", selection: $state.weightGoal) {
                    ForEach(WeightGoal.allCases) { g in
                        VStack(alignment: .leading) {
                            Text(g.title)
                            Text(g.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(g)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                LabeledContent("Resting burn (BMR)", value: "\(plan.bmr.kcal) kcal")
                LabeledContent("Maintenance (TDEE)", value: "\(plan.tdee.kcal) kcal")
                LabeledContent {
                    Text("\(plan.calories.kcal) kcal").font(.headline).foregroundStyle(Color.accentColor)
                } label: {
                    Text("Daily calories").font(.headline)
                }
                LabeledContent("Protein", value: "\(plan.protein.clean) g")
                LabeledContent("Carbs", value: "\(plan.carbs.clean) g")
                LabeledContent("Fat", value: "\(plan.fat.clean) g")
            } header: {
                Text("Your daily targets")
            } footer: {
                Text("Based on the Mifflin–St Jeor equation. Ask a healthcare professional for medical or very low-calorie plans.")
            }

            Section {
                Button {
                    appState.calorieGoal = plan.calories
                    appState.proteinGoal = plan.protein
                    appState.carbsGoal = plan.carbs
                    appState.fatGoal = plan.fat
                    appState.profileComplete = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Text("Apply These Goals")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Goal Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    private func measurementRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
