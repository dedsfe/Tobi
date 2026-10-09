import SwiftUI

/// 1 de 3 do paywall: um bentô de vidro com o Tobi trabalhando. Em cima, três linhas se escrevem
/// numa notinha e ganham as calorias; embaixo, seis quadradinhos, e o widget de verdade acompanha o total.
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
    private static let gap: CGFloat = 10
    private static let radius: CGFloat = 24
    private static let tileHeight: CGFloat = 100
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
        VStack(spacing: Self.gap) {
            note
                .reveal(isShown, order: 0)
            HStack(spacing: Self.gap) {
                tile("Fala", order: 1) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers, options: .repeating, isActive: isShown)
                }
                tile("Escaneia o rótulo", order: 2) {
                    Image(systemName: "barcode.viewfinder")
                        .symbolEffect(.breathe, options: .repeating, isActive: isShown)
                }
                widget
                    .reveal(isShown, order: 3)
            }
            HStack(spacing: Self.gap) {
                tile("Whey, marcas e fast food", order: 4) {
                    Image(systemName: "dumbbell.fill")
                        .symbolEffect(.bounce, value: counted == Self.lines.count)
                }
                tile("Macros sob medida", order: 5) {
                    Image(systemName: "chart.pie.fill")
                        .symbolEffect(.bounce, value: counted == Self.lines.count)
                }
                tile("Lembretes", order: 6) {
                    Image(systemName: "bell.badge.fill")
                        .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.5)), isActive: isShown)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: counted)
        .task(id: isShown) { await play() }
    }

    // MARK: Peças

    /// O quadrado grande do bentô: a notinha se escrevendo.
    private var note: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Escreve do seu jeito, ele conta tudo", systemImage: "pencil.and.scribble")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach(Self.lines.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    HStack(spacing: 1) {
                        Text(String(Self.lines[index].text.prefix(typed[index])))
                        // O cursor fica na linha que está sendo escrita.
                        if isTyping(index) {
                            Capsule()
                                .fill(.indigo)
                                .frame(width: 2, height: 19)
                        }
                    }
                    .font(.system(size: 16))
                    .lineLimit(1)
                    Spacer(minLength: 8)
                    if counted > index {
                        Text("\(Self.lines[index].kcal)\(Text(" cal").font(.system(size: 12)))")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.emerge(from: .trailing))
                    }
                }
                .frame(height: 22)
            }

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                Text("\(total.formatted()) cal")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(total)))
                Spacer()
                Text("\(protein) g de proteína")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.protein)
                    .contentTransition(.numericText(value: Double(protein)))
            }
            .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.radius))
    }

    /// O widget pequeno de verdade, com o total da notinha. Ele mesmo diz o que é: sem legenda.
    private var widget: some View {
        let snapshot = WidgetSnapshot(day: .now, kcal: Double(total),
                                      carbs: done.reduce(0) { $0 + $1.carbs },
                                      protein: done.reduce(0) { $0 + $1.protein },
                                      fat: done.reduce(0) { $0 + $1.fat },
                                      goal: Self.goal, carbsShare: 0.5, proteinShare: 0.2, fatShare: 0.3)
        return GeometryReader { proxy in
            SmallDay(snapshot: snapshot)
                .frame(width: Self.widgetSide, height: Self.widgetSide)
                .scaleEffect(min(proxy.size.width, proxy.size.height) / Self.widgetSide)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.tileHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.radius))
    }

    private func tile(_ caption: String, order: Int, @ViewBuilder _ symbol: () -> some View) -> some View {
        VStack(spacing: 6) {
            symbol()
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.indigo)
                .frame(maxHeight: .infinity)
            Text(caption)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: Self.tileHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.radius))
        .reveal(isShown, order: order)
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
