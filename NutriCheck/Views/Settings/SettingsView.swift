import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    private enum TestState: Equatable {
        case idle, testing, success
        case failure(String)
    }

    @State private var testState: TestState = .idle
    @State private var showCustomModel = false
    @State private var confirmDeleteAll = false
    @State private var entryCount = 0

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            Form {
                // MARK: OpenAI
                Section {
                    SecureField("sk-…", text: $state.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .onChange(of: appState.apiKey) { testState = .idle }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            switch testState {
                            case .idle: EmptyView()
                            case .testing: ProgressView()
                            case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            case .failure: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(!appState.hasAPIKey || testState == .testing)

                    if case .failure(let message) = testState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        Label("Get an API key", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Stored in your iPhone's Keychain. Photos go to OpenAI only when you analyze food, with storage turned off for each request.")
                }

                // MARK: Model
                Section {
                    Picker("Model", selection: modelSelection) {
                        ForEach(AppState.modelPresets) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                        Text("Custom…").tag("__custom__")
                    }
                    if showCustomModel {
                        TextField("Model ID, e.g. gpt-5.6", text: $state.model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                    }
                } header: {
                    Text("AI Model")
                } footer: {
                    Text(AppState.modelPresets.first { $0.id == appState.model && !showCustomModel }?.detail
                         ?? "Use any OpenAI model that accepts images and supports Structured Outputs.")
                }

                // MARK: Profile
                Section {
                    HStack {
                        Image(systemName: "scalemass.fill").foregroundStyle(.blue).frame(width: 20)
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $state.weightKg, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg")
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .leading)
                    }
                    Toggle(isOn: $state.countExerciseCalories) {
                        Label("Add exercise to calories left", systemImage: "flame.fill")
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text(appState.profileComplete
                         ? "Your weight is used to estimate calories burned. Update it as it changes, or tell the Assistant."
                         : "Your weight is used to estimate calories burned. Open \"Calculate my goals\" below to add height, age and activity for personalised targets.")
                }

                // MARK: Goals
                Section {
                    GoalField(title: "Calories", value: $state.calorieGoal, unit: "kcal", color: .accentColor)
                    GoalField(title: "Protein", value: $state.proteinGoal, unit: "g", color: .protein)
                    GoalField(title: "Carbs", value: $state.carbsGoal, unit: "g", color: .carbs)
                    GoalField(title: "Fat", value: $state.fatGoal, unit: "g", color: .fat)
                    NavigationLink {
                        GoalCalculatorView()
                    } label: {
                        Label("Calculate my goals", systemImage: "function")
                    }
                } header: {
                    Text("Daily Goals")
                } footer: {
                    let macroKcal = appState.proteinGoal * 4 + appState.carbsGoal * 4 + appState.fatGoal * 9
                    Text("Your macro goals add up to \(macroKcal.kcal) kcal.")
                }

                // MARK: Data
                Section("Data") {
                    LabeledContent("Logged foods", value: "\(entryCount)")
                    Button("Delete All Entries", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .disabled(entryCount == 0)
                }

                // MARK: About
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("NutriCheck estimates nutrition with AI. Estimates can be off, especially for mixed dishes and portion sizes. It isn't a substitute for advice from a doctor or dietitian.")
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .confirmationDialog("Delete all logged foods?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) { deleteAll() }
            } message: {
                Text("This permanently removes \(entryCount) entries from this iPhone.")
            }
            .onAppear {
                showCustomModel = !AppState.modelPresets.contains { $0.id == appState.model }
                refreshCount()
            }
        }
    }

    private var modelSelection: Binding<String> {
        Binding {
            showCustomModel ? "__custom__" : appState.model
        } set: { newValue in
            if newValue == "__custom__" {
                showCustomModel = true
            } else {
                showCustomModel = false
                appState.model = newValue
            }
            testState = .idle
        }
    }

    private func testConnection() {
        testState = .testing
        let service = appState.makeService()
        Task {
            do {
                try await service.validate()
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }

    private func refreshCount() {
        entryCount = (try? modelContext.fetchCount(FetchDescriptor<FoodEntry>())) ?? 0
    }

    private func deleteAll() {
        try? modelContext.delete(model: FoodEntry.self)
        try? modelContext.save()
        refreshCount()
    }
}

private struct GoalField: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}
