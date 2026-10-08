import SwiftUI

/// A jornada até a meta: a curva do peso de hoje até o peso-meta, que se desenha sozinha,
/// acende os marcos de cada mês pelo caminho e estoura no ponto final.
/// `progress` vai de 0 a 1 (quanto da curva já foi desenhado); quem anima é a tela.
struct JourneyChart: View {
    let startKg: Double
    let goalKg: Double
    let arrival: Date
    let progress: CGFloat
    /// Ponto final aceso (bandeira, pulso e confete).
    let reached: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFlat: Bool { abs(goalKg - startKg) < 0.5 }

    /// Marcos de mês no caminho (no máximo 3), com a fração da curva onde cada um cai.
    var milestones: [(fraction: CGFloat, label: String)] {
        guard !isFlat else { return [] }
        let days = max(1, Calendar.current.dateComponents([.day], from: .now, to: arrival).day ?? 1)
        let months = Int((Double(days) / 30.4).rounded(.down))
        guard months >= 2 else { return [] }
        let picks = months <= 4 ? Array(1..<months) : [months / 4, months / 2, months * 3 / 4]
        return picks.map { month in
            let fraction = CGFloat(Double(month) * 30.4 / Double(days))
            let delta = (weight(at: fraction) - startKg)
            let rounded = (abs(delta) * 2).rounded() / 2
            let sign = delta < 0 ? "−" : "+"
            return (fraction, "\(sign)\(rounded.formatted(.number.precision(.fractionLength(0...1)))) kg")
        }
    }

    /// Peso ao longo do caminho: muda mais no começo e assenta perto da meta, como na vida real.
    private func weight(at fraction: CGFloat) -> Double {
        let eased = 1 - pow(1 - Double(fraction), 1.6)
        return startKg + (goalKg - startKg) * eased
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plot = CGRect(x: 6, y: 34, width: size.width - 12, height: size.height - 62)
            let curve = path(in: plot)

            ZStack(alignment: .topLeading) {
                // Área sob a curva, revelada junto com o traço.
                area(in: plot)
                    .fill(LinearGradient(colors: [.indigo.opacity(0.28), .purple.opacity(0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: plot.minX + plot.width * progress)
                    }

                // Brilho por baixo do traço.
                curve
                    .trim(from: 0, to: progress)
                    .stroke(.indigo.opacity(0.45), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .blur(radius: 8)
                curve
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                // Começo: hoje.
                dot(at: point(at: 0, in: plot), size: 10, filled: true)
                label(title: "Hoje", value: kg(startKg), alignment: .leading)
                    .position(x: plot.minX + 34, y: 14)

                // Marcos pelo caminho.
                ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                    let spot = point(at: milestone.fraction, in: plot)
                    let shown = progress >= milestone.fraction
                    ZStack {
                        dot(at: spot, size: 8, filled: false)
                        Text(milestone.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular, in: .capsule)
                            .position(x: spot.x, y: spot.y + (goalKg < startKg ? 22 : -22))
                    }
                    .scaleEffect(shown ? 1 : 0.4)
                    .opacity(shown ? 1 : 0)
                    .animation(Motion.quick, value: shown)
                }

                // Fim: a meta.
                let end = point(at: 1, in: plot)
                if reached && !reduceMotion {
                    PulseRing().position(end)
                    ConfettiBurst(origin: end)
                }
                dot(at: end, size: 14, filled: true)
                    .scaleEffect(reached ? 1 : 0.01)
                    .animation(Motion.surface, value: reached)
                label(title: arrival.formatted(.dateTime.month(.abbreviated).year(.twoDigits)),
                      value: kg(goalKg), alignment: .trailing, icon: "flag.checkered")
                    .position(x: plot.maxX - 40, y: 14)
                    .opacity(reached ? 1 : 0)
                    .offset(y: reached ? 0 : 6)
                    .animation(Motion.surface, value: reached)
            }
        }
    }

    // MARK: - Geometria

    private var range: ClosedRange<Double> {
        let low = min(startKg, goalKg), high = max(startKg, goalKg)
        let pad = max((high - low) * 0.25, 1.5)
        return (low - pad)...(high + pad)
    }

    private func point(at fraction: CGFloat, in plot: CGRect) -> CGPoint {
        let value = weight(at: fraction)
        let y = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGPoint(x: plot.minX + plot.width * fraction, y: plot.maxY - plot.height * CGFloat(y))
    }

    private func path(in plot: CGRect) -> Path {
        Path { path in
            let steps = 60
            for step in 0...steps {
                let spot = point(at: CGFloat(step) / CGFloat(steps), in: plot)
                step == 0 ? path.move(to: spot) : path.addLine(to: spot)
            }
        }
    }

    private func area(in plot: CGRect) -> Path {
        var area = path(in: plot)
        area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY + 22))
        area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY + 22))
        area.closeSubpath()
        return area
    }

    // MARK: - Peças

    private func dot(at spot: CGPoint, size: CGFloat, filled: Bool) -> some View {
        Circle()
            .fill(filled ? Color.white : Color.white.opacity(0.9))
            .overlay { Circle().stroke(.indigo, lineWidth: filled ? 4 : 2.5) }
            .frame(width: size, height: size)
            .position(spot)
    }

    private func label(title: String, value: String, alignment: HorizontalAlignment, icon: String? = nil) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(uiColor: .label))
        }
        .fixedSize()
    }

    private func kg(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}

/// Anel que pulsa em volta da meta depois que a curva chega nela.
private struct PulseRing: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .stroke(.indigo.opacity(0.6), lineWidth: 2)
            .frame(width: 14, height: 14)
            .scaleEffect(pulsing ? 3.2 : 1)
            .opacity(pulsing ? 0 : 0.9)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
            .onAppear { pulsing = true }
    }
}

/// Estouro de confete a partir de um ponto (a meta), nas cores dos macros. Uma vez só.
struct ConfettiBurst: View {
    let origin: CGPoint
    @State private var burst = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors = [Theme.protein, Theme.carbs, Theme.fat, Theme.sugar, Theme.fiber, Theme.sodium, Color.indigo]
    private let pieces: [(angle: Double, distance: CGFloat, spin: Double, size: CGSize, color: Color)] =
        (0..<26).map { index in
            (angle: .random(in: -Double.pi * 0.95 ... -Double.pi * 0.05),
             distance: .random(in: 50...130), spin: .random(in: -360...360),
             size: CGSize(width: .random(in: 5...8), height: .random(in: 8...13)),
             color: colors[index % colors.count])
        }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(pieces.indices, id: \.self) { index in
                    let piece = pieces[index]
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(piece.color)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .rotationEffect(.degrees(burst ? piece.spin : 0))
                        .position(origin)
                        .offset(x: burst ? cos(piece.angle) * piece.distance : 0,
                                y: burst ? sin(piece.angle) * piece.distance + 90 : 0)
                        .opacity(burst ? 0 : 1)
                        .animation(.easeOut(duration: 1.3), value: burst)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { burst = true }
    }
}
