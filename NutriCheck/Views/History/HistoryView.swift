import Charts
import SwiftData
import SwiftUI

enum HistoryRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    var id: Int { rawValue }
    var title: String { self == .week ? "7 Days" : "30 Days" }
}

struct DaySummary: Identifiable {
    let date: Date
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var count = 0
    var id: Date { date }
}

struct HistoryView: View {
    @State private var range: HistoryRange = .week

    var body: some View {
        NavigationStack {
            HistoryContent(range: $range)
                .id(range)
                .navigationTitle("History")
                .navigationDestination(for: Date.self) { day in
                    DayLogView(date: day)
                        .navigationTitle(day.dayTitle)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }
}

private struct HistoryContent: View {
    @Binding var range: HistoryRange
    @Environment(AppState.self) private var appState
    @Query private var entries: [FoodEntry]

    init(range: Binding<HistoryRange>) {
        _range = range
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(range.wrappedValue.rawValue - 1), to: cal.startOfDay(for: .now)) ?? .distantPast
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start }, sort: \FoodEntry.date, order: .reverse)
    }

    /// Every day in range (oldest → newest), including empty days.
    private var days: [DaySummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var map: [Date: DaySummary] = [:]
        for offset in 0..<range.rawValue {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                map[day] = DaySummary(date: day)
            }
        }
        for entry in entries {
            let day = cal.startOfDay(for: entry.date)
            guard var summary = map[day] else { continue }
            summary.calories += entry.calories
            summary.protein += entry.protein
            summary.carbs += entry.carbs
            summary.fat += entry.fat
            summary.count += 1
            map[day] = summary
        }
        return map.values.sorted { $0.date < $1.date }
    }

    var body: some View {
        let days = days
        let logged = days.filter { $0.count > 0 }
        let goal = appState.calorieGoal

        List {
            Section {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                CaloriesChart(days: days, goal: goal, range: range)
                    .padding(.vertical, 8)
            } header: {
                Text("Calories").textCase(nil)
            }

            if logged.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No meals logged yet",
                        systemImage: "fork.knife.circle",
                        description: Text("Scan your first meal on the Today tab and your trends will show up here.")
                    )
                }
            } else {
                Section {
                    AveragesView(logged: logged, totalDays: days.count, goal: goal)
                } header: {
                    Text("Daily averages").textCase(nil)
                }

                Section {
                    ForEach(logged.reversed()) { day in
                        NavigationLink(value: day.date) {
                            DayRow(day: day, goal: goal)
                        }
                    }
                } header: {
                    Text("Days").textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct CaloriesChart: View {
    let days: [DaySummary]
    let goal: Double
    let range: HistoryRange

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Calories", day.calories)
                )
                .foregroundStyle(day.calories > goal ? Color.orange.gradient : Color.accentColor.gradient)
                .cornerRadius(range == .week ? 6 : 3)
            }
            RuleMark(y: .value("Goal", goal))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .top, alignment: .leading) {
                    Text("Goal \(goal.kcal)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis {
            if range == .week {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .frame(height: 210)
    }
}

private struct MacroSlice: Identifiable {
    let name: String
    let kcal: Double
    let color: Color
    var id: String { name }
}

private struct AveragesView: View {
    let logged: [DaySummary]
    let totalDays: Int
    let goal: Double

    var body: some View {
        let n = Double(max(logged.count, 1))
        let kcal = logged.reduce(0) { $0 + $1.calories } / n
        let protein = logged.reduce(0) { $0 + $1.protein } / n
        let carbs = logged.reduce(0) { $0 + $1.carbs } / n
        let fat = logged.reduce(0) { $0 + $1.fat } / n
        let slices = [
            MacroSlice(name: "Protein", kcal: protein * 4, color: .protein),
            MacroSlice(name: "Carbs", kcal: carbs * 4, color: .carbs),
            MacroSlice(name: "Fat", kcal: fat * 9, color: .fat),
        ]
        let macroTotal = slices.reduce(0) { $0 + $1.kcal }

        HStack(spacing: 20) {
            Chart(slices) { slice in
                SectorMark(angle: .value("kcal", slice.kcal), innerRadius: .ratio(0.62), angularInset: 2)
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
            }
            .chartLegend(.hidden)
            .frame(width: 110, height: 110)
            .overlay {
                VStack(spacing: 0) {
                    Text(kcal.kcal).font(.headline)
                    Text("kcal/day").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    let grams = slice.name == "Fat" ? slice.kcal / 9 : slice.kcal / 4
                    HStack(spacing: 6) {
                        Circle().fill(slice.color).frame(width: 8, height: 8)
                        Text(slice.name).font(.subheadline)
                        Spacer()
                        Text("\(Int(grams.rounded()))g").font(.subheadline.weight(.semibold))
                        Text(macroTotal > 0 ? "\(Int((slice.kcal / macroTotal * 100).rounded()))%" : "–")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                Divider()
                Text("Logged \(logged.count) of \(totalDays) days · \(kcal > goal ? "above" : "within") goal on average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DayRow: View {
    let day: DaySummary
    let goal: Double

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(
                progress: goal > 0 ? day.calories / goal : 0,
                lineWidth: 5,
                colors: day.calories > goal ? [.orange, .red] : [Color.accentColor.opacity(0.6), Color.accentColor]
            )
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.dayTitle)
                    .font(.subheadline.weight(.semibold))
                Text("\(day.count) item\(day.count == 1 ? "" : "s") · P \(day.protein.clean)g · C \(day.carbs.clean)g · F \(day.fat.clean)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(day.calories.kcal) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}
