import SwiftUI

/// A jornada até a meta, sem moldura nem sombra: as patinhas do Tobi de hoje até o peso-meta, com ele
/// andando na frente e um vidro mostrando quanto já foi, mês a mês, até a bandeira. Ocupa a largura toda da tela.
/// `progress` vai de 0 a 1 e `time` é o relógio da caminhada (o passinho); quem anima é a tela.
struct JourneyChart: View {
    let startKg: Double
    let goalKg: Double
    let arrival: Date
    let progress: CGFloat
    let time: Double
    /// Chegou: o Tobi pula, a bandeira acende e estoura o confete.
    let reached: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let headSize: CGFloat = 46
    /// O rosto do Tobi renderizado, solto no bundle (o app não tem catálogo de assets).
    private static let headImage = UIImage(named: "tobi-head") ?? UIImage()

    private var isFlat: Bool { abs(goalKg - startKg) < 0.5 }

    /// Viradas de mês no caminho (no máximo 3), com a fração da curva onde cada uma cai.
    var milestones: [(fraction: CGFloat, date: Date)] {
        let days = Self.days(until: arrival)
        let months = Int((Double(days) / 30.4).rounded(.down))
        guard months >= 2 else { return [] }
        let picks = months <= 4 ? Array(1..<months) : [months / 4, months / 2, months * 3 / 4]
        return picks.map { month in
            let fraction = CGFloat(Double(month) * 30.4 / Double(days))
            return (fraction, Calendar.current.date(byAdding: .day, value: Int(Double(month) * 30.4), to: .now) ?? .now)
        }
    }

    static func days(until arrival: Date) -> Int {
        max(1, Calendar.current.dateComponents([.day], from: .now, to: arrival).day ?? 1)
    }

    /// Peso ao longo do caminho: muda mais no começo e assenta perto da meta, como na vida real.
    static func weight(from start: Double, to goal: Double, at fraction: CGFloat) -> Double {
        let eased = 1 - pow(1 - Double(fraction), 1.6)
        return start + (goal - start) * eased
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let inset = Self.headSize / 2 + 8
            // Em cima cabe a bandeira por cima da cabeça; embaixo, os meses.
            let top = Self.headSize + 26
            let plot = CGRect(x: inset, y: top, width: size.width - inset * 2, height: size.height - top - 40)
            let curve = path(in: plot)
            let tip = point(at: progress, in: plot)

            ZStack(alignment: .topLeading) {
                // A trilha inteira, apagada: o caminho que falta.
                curve
                    .stroke(Color(uiColor: .label).opacity(0.08),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 9]))

                // O caminho andado: as patinhas do Tobi, uma a uma, alternando esquerda e direita.
                ForEach(0..<Self.pawCount, id: \.self) { index in
                    paw(index, in: plot)
                }

