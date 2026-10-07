import SwiftUI

/// O motion do Tobi inteiro sai daqui. Regra: superfície nova *emerge* de onde foi tocada
/// e o conteúdo dela se *revela* em cascata. Nada de animação solta fora destes tokens.
enum Motion {
    /// Abrir e fechar superfícies: cards, barras que viram outra coisa, sheets custom.
    static let surface = Animation.spring(duration: 0.55, bounce: 0.24)
    /// Resposta a toque, números mudando, estados pequenos.
    static let quick = Animation.spring(duration: 0.3, bounce: 0.15)
    /// Intervalo entre itens de uma cascata.
    static let stagger = 0.04
    /// Saída do conteúdo: rápida e junta, pra casca poder fechar logo depois.
    static let exit = Animation.spring(duration: 0.2, bounce: 0)
    static let exitDuration = 0.16

    /// Animação de um item da cascata, já com o atraso da posição dele.
    static func cascade(_ order: Int) -> Animation {
        surface.delay(Double(order) * stagger)
    }

    /// Fecha uma superfície em dois tempos: primeiro o conteúdo some, depois a casca.
    @MainActor
    static func close(content: () -> Void, surface closeSurface: @escaping @MainActor () -> Void) {
        withAnimation(exit, content)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(exitDuration))
            withAnimation(surface, closeSurface)
        }
    }
}

// MARK: - Emerge

/// Superfície que nasce do ponto de origem (por padrão, de baixo): cresce, sobe e ganha foco.
struct EmergeTransition: Transition {
    var anchor: UnitPoint = .bottom

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(EmergeEffect(isVisible: phase.isIdentity, anchor: anchor))
    }
}

private struct EmergeEffect: ViewModifier {
    let isVisible: Bool
    let anchor: UnitPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(isVisible ? 1 : 0)
        } else {
            content
                .opacity(isVisible ? 1 : 0)
                .blur(radius: isVisible ? 0 : 12)
                .scaleEffect(isVisible ? 1 : 0.82, anchor: anchor)
                .offset(y: isVisible ? 0 : (anchor == .top ? -16 : 16))
        }
    }
}

extension Transition where Self == EmergeTransition {
    static var emerge: EmergeTransition { EmergeTransition() }
    static func emerge(from anchor: UnitPoint) -> EmergeTransition { EmergeTransition(anchor: anchor) }
}

// MARK: - Reveal

extension View {
    /// Conteúdo de uma superfície que entra em cascata: `order` define a vez de cada item.
    func reveal(_ isVisible: Bool, order: Int) -> some View {
        modifier(RevealEffect(isVisible: isVisible, order: order))
    }
}

private struct RevealEffect: ViewModifier {
    let isVisible: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || reduceMotion ? 0 : 6)
            .offset(y: isVisible || reduceMotion ? 0 : 10)
            .animation(isVisible ? Motion.cascade(order) : Motion.exit, value: isVisible)
    }
}
