import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?

    @State private var messageIndex = 0
    @State private var scanning = false

    private var messages: [String] {
        image == nil
            ? ["Understanding your description…", "Estimating portions…", "Calculating nutrients…", "Almost there…"]
            : ["Identifying the food…", "Estimating portion sizes…", "Reading labels & ingredients…", "Calculating nutrients…", "Almost there…"]
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 260, height: 260)
                } else {
                    Rectangle()
                        .fill(Color.accentColor.gradient)
                        .overlay {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                }

                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.55), .white.opacity(0.7), Color.accentColor.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 70)
                .offset(y: scanning ? 120 : -120)
                .blendMode(.plusLighter)
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.accentColor.gradient, lineWidth: 3)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 24, y: 10)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(messages[min(messageIndex, messages.count - 1)])
                    .font(.headline)
                    .contentTransition(.opacity)
                    .id(messageIndex)
                    .transition(.opacity)
                Text("This usually takes a few seconds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scanning = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut) {
                    messageIndex = min(messageIndex + 1, messages.count - 1)
                }
            }
        }
    }
}