                // Viradas de mês: o ponto e o mês embaixo acendem quando o Tobi passa.
                ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                    let spot = point(at: milestone.fraction, in: plot)
                    let passed = progress >= milestone.fraction
                    Circle()
                        .fill(passed ? Color.white : Color(uiColor: .label).opacity(0.12))
                        .overlay { Circle().stroke(.indigo, lineWidth: passed ? 2.5 : 0) }
                        .frame(width: 9, height: 9)
                        .scaleEffect(passed ? 1 : 0.7)
                        .position(spot)
                        .animation(Motion.quick, value: passed)
                    axisLabel(milestone.date.formatted(.dateTime.month(.abbreviated)), lit: passed)
                        .position(x: spot.x, y: size.height - 14)
                }
                axisLabel("hoje", lit: true)
                    .position(x: plot.minX, y: size.height - 14)
                axisLabel(arrival.formatted(.dateTime.month(.abbreviated)), lit: reached)
                    .position(x: plot.maxX, y: size.height - 14)

                // A bandeira espera na meta desde o começo; acende quando o Tobi chega.
                let end = point(at: 1, in: plot)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(reached ? AnyShapeStyle(.indigo) : AnyShapeStyle(.tertiary))
                    .scaleEffect(reached ? 1.2 : 1, anchor: .bottomLeading)
                    .position(x: end.x + 4, y: end.y - Self.headSize - 12)
                    .animation(Motion.surface, value: reached)

                if reached && !reduceMotion {
                    ConfettiBurst(origin: end)
                }

                // O vidro que anda com o Tobi: quanto já foi, com a trilha passando por trás.
                Text(walked)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .fixedSize()
                    .position(x: min(max(tip.x, plot.minX + 20), plot.maxX - 20), y: tip.y - Self.headSize - 16)
                    .opacity(pillHidden ? 0 : 1)
                    .scaleEffect(pillHidden ? 0.6 : 1)
                    .animation(Motion.quick, value: pillHidden)
                    .accessibilityHidden(true)

                head(at: tip, walking: progress > 0 && progress < 1)
            }
        }
    }

    // MARK: - Patinhas

    static let pawCount = 18

    /// Uma pegada no caminho: virada pra onde o Tobi anda, um pouco pro lado, e só aparece depois que ele passa.
    private func paw(_ index: Int, in plot: CGRect) -> some View {
        let fraction = CGFloat(index) / CGFloat(Self.pawCount - 1) * 0.96
        let here = point(at: fraction, in: plot)
        let ahead = point(at: min(1, fraction + 0.01), in: plot)
        let heading = atan2(ahead.y - here.y, ahead.x - here.x)
        let side: CGFloat = index.isMultiple(of: 2) ? -5 : 5
        let spot = CGPoint(x: here.x - sin(heading) * side, y: here.y + cos(heading) * side)
        let shown = progress >= fraction + 0.02 || reached
        let tint = Color(hue: 0.70 + 0.22 * Double(fraction), saturation: 0.62, brightness: 0.86)
        return Image(systemName: "pawprint.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .rotationEffect(.radians(Double(heading) + .pi / 2))
            .scaleEffect(shown ? 1 : 0.2)
            .opacity(shown ? 1 : 0)
            .animation(Motion.quick, value: shown)
            .position(spot)
            .accessibilityHidden(true)
    }

    /// O vidro some antes da chegada pra não cobrir a bandeira; a promessa lá em cima assume.
    private var pillHidden: Bool { reached || progress == 0 || progress > 0.88 }

    /// O que já foi no caminho, pro vidro: "hoje" no começo, depois "−4 kg" / "+2 kg".
    private var walked: String {
        let delta = Self.weight(from: startKg, to: goalKg, at: progress) - startKg
        guard abs(delta) >= 0.5 else { return isFlat ? "mantendo" : "hoje" }
        let amount = abs(delta).rounded().formatted()
        return (delta < 0 ? "−" : "+") + amount + " kg"
    }

    // MARK: - O Tobi

    /// A cabeça anda na ponta da linha: inclina com a subida/descida e balança a cada passinho.
    private func head(at spot: CGPoint, walking: Bool) -> some View {
        let step = walking && !reduceMotion ? time * 2 * .pi * 2.4 : 0
        let tilt = isFlat ? 0 : (goalKg < startKg ? 8.0 : -8.0) * Double(1 - progress)
        return Image(uiImage: Self.headImage)
            .resizable()
            .scaledToFit()
            .frame(width: Self.headSize, height: Self.headSize)
            .rotationEffect(.degrees(tilt + sin(step) * 7))
            .offset(y: -abs(sin(step)) * 4)
            .keyframeAnimator(initialValue: Hop(), trigger: reached) { content, hop in
                content
                    .scaleEffect(hop.scale, anchor: .bottom)
                    .offset(y: hop.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-22, duration: 0.22)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.22, duration: 0.22)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
            .position(x: spot.x, y: spot.y - Self.headSize * 0.32)
            .accessibilityHidden(true)
    }

    private struct Hop {
        var lift: CGFloat = 0
        var scale: CGFloat = 1
    }

    // MARK: - Geometria

    private var range: ClosedRange<Double> {
        let low = min(startKg, goalKg), high = max(startKg, goalKg)
        let pad = max((high - low) * 0.12, 1.5)
        return (low - pad)...(high + pad)
    }

    private func point(at fraction: CGFloat, in plot: CGRect) -> CGPoint {
        let value = Self.weight(from: startKg, to: goalKg, at: fraction)
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

    private func axisLabel(_ text: String, lit: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? AnyShapeStyle(.indigo) : AnyShapeStyle(.tertiary))
            .fixedSize()
            .animation(Motion.quick, value: lit)
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
