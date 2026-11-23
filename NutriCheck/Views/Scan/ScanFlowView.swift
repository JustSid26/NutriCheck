import PhotosUI
import SwiftData
import SwiftUI

struct ScanRequest: Identifiable {
    let id = UUID()
    var mealType: MealType?
    var date: Date
    #if DEBUG
    var debugAnalysis: NutritionAnalysis?
    #endif
}

/// Capture → (optional details) → AI analysis → review & log.
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    enum Stage: Equatable {
        case choose, preview, describe, analyzing, result
        case failed(String)
    }

    @State private var stage: Stage = .choose
    @State private var image: UIImage?
    @State private var uploadData: Data?
    @State private var note = ""
    @State private var foodDescription = ""
    @State private var analysis: NutritionAnalysis?
    @State private var servings: Double = 1
    @State private var entryName = ""
    @State private var mealType: MealType
    @State private var entryDate: Date
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var showRefine = false
    @State private var refineText = ""
    @State private var analysisTask: Task<Void, Never>?

    init(request: ScanRequest) {
        _mealType = State(initialValue: request.mealType ?? MealType.suggested(for: request.date))
        _entryDate = State(initialValue: request.date)
        #if DEBUG
        if let debug = request.debugAnalysis {
            _analysis = State(initialValue: debug)
            _entryName = State(initialValue: debug.name)
            _stage = State(initialValue: .result)
        }
        #endif
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.screenBackground)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { captured in setImage(captured) }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            if let item { loadPhoto(item) }
        }
        .alert("Refine result", isPresented: $showRefine) {
            TextField("e.g. 3 rotis, not 2. Cooked in ghee.", text: $refineText)
            Button("Cancel", role: .cancel) {}
            Button("Re-analyze") { runAnalysis(correction: refineText) }
        } message: {
            Text("Tell NutriCheck what's different and it will recalculate.")
        }
        .interactiveDismissDisabled(stage == .analyzing || stage == .result)
        .onDisappear { analysisTask?.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choose: chooseView
        case .preview: previewView
        case .describe: describeView
        case .analyzing: AnalyzingView(image: image)
        case .result: resultView
        case .failed(let message): failedView(message)
        }
    }

    private var navigationTitle: String {
        switch stage {
        case .choose: "Add Food"
        case .preview: "Your Photo"
        case .describe: "Describe Food"
        case .analyzing: "Analyzing"
        case .result: analysis?.isFood == false ? "Hmm…" : "Review"
        case .failed: "Something Went Wrong"
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                analysisTask?.cancel()
                dismiss()
            }
        }
        if stage == .result, analysis?.isFood == true {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    refineText = ""
                    showRefine = true
                } label: {
                    Label("Refine", systemImage: "wand.and.stars")
                }
            }
        }
    }

    // MARK: - Choose

    private var chooseView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !appState.hasAPIKey {
                    APIKeyInlineCard()
                }

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.gradient)
                            .frame(width: 104, height: 104)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 18, y: 8)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("What are you having?")
                        .font(.title2.bold())
                    Text("Snap a meal, a drink, a packaged product or its nutrition label. NutriCheck works out the rest.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    Button { showCamera = true } label: {
                        OptionRow(title: "Take a Photo", subtitle: CameraPicker.isAvailable ? "Food, drink or label" : "Camera not available on this device", icon: "camera.fill", prominent: true)
                    }
                    .disabled(!CameraPicker.isAvailable)

                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        OptionRow(title: "Choose from Library", subtitle: "Use a photo you already took", icon: "photo.on.rectangle.angled")
                    }

                    Button { stage = .describe } label: {
                        OptionRow(title: "Describe It", subtitle: "Type what you ate or drank", icon: "text.bubble.fill")
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    Text("Works with")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        Chip(text: "Home-cooked", icon: "frying.pan.fill", tint: .orange)
                        Chip(text: "Restaurant", icon: "fork.knife", tint: .indigo)
                        Chip(text: "Fast food", icon: "takeoutbag.and.cup.and.straw.fill", tint: .red)
                        Chip(text: "Packaged", icon: "shippingbox.fill", tint: .brown)
                        Chip(text: "Drinks", icon: "cup.and.saucer.fill", tint: .cyan)
                        Chip(text: "Labels", icon: "doc.text.viewfinder", tint: .blue)
                    }
                }
            }
            .padding(20)
        }
        .overlay {
            if isLoadingPhoto {
                ProgressView("Loading photo…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Preview

    private var previewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                }

                VStack(alignment: .leading, spacing: 10) {
                    CardTitle(title: "Add details (optional)", icon: "square.and.pencil")
                    TextField("e.g. homemade, cooked in ghee, 2 rotis, I'll eat half", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Portion size, cooking method, brand or restaurant name all improve accuracy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .card()
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button { runAnalysis() } label: {
                    Label("Analyze Nutrition", systemImage: "sparkles")
                }
                .buttonStyle(.primary)
                Button("Choose a different photo") { reset() }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    // MARK: - Describe

    private var describeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    CardTitle(title: "What did you eat or drink?", icon: "text.bubble.fill")
                    TextField("e.g. 2 aloo parathas with butter, a bowl of curd and masala chai with sugar", text: $foodDescription, axis: .vertical)
                        .lineLimit(4...10)
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Include quantities, brands and how it was cooked for the best estimate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Try an example")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(Self.examples, id: \.self) { example in
                            Button { foodDescription = example } label: {
                                Text(example)
                                    .font(.footnote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cardBackground, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button { runAnalysis() } label: {
                    Label("Analyze Nutrition", systemImage: "sparkles")
                }
                .buttonStyle(.primary)
                .disabled(foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Use a photo instead") { reset() }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private static let examples = [
        "2 aloo parathas with curd",
        "McDonald's McChicken meal, medium fries, Coke",
        "Starbucks grande caramel latte",
        "Bowl of oats with banana and honey",
        "Chicken biryani, 1 plate",
        "1 glass of fresh orange juice",
    ]

    // MARK: - Result

    @ViewBuilder
    private var resultView: some View {
        if let analysis, analysis.isFood {
            ScrollView {
                VStack(spacing: 16) {
                    NutritionDetailContent(analysis: analysis, image: image, title: entryName, servings: $servings)
                    LogDetailsCard(name: $entryName, mealType: $mealType, date: $entryDate)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Text("Add this to your log?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button { save(analysis) } label: {
                        Label("Yes, add to \(mealType.title) · \(analysis.nutrients.scaled(by: servings).calories.kcal) kcal", systemImage: "plus.circle.fill")
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.primary)
                    Button {
                        analysisTask?.cancel()
                        dismiss()
                    } label: {
                        Text("No, just checking")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
            }
        } else {
            ContentUnavailableView {
                Label("That doesn't look like food", systemImage: "questionmark.circle")
            } description: {
                Text(analysis?.notFoodReason ?? "Try a clearer photo of your meal, drink or its nutrition label.")
            } actions: {
                Button("Try Another Photo") { reset() }
                    .buttonStyle(.borderedProminent)
                Button("Describe It Instead") { stage = .describe }
            }
        }
    }

    // MARK: - Failure

    private func failedView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("Analysis failed", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(message)
                }
                if !appState.hasAPIKey {
                    APIKeyInlineCard()
                }
                VStack(spacing: 10) {
                    Button { runAnalysis() } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.primary)
                    .disabled(!appState.hasAPIKey)
                    Button("Start Over") { reset() }
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    private func setImage(_ captured: UIImage) {
        image = ImageProcessor.resized(captured, maxDimension: 1600)
        uploadData = image.flatMap(ImageProcessor.uploadJPEG(from:))
        foodDescription = ""
        stage = .preview
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        Task {
            defer {
                isLoadingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let picked = UIImage(data: data) else {
                stage = .failed("Couldn't load that photo. Please try a different one.")
                return
            }
            setImage(picked)
        }
    }

    private func runAnalysis(correction: String? = nil) {
        guard appState.hasAPIKey else {
            stage = .failed(AnalysisError.missingAPIKey.localizedDescription)
            return
        }
        let service = appState.makeService()
        let imageData = uploadData
        let details = imageData == nil ? foodDescription : note
        let previous = correction == nil ? nil : analysis

        analysisTask?.cancel()
        withAnimation(.snappy) { stage = .analyzing }

        analysisTask = Task {
            do {
                let result = try await service.analyze(imageJPEG: imageData, details: details, correction: correction, previous: previous)
                guard !Task.isCancelled else { return }
                analysis = result
                entryName = result.name
                servings = 1
                withAnimation(.snappy) { stage = .result }
                UINotificationFeedbackGenerator().notificationOccurred(result.isFood ? .success : .warning)
            } catch {
                guard !Task.isCancelled else { return }
                if (error as? URLError)?.code == .cancelled { return }
                withAnimation(.snappy) { stage = .failed(error.localizedDescription) }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func save(_ analysis: NutritionAnalysis) {
        let trimmedName = entryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = (image == nil ? foodDescription : note).trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntry(
            analysis: analysis,
            name: trimmedName.isEmpty ? analysis.name : trimmedName,
            servings: servings,
            mealType: mealType,
            date: entryDate,
            imageData: image.flatMap(ImageProcessor.thumbnailJPEG(from:)),
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        modelContext.insert(entry)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func reset() {
        analysisTask?.cancel()
        image = nil
        uploadData = nil
        note = ""
        analysis = nil
        servings = 1
        withAnimation(.snappy) { stage = .choose }
    }
}

// MARK: - Subviews

private struct OptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(prominent ? Color.accentColor : .white)
                .background(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(Color.accentColor.gradient), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.75)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .opacity(0.5)
        }
        .foregroundStyle(prominent ? .white : .primary)
        .padding(14)
        .background(
            prominent ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.cardBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
    }
}

/// Lets the user paste their key right inside the scan flow.
struct APIKeyInlineCard: View {
    @Environment(AppState.self) private var appState
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(title: "Connect OpenAI", icon: "key.fill", tint: .orange)
            Text("NutriCheck uses OpenAI to analyze food photos. Paste your API key to get started. It's stored in your iPhone's Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                SecureField("sk-…", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.callout.monospaced())
                    .padding(10)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                Button("Save") {
                    appState.apiKey = draft
                    dismissKeyboard()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                Label("Get an API key", systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
            }
        }
        .card()
    }
}
