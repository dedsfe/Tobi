import SwiftUI

/// Cores da voz, dos graves (esquerda) aos agudos (direita): as mesmas dos macros do app.
private let voiceColors = [Theme.protein, Theme.carbs, Theme.sugar, Theme.fat, Theme.sodium]

/// Luz que sobe de baixo enquanto a pessoa dita. Cada faixa da voz é um lobo de cor que cresce
/// com a sílaba; parado, ele só respira. Lê `dictation.levels` aqui dentro, de propósito: assim só
/// esta view redesenha a cada buffer de áudio, não a tela inteira.
struct VoiceGlow: View {
    let dictation: Dictation
    @State private var display = GlowLevels()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A luz é toda desfocada, então desenhar em 1/4 da resolução e ampliar dá a mesma imagem
    /// com 16 vezes menos pixel pra borrar a cada quadro.
    private static let downscale: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            // O desfoque clareia perto da borda do desenho. Desenhando mais largo que a tela,
            // essa borda clara fica fora dela e a luz encosta inteira nas laterais.
            let overscan = proxy.size.width * 0.18
            glow
                .frame(width: (proxy.size.width + overscan * 2) / Self.downscale,
                       height: proxy.size.height / Self.downscale)
                .drawingGroup()
                .scaleEffect(Self.downscale, anchor: .topLeading)
                .offset(x: -overscan)
        }
        .mask {
            LinearGradient(colors: [.clear, .black.opacity(0.85), .black], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var glow: some View {
        // 60 quadros bastam pra luz desfocada; 120 só gastava bateria e engasgava o vidro por cima.
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let levels = display.step(toward: dictation.levels, at: time)
            Canvas { context, size in
                context.addFilter(.blur(radius: 26 / Self.downscale))
                if colorScheme == .dark { context.blendMode = .plusLighter }
                let count = levels.count
                for (band, level) in levels.enumerated() {
                    // Cada lobo passeia devagar no próprio ritmo, pra luz nunca ficar parada.
                    let drift = sin(time * (0.6 + Double(band) * 0.17) + Double(band) * 1.9) * size.width * 0.05
                    let breathe = (sin(time * 1.4 + Double(band)) + 1) * 0.04
                    let strength = CGFloat(min(level + Float(breathe), 1))
                    let width = size.width * 0.46
                    let height = size.height * (0.28 + strength * 0.95)
                    let center = size.width * (CGFloat(band) + 0.5) / CGFloat(count) + drift
                    let rect = CGRect(x: center - width / 2, y: size.height - height * 0.62,
                                      width: width, height: height)
                    context.opacity = 0.5 + strength * 0.5
                    context.fill(Ellipse().path(in: rect), with: .color(voiceColors[band % voiceColors.count]))
                }
                // Miolo claro quando a voz sobe: dá a sensação de "acendeu".
                let peak = CGFloat(levels.max() ?? 0)
                context.opacity = peak * 0.55
                let core = CGRect(x: size.width * 0.2, y: size.height * (1 - 0.35 * peak),
                                  width: size.width * 0.6, height: size.height * 0.5)
                context.fill(Ellipse().path(in: core), with: .color(.white))
            }
        }
    }
}

/// Barrinhas dentro do botão do microfone enquanto dita: mesma voz, mesmas cores, em miniatura.
struct VoiceBars: View {
    let dictation: Dictation
    @State private var display = GlowLevels()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let levels = display.step(toward: dictation.levels, at: timeline.date.timeIntervalSinceReferenceDate)
            HStack(spacing: 3) {
                ForEach(levels.indices, id: \.self) { band in
                    Capsule()
                        .fill(voiceColors[band % voiceColors.count])
                        .frame(width: 4, height: 5 + CGFloat(levels[band]) * 19)
                }
            }
            .frame(height: 24)
        }
        .accessibilityHidden(true)
    }
}

/// Os níveis chegam ~40 vezes por segundo; a tela desenha 120. Aqui cada quadro anda um pouco
/// em direção ao último nível, pra luz escorrer em vez de pular.
@MainActor
private final class GlowLevels {
    private var values = [Float](repeating: 0, count: VoiceSpectrum.bandCount)
    private var lastTime: Double?

    func step(toward target: [Float], at time: Double) -> [Float] {
        let delta = Float(min(time - (lastTime ?? time), 1.0 / 30))
        lastTime = time
        for index in values.indices where index < target.count {
            let rate: Float = target[index] > values[index] ? 18 : 6
            values[index] += (target[index] - values[index]) * min(delta * rate, 1)
        }
        return values
    }
}
