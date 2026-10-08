import SwiftUI

/// "Pensando" e depois "puff": enquanto pensa, mostra um texto com brilho de cores passando;
/// quando termina, o conteúdo aparece num reveal (desfoque e escala voltando ao normal).
/// Cada mudança de `trigger` pensa de novo. Com Reduzir Movimento, mostra o conteúdo direto.
struct ThinkingReveal<Content: View>: View {
    let trigger: AnyHashable
    var thinkingText = "Calculando"
    var duration: Duration = .milliseconds(650)
    @ViewBuilder let content: Content

    @State private var thinking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            content
                .opacity(thinking ? 0 : 1)
                .blur(radius: thinking ? 8 : 0)
                .scaleEffect(thinking ? 0.9 : 1)
            if thinking {
                ShimmerText(text: thinkingText)
                    .transition(.opacity)
            }
        }
        .task(id: trigger) {
            guard !reduceMotion else { return }
            withAnimation(Motion.quick) { thinking = true }
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.surface) { thinking = false }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: thinking) { wasThinking, isThinking in
            wasThinking && !isThinking
        }
    }
}

/// Texto pensando: as letras fazem "ola" (sobem uma depois da outra) e um degradê de cores amigas passa por elas.
private struct ShimmerText: View {
    let text: String
    @State private var phase: CGFloat = 0
    @State private var waving = false

    private var letters: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .offset(y: waving ? -6 : 2)
                    .animation(.easeInOut(duration: 0.38).repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.07), value: waving)
            }
        }
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .padding(.vertical, 8)
    }

    var body: some View {
        letters
            .hidden()
            .overlay {
                LinearGradient(colors: [.indigo, .purple, .pink, .orange, .blue, .indigo],
                               startPoint: UnitPoint(x: phase - 1, y: 0.5),
                               endPoint: UnitPoint(x: phase + 1, y: 0.5))
                    .mask { letters }
            }
            .onAppear {
                waving = true
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}
