import SwiftUI

/// 1 de 3 do paywall: o Tobi trabalhando em vez de uma lista. Três linhas se escrevem numa notinha,
/// cada uma ganha as calorias, e o widget de verdade, embaixo, acompanha o total.
struct PaywallShowcase: View {
    let isShown: Bool

    private struct Line {
        let text: String
        let kcal: Int
        let carbs: Double
        let protein: Double
        let fat: Double
    }

    private static let lines = [
        Line(text: "2 ovos mexidos", kcal: 182, carbs: 2, protein: 12, fat: 14),
        Line(text: "1 pão francês na chapa", kcal: 190, carbs: 30, protein: 4, fat: 6),
        Line(text: "1 scoop de whey Growth", kcal: 120, carbs: 3, protein: 24, fat: 1.5),
    ]
    private static let goal = 2000
    /// O widget da tela de início tem esse lado; aqui ele encolhe pro quadradinho.
    private static let widgetSide: CGFloat = 158

    /// Letras já escritas em cada linha.
    @State private var typed = Array(repeating: 0, count: lines.count)
    /// Linhas que já ganharam as calorias.
    @State private var counted = 0

    private var done: ArraySlice<Line> { Self.lines.prefix(counted) }
    private var total: Int { done.reduce(0) { $0 + $1.kcal } }
    private var protein: Int { Int(done.reduce(0) { $0 + $1.protein }.rounded()) }

    var body: some View {
        VStack(spacing: 18) {
            feature("Escreve do seu jeito, ele conta tudo") { note }
                .reveal(isShown, order: 0)

            HStack(alignment: .top, spacing: 14) {
                feature("Fala") {
                    tile {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: isShown)
                    }
                }
                .reveal(isShown, order: 1)
                feature("Escaneia o rótulo") {
                    tile {
                        Image(systemName: "barcode.viewfinder")
                            .symbolEffect(.breathe, options: .repeating, isActive: isShown)
                    }
                }
                .reveal(isShown, order: 2)
                feature("Widget") { widget }
                    .reveal(isShown, order: 3)
            }
        }
        .sensoryFeedback(.selection, trigger: counted)
        .task(id: isShown) { await play() }
    }

    // MARK: Peças

    private var note: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Self.lines.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    HStack(spacing: 1) {
                        Text(String(Self.lines[index].text.prefix(typed[index])))
                        // O cursor fica na linha que está sendo escrita.
                        if isTyping(index) {
                            Capsule()
                                .fill(.indigo)
                                .frame(width: 2, height: 20)
                        }
                    }
                    .font(.system(size: 17))
                    .lineLimit(1)
                    Spacer(minLength: 8)
                    if counted > index {
                        Text("\(Self.lines[index].kcal)\(Text(" cal").font(.system(size: 13)))")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.emerge(from: .trailing))
                    }
                }
                .frame(height: 24)
            }

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                Text("\(total.formatted()) cal")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(total)))
                Spacer()
                Text("\(protein) g de proteína")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.protein)
                    .contentTransition(.numericText(value: Double(protein)))
            }
            .monospacedDigit()
        }
        .tobiGlassSurface()
    }

    /// O widget pequeno de verdade, com o total da notinha.
    private var widget: some View {
        let snapshot = WidgetSnapshot(day: .now, kcal: Double(total),
                                      carbs: done.reduce(0) { $0 + $1.carbs },
                                      protein: done.reduce(0) { $0 + $1.protein },
                                      fat: done.reduce(0) { $0 + $1.fat },
                                      goal: Self.goal, carbsShare: 0.5, proteinShare: 0.2, fatShare: 0.3)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    SmallDay(snapshot: snapshot)
                        .frame(width: Self.widgetSide, height: Self.widgetSide)
                        .scaleEffect(proxy.size.width / Self.widgetSide)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func tile(@ViewBuilder _ symbol: () -> some View) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                symbol()
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.indigo)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func feature(_ caption: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 8) {
            content()
            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func isTyping(_ index: Int) -> Bool {
        counted == index && typed[index] > 0
    }

    // MARK: Coreografia

    private func play() async {
        typed = Array(repeating: 0, count: Self.lines.count)
        counted = 0
        guard isShown, await wait(500) else { return }
        for (index, line) in Self.lines.enumerated() {
            for count in 1...line.text.count {
                typed[index] = count
                guard await wait(30) else { return }
            }
            guard await wait(180) else { return }
            withAnimation(Motion.surface) { counted = index + 1 }
            guard await wait(360) else { return }
        }
    }

    private func wait(_ milliseconds: Int) async -> Bool {
        (try? await Task.sleep(for: .milliseconds(milliseconds))) != nil
    }
}
