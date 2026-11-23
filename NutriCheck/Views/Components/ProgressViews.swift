import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var colors: [Color]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(min(progress, 1), 0.05))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0.001 ? 1 : 0)
        }
        .animation(.spring(duration: 0.7), value: progress)
    }
}

struct MacroProgressBar: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color

    private var progress: Double { goal > 0 ? value / goal : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.clean)
                    .font(.headline)
                    .contentTransition(.numericText())
                Text("/ \(goal.clean)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(progress > 1 ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(color.gradient))
                        .frame(width: max(6, geo.size.width * min(progress, 1)))
                }
            }
            .frame(height: 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.6), value: value)
    }
}

/// Horizontal bar split by each macro's share of calories.
struct MacroSplitBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        let p = protein * 4, c = carbs * 4, f = fat * 9
        let total = p + c + f
        GeometryReader { geo in
            HStack(spacing: 3) {
                if total > 0 {
                    segment(Color.protein, width: geo.size.width * p / total)
                    segment(Color.carbs, width: geo.size.width * c / total)
                    segment(Color.fat, width: geo.size.width * f / total)
                } else {
                    Capsule().fill(Color(.tertiarySystemFill))
                }
            }
        }
        .frame(height: 10)
    }

    private func segment(_ color: Color, width: CGFloat) -> some View {
        Capsule().fill(color.gradient).frame(width: max(0, width - 2))
    }
}

struct HealthScoreBadge: View {
    let score: Int
    var size: CGFloat = 64

    var body: some View {
        let color = NutritionAnalysis.healthColor(for: score)
        ZStack {
            ProgressRing(progress: Double(score) / 10, lineWidth: size * 0.11, colors: [color.opacity(0.7), color])
            VStack(spacing: -2) {
                Text("\(score)")
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                Text("/10")
                    .font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct FoodThumbnail: View {
    let imageData: Data?
    let category: FoodCategory
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    category.tint.opacity(0.16)
                    Image(systemName: category.icon)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(category.tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}
