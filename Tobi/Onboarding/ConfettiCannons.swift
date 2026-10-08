import SwiftUI

/// A comemoração da compra: dois canhões de confete nos cantos de baixo e um estouro do meio,
/// em duas rajadas. Cada papel sobe rápido, freia no ar, vira, gira e desce balançando até sumir.
/// Fica preso embaixo e cresce pra cima, cobrindo a tela toda. Com Reduzir Movimento, só vibra.
struct ConfettiCannons: View {
    @State private var start: Date?
    @State private var volleys = 0
    @State private var crackles = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sorteado uma vez só: se a tela redesenhar, cada papel continua no mesmo caminho.
    @State private var pieces = Piece.burst()

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { context in
            Canvas { canvas, size in
                guard let start else { return }
                let time = context.date.timeIntervalSince(start)
                let paw = canvas.resolveSymbol(id: 0)
                for piece in pieces {
                    piece.draw(in: canvas, size: size, time: time, paw: paw)
                }
            } symbols: {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tag(0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .heavy), trigger: volleys)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: crackles)
        .task {
            volleys += 1
            if !reduceMotion { start = .now }
            // Estalinhos enquanto o papel se espalha, e a segunda rajada no meio deles.
            for tick in 1...12 {
                try? await Task.sleep(for: .milliseconds(55 + tick * 6))
                if tick == 5 { volleys += 1 } else { crackles += 1 }
            }
        }
    }
}

private struct Piece {
    enum Shape { case strip, dot, paw }

    /// De onde sai: x em fração da largura, y em pontos acima do fundo.
    let originX: Double
    let originY: Double
    let velocity: CGVector
    let delay: Double
    let life: Double
    let color: Color
    let shape: Shape
    let width: Double
    let height: Double
    let spin: Double
    let spinRate: Double
    let flipRate: Double
    let flipPhase: Double
    let sway: Double
    let swayRate: Double
    let swayPhase: Double

    /// Freio do ar e gravidade: sobe rápido, para lá em cima e desce devagar, como papel.
    private static let drag = 3.0
    private static let gravity = 820.0

    private static let colors: [Color] = [Theme.protein, Theme.carbs, Theme.fat, Theme.sugar,
                                          Theme.fiber, Theme.sodium, .indigo, .indigo.mix(with: .white, by: 0.4)]

    static func burst() -> [Piece] {
        var pieces: [Piece] = []
        // Cantos: mira pra cima e pra dentro. Meio: leque pra cima, saindo de onde fica o botão.
        for _ in 0..<56 { pieces.append(make(x: 0, y: 30, angles: 58...82, speeds: 1700...2600)) }
        for _ in 0..<56 { pieces.append(make(x: 1, y: 30, angles: 98...122, speeds: 1700...2600)) }
        for _ in 0..<40 { pieces.append(make(x: 0.5, y: 110, angles: 55...125, speeds: 1100...1900)) }
        return pieces
    }

    private static func make(x: Double, y: Double, angles: ClosedRange<Double>, speeds: ClosedRange<Double>) -> Piece {
        let angle = Double.random(in: angles) * .pi / 180
        let speed = Double.random(in: speeds)
        // Metade sai na primeira rajada, metade na segunda.
        let delay = Bool.random() ? Double.random(in: 0...0.06) : Double.random(in: 0.3...0.38)
        let roll = Double.random(in: 0...1)
        let shape: Shape = roll < 0.6 ? .strip : roll < 0.85 ? .dot : .paw
        return Piece(originX: x, originY: y,
                     velocity: CGVector(dx: cos(angle) * speed, dy: -sin(angle) * speed),
                     delay: delay, life: .random(in: 2.6...3.4),
                     color: colors.randomElement()!, shape: shape,
                     width: .random(in: 6...9), height: .random(in: 11...16),
                     spin: .random(in: 0...360), spinRate: .random(in: -380...380),
                     flipRate: .random(in: 4...10), flipPhase: .random(in: 0...(2 * .pi)),
                     sway: .random(in: 8...26), swayRate: .random(in: 2.5...5), swayPhase: .random(in: 0...(2 * .pi)))
    }

    func draw(in canvas: GraphicsContext, size: CGSize, time: Double, paw: GraphicsContext.ResolvedSymbol?) {
        let t = time - delay
        guard t > 0, t < life else { return }
        let k = Self.drag
        let g = Self.gravity
        let slowed = (1 - exp(-k * t)) / k
        // O balanço só entra depois que o papel perde a força da subida.
        let swaying = sin(t * swayRate + swayPhase) * sway * min(1, t / 0.9)
        let x = originX * size.width + velocity.dx * slowed + swaying
        let y = size.height - originY + g * t / k + (velocity.dy - g / k) * slowed

        var context = canvas
        context.opacity = min(1, (life - t) / 0.6)
        context.translateBy(x: x, y: y)
        context.rotate(by: .degrees(spin + spinRate * t))
        // Virar no ar: achata e desachata, como papel girando de lado.
        context.scaleBy(x: max(0.08, abs(cos(t * flipRate + flipPhase))), y: 1)

        switch shape {
        case .strip:
            let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
        case .dot:
            let radius = width / 2
            context.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                         with: .color(color))
        case .paw:
            guard let paw else { return }
            context.addFilter(.colorMultiply(color))
            context.draw(paw, at: .zero)
        }
    }
}
