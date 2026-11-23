import SwiftUI

/// Name, meal and time controls shared by the scan result and the entry detail screen.
struct LogDetailsCard: View {
    @Binding var name: String
    @Binding var mealType: MealType
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardTitle(title: "Log details", icon: "square.and.pencil")

            VStack(spacing: 0) {
                HStack {
                    Text("Name").foregroundStyle(.secondary)
                    Spacer()
                    TextField("Food name", text: $name)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                }
                .padding(.vertical, 10)

                Divider()

                HStack {
                    Text("Meal").foregroundStyle(.secondary)
                    Spacer()
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.title, systemImage: meal.icon).tag(meal)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 4)

                Divider()

                DatePicker("Time", selection: $date, in: ...Date.now.addingTimeInterval(3600 * 24 * 7), displayedComponents: [.date, .hourAndMinute])
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            .font(.subheadline)
        }
        .card()
    }
}
