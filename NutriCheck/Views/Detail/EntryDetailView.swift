import SwiftData
import SwiftUI

/// A logged entry: full breakdown plus editable servings, meal and time.
struct EntryDetailView: View {
    @Bindable var entry: FoodEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var analysis: NutritionAnalysis?
    @State private var image: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analysis {
                    NutritionDetailContent(analysis: analysis, image: image, title: entry.name, servings: $entry.servings)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.name).font(.title2.bold())
                        Text("\(entry.calories.kcal) kcal")
                            .font(.largeTitle.bold())
                        ServingsStepper(servings: $entry.servings)
                    }
                    .card()
                }

                if let note = entry.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        CardTitle(title: "Your note", icon: "text.quote")
                        Text(note).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .card()
                }

                LogDetailsCard(name: $entry.name, mealType: $entry.mealType, date: $entry.date)

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.screenBackground)
        .navigationTitle(entry.mealType.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete \(entry.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
        .task {
            analysis = entry.analysis
            image = entry.uiImage
        }
    }

    private func delete() {
        let target = entry
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            modelContext.delete(target)
            try? modelContext.save()
        }
    }
}
