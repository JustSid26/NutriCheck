import SwiftData
import SwiftUI

/// One day's log: summary, meals, and a scan button. Used on Today and from History.
struct DayLogView<Header: View>: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]
    @Query private var exercises: [ExerciseEntry]
    @State private var scanRequest: ScanRequest?
    @State private var showExerciseSheet = false

    private let date: Date
    private let header: Header

    init(date: Date, @ViewBuilder header: () -> Header) {
        self.date = date
        self.header = header()
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end }, sort: \FoodEntry.date)
        _exercises = Query(filter: #Predicate<ExerciseEntry> { $0.date >= start && $0.date < end }, sort: \ExerciseEntry.date)
    }

    private var totals: Nutrients {
        entries.reduce(Nutrients.zero) { $0 + $1.totalNutrients }
    }

    private var burned: Double {
        exercises.reduce(0) { $0 + $1.caloriesBurned }
    }

    var body: some View {
        let totals = totals
        List {
            Section {
                header
                DaySummaryCard(totals: totals, burned: burned)
                if !appState.hasAPIKey {
                    APIKeyBanner()
                }
                if !entries.isEmpty {
                    NutrientHighlights(totals: totals)
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(MealType.allCases) { meal in
                mealSection(meal)
            }

            exerciseSection
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(Color.screenBackground)
        .safeAreaInset(edge: .bottom) {
            Button {
                scanRequest = ScanRequest(mealType: nil, date: newEntryDate(for: nil))
            } label: {
                Label("Scan Food", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
        }
        .sheet(item: $scanRequest) { request in
            ScanFlowView(request: request)
        }
        .sheet(isPresented: $showExerciseSheet) {
            ExerciseLogSheet(date: newEntryDate(for: nil))
        }
    }

    private var exerciseSection: some View {
        Section {
            ForEach(exercises) { exercise in
                ExerciseRow(exercise: exercise)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(exercise)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Button {
                showExerciseSheet = true
            } label: {
                Label("Log exercise", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
            }
        } header: {
            HStack {
                Label("Exercise", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if burned > 0 {
                    Text("−\(burned.kcal) kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }
            .textCase(nil)
        } footer: {
            Text("Tip: tell the Assistant what you did (\"walked 40 min\") and it'll estimate and log it.")
        }
    }

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let mealEntries = entries.filter { $0.mealType == meal }
        let mealCalories = mealEntries.reduce(0) { $0 + $1.calories }

        Section {
            ForEach(mealEntries) { entry in
                NavigationLink {
                    EntryDetailView(entry: entry)
                } label: {
                    FoodEntryRow(entry: entry)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { delete(entry) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button { logAgain(entry) } label: {
                        Label("Log again", systemImage: "arrow.clockwise")
                    }
                    .tint(.accentColor)
                }
                .contextMenu {
                    Button { logAgain(entry) } label: {
                        Label("Log Again Now", systemImage: "arrow.clockwise")
                    }
                    Menu("Move to…") {
                        ForEach(MealType.allCases.filter { $0 != entry.mealType }) { other in
                            Button(other.title) { entry.mealType = other }
                        }
                    }
                    Button(role: .destructive) { delete(entry) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                scanRequest = ScanRequest(mealType: meal, date: newEntryDate(for: meal))
            } label: {
                Label("Add \(meal.title.lowercased())", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
            }
        } header: {
            HStack {
                Label(meal.title, systemImage: meal.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if mealCalories > 0 {
                    Text("\(mealCalories.kcal) kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .textCase(nil)
        }
    }

    /// Now for today; otherwise the chosen day at the meal's typical time.
    private func newEntryDate(for meal: MealType?) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .now }
        let hour = meal?.defaultHour ?? cal.component(.hour, from: .now)
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    private func delete(_ entry: FoodEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func logAgain(_ entry: FoodEntry) {
        let now = Date.now
        guard let copy = entry.duplicate(at: now, mealType: MealType.suggested(for: now)) else { return }
        modelContext.insert(copy)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

extension DayLogView where Header == EmptyView {
    init(date: Date) {
        self.init(date: date) { EmptyView() }
    }
}

// MARK: - Summary

struct DaySummaryCard: View {
    @Environment(AppState.self) private var appState
    let totals: Nutrients
    var burned: Double = 0

    var body: some View {
        let goal = appState.budget(burned: burned)
        let eaten = totals.calories
        let remaining = goal - eaten
        let over = remaining < 0

        VStack(spacing: 18) {
            HStack(spacing: 22) {
                ZStack {
                    ProgressRing(
                        progress: goal > 0 ? eaten / goal : 0,
                        lineWidth: 16,
                        colors: over ? [.orange, .red] : [Color.accentColor.opacity(0.6), Color.accentColor]
                    )
                    VStack(spacing: 0) {
                        Text(abs(remaining).kcal)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: remaining))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(over ? "kcal over" : "kcal left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(over ? .orange : .secondary)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(width: 142, height: 142)

                VStack(alignment: .leading, spacing: 14) {
                    stat(title: "Goal", value: appState.calorieGoal.kcal, unit: "kcal", icon: "target", tint: .secondary)
                    stat(title: "Eaten", value: eaten.kcal, unit: "kcal", icon: "fork.knife", tint: .accentColor)
                    stat(title: "Burned", value: burned.kcal, unit: "kcal", icon: "flame.fill", tint: .orange)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                MacroProgressBar(title: "Protein", value: totals.proteinG, goal: appState.proteinGoal, color: .protein)
                MacroProgressBar(title: "Carbs", value: totals.carbsG, goal: appState.carbsGoal, color: .carbs)
                MacroProgressBar(title: "Fat", value: totals.fatG, goal: appState.fatGoal, color: .fat)
            }
        }
        .card(padding: 18)
    }

    private func stat(title: String, value: String, unit: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NutrientHighlights: View {
    let totals: Nutrients

    var body: some View {
        HStack(spacing: 10) {
            tile("Fiber", totals.fiberG, unit: "g", goal: 28, color: .fiber, icon: "leaf.fill")
            tile("Sugar", totals.sugarG, unit: "g", goal: 50, color: .purple, icon: "cube.fill", limit: true)
            tile("Sodium", totals.sodiumMg, unit: "mg", goal: 2300, color: .teal, icon: "drop.fill", limit: true)
            if let caffeine = totals.caffeineMg, caffeine > 0 {
                tile("Caffeine", caffeine, unit: "mg", goal: 400, color: .brown, icon: "cup.and.saucer.fill", limit: true)
            }
        }
    }

    private func tile(_ title: String, _ value: Double?, unit: String, goal: Double, color: Color, icon: String, limit: Bool = false) -> some View {
        let v = value ?? 0
        let over = limit && v > goal
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Image(systemName: icon).imageScale(.small)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value == nil ? "–" : v.clean)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(over ? .red : .primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(over ? Color.red : color)
                        .frame(width: geo.size.width * min(v / goal, 1))
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct APIKeyBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect OpenAI to start scanning")
                    .font(.subheadline.weight(.semibold))
                Text("Add your API key in Settings, or tap Scan Food to paste it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Row

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnail(imageData: entry.imageData, category: entry.category, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    macro("P", entry.protein, .protein)
                    macro("C", entry.carbs, .carbs)
                    macro("F", entry.fat, .fat)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(entry.calories.kcal)
                    .font(.headline)
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        let serving = entry.servings == 1 ? entry.servingDescription : "\(entry.servings.clean) × \(entry.servingDescription)"
        return serving.isEmpty ? time : "\(time) · \(serving)"
    }

    private func macro(_ letter: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(letter) \(value.clean)g")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }
}
