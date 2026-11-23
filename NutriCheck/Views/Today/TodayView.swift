import SwiftUI

struct TodayView: View {
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            DayLogView(date: selectedDate) {
                WeekStrip(selectedDate: $selectedDate)
            }
            .id(selectedDate)
            .navigationTitle(selectedDate.dayTitle)
            .toolbar {
                if !Calendar.current.isDateInToday(selectedDate) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today") {
                            withAnimation { selectedDate = Calendar.current.startOfDay(for: .now) }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Label("Pick date", systemImage: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $selectedDate)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct DatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Date.now

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $draft, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .navigationTitle("Go to date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            date = Calendar.current.startOfDay(for: draft)
                            dismiss()
                        }
                    }
                }
        }
        .onAppear { draft = date }
    }
}

/// The last seven days, tappable.
struct WeekStrip: View {
    @Binding var selectedDate: Date

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekAgo = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let anchor = selectedDate >= weekAgo ? today : cal.startOfDay(for: selectedDate)
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: anchor) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let selected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(day)
                Button {
                    withAnimation(.snappy) { selectedDate = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.callout.weight(.bold))
                            .foregroundStyle(selected ? .white : .primary)
                        Circle()
                            .fill(isToday ? (selected ? Color.white : Color.accentColor) : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.cardBackground))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }
}
