import SwiftData
import SwiftUI

struct AssistantView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.date) private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var confirmClear = false
    @State private var replyTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    static let suggestions = [
        "How many calories do I have left today?",
        "What can I eat for dinner with my remaining calories?",
        "I walked 30 minutes. How many calories did I burn?",
        "High-protein snack ideas under 200 kcal",
        "How am I doing this week?",
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if messages.isEmpty && !isThinking {
                            AssistantWelcome { send($0) }
                        }
                        ForEach(messages) { message in
                            ChatBubble(message: message) { index in
                                apply(actionAt: index, in: message)
                            } onDismiss: { index in
                                dismissAction(at: index, in: message)
                            }
                            .id(message.id)
                        }
                        if isThinking {
                            TypingIndicator()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("typing")
                        }
                        if let errorMessage {
                            ErrorBubble(message: errorMessage) { requestReply() }
                                .id("error")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: isThinking) { scrollToBottom(proxy) }
                .onChange(of: inputFocused) { if inputFocused { scrollToBottom(proxy) } }
            }
            .background(Color.screenBackground)
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            confirmClear = true
                        } label: {
                            Label("New chat", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .confirmationDialog("Start a new chat?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Conversation", role: .destructive) { clearChat() }
            } message: {
                Text("Your food and exercise logs aren't affected.")
            }
        }
        .task {
            #if DEBUG
            if let prompt = UserDefaults.standard.string(forKey: "chatPrompt"), messages.isEmpty {
                send(prompt)
            }
            #endif
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about calories, food, workouts…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
                }
                .onSubmit { send(draft) }

            Button {
                send(draft)
            } label: {
                Image(systemName: isThinking ? "ellipsis" : "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(canSend ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.gray.opacity(0.35))))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !isThinking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: - Sending

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        modelContext.insert(ChatMessage(role: .user, text: trimmed))
        try? modelContext.save()
        draft = ""
        requestReply()
    }

    private func requestReply() {
        guard appState.hasAPIKey else {
            errorMessage = AnalysisError.missingAPIKey.localizedDescription
            return
        }
        errorMessage = nil
        isThinking = true

        let all = (try? modelContext.fetch(FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let history = all.suffix(24).map { ChatTurn(role: $0.role, text: $0.textForModel) }
        let context = AssistantContext.build(modelContext: modelContext, appState: appState)
        let service = appState.makeService()

        replyTask?.cancel()
        replyTask = Task {
            defer { isThinking = false }
            do {
                let reply = try await service.chat(history: Array(history), context: context)
                guard !Task.isCancelled else { return }
                modelContext.insert(ChatMessage(role: .assistant, text: reply.reply, actions: reply.actions))
                try? modelContext.save()
            } catch {
                guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Actions

    private func apply(actionAt index: Int, in message: ChatMessage) {
        var actions = message.actions
        guard actions.indices.contains(index) else { return }
        let action = actions[index]

        switch action.type {
        case .logExercise:
            modelContext.insert(ExerciseEntry(
                name: action.exerciseName ?? "Workout",
                durationMinutes: action.durationMinutes ?? 0,
                caloriesBurned: action.caloriesBurned ?? 0,
                date: .now
            ))
        case .setGoals:
            if let c = action.calories { appState.calorieGoal = c.rounded() }
            if let p = action.proteinG { appState.proteinGoal = p.rounded() }
            if let c = action.carbsG { appState.carbsGoal = c.rounded() }
            if let f = action.fatG { appState.fatGoal = f.rounded() }
        case .updateWeight:
            if let w = action.weightKg { appState.weightKg = w }
        case .unknown:
            return
        }
        actions[index].status = .applied
        message.actions = actions
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func dismissAction(at index: Int, in message: ChatMessage) {
        var actions = message.actions
        guard actions.indices.contains(index) else { return }
        actions[index].status = .dismissed
        message.actions = actions
        try? modelContext.save()
    }

    private func clearChat() {
        replyTask?.cancel()
        isThinking = false
        errorMessage = nil
        try? modelContext.delete(model: ChatMessage.self)
        try? modelContext.save()
    }
}

// MARK: - Welcome

private struct AssistantWelcome: View {
    @Environment(AppState.self) private var appState
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)

            VStack(spacing: 6) {
                Text("Your nutrition assistant")
                    .font(.title2.bold())
                Text("I can see what you've logged, your goals and your weight (\(appState.weightKg.clean) kg). Ask me what to eat, how much you burned, or how your week is going.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(AssistantView.suggestions, id: \.self) { suggestion in
                    Button { onPick(suggestion) } label: {
                        HStack {
                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(14)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Bubbles

private struct ChatBubble: View {
    let message: ChatMessage
    let onApply: (Int) -> Void
    let onDismiss: (Int) -> Void

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .textSelection(.enabled)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                AssistantAvatar()
                VStack(alignment: .leading, spacing: 10) {
                    Text(Self.markdown(message.text))
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .textSelection(.enabled)

                    let actions = message.actions
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        ActionCard(action: action) { onApply(index) } onDismiss: { onDismiss(index) }
                    }
                }
                Spacer(minLength: 24)
            }
        }
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

private struct AssistantAvatar: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.accentColor.gradient))
    }
}

private struct ActionCard: View {
    let action: AssistantAction
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            switch action.status {
            case .applied:
                Label(appliedText, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            case .dismissed:
                Text("Dismissed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case nil:
                HStack(spacing: 8) {
                    Button(action: onApply) {
                        Text(buttonTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Not now", action: onDismiss)
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                }
                .controlSize(.regular)
            }
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        }
    }

    private var icon: String {
        switch action.type {
        case .logExercise: "flame.fill"
        case .setGoals: "target"
        case .updateWeight: "scalemass.fill"
        case .unknown: "questionmark"
        }
    }

    private var tint: Color {
        switch action.type {
        case .logExercise: .orange
        case .setGoals: .accentColor
        case .updateWeight: .blue
        case .unknown: .gray
        }
    }

    private var title: String {
        switch action.type {
        case .logExercise: "Log exercise"
        case .setGoals: "Update daily goals"
        case .updateWeight: "Update weight"
        case .unknown: "Action"
        }
    }

    private var detail: String {
        switch action.type {
        case .logExercise:
            let minutes = (action.durationMinutes ?? 0) > 0 ? " · \((action.durationMinutes ?? 0).clean) min" : ""
            return "\(action.exerciseName ?? "Workout")\(minutes) · \((action.caloriesBurned ?? 0).kcal) kcal burned"
        case .setGoals:
            return "\((action.calories ?? 0).kcal) kcal · P \((action.proteinG ?? 0).clean)g · C \((action.carbsG ?? 0).clean)g · F \((action.fatG ?? 0).clean)g"
        case .updateWeight:
            return "\((action.weightKg ?? 0).clean) kg"
        case .unknown:
            return ""
        }
    }

    private var buttonTitle: String {
        switch action.type {
        case .logExercise: "Add to Today"
        case .setGoals: "Apply Goals"
        case .updateWeight: "Update"
        case .unknown: "OK"
        }
    }

    private var appliedText: String {
        switch action.type {
        case .logExercise: "Added to today's exercise"
        case .setGoals: "Goals updated"
        case .updateWeight: "Weight updated"
        case .unknown: "Done"
        }
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AssistantAvatar()
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(phase == i ? 1 : 0.3)
                        .scaleEffect(phase == i ? 1.15 : 0.9)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1) % 3 }
            }
        }
    }
}

private struct ErrorBubble: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn't get a reply", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try Again", action: retry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
