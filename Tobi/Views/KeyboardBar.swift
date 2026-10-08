import SwiftUI

/// Barra de baixo enquanto o teclado está aberto: calorias e macros, e as ações rápidas.
struct KeyboardBar: View {
    let total: Nutrition
    let goal: Int
    let dictation: Dictation
    let glass: Namespace.ID
    let onMic: () -> Void
    let onScan: () -> Void
    let onDismiss: () -> Void
    /// Tocou nos totais: fecha o teclado e abre as metas.
    let onTotals: () -> Void

    @AppStorage("proteinShare") private var proteinShare = 0.2

    private var kcal: Int { Int(total.kcal.rounded()) }

    var body: some View {
        HStack(spacing: 10) {
            totals
            if dictation.isRecording {
                listening
            } else {
                action("Ditar", "mic.fill", .blue, id: "mic", onMic)
                action("Ler código de barras", "barcode.viewfinder", .purple, id: "scan", onScan)
            }
            action("Fechar teclado", "keyboard.chevron.compact.down", .primary, id: "close", onDismiss)
        }
    }

    /// As calorias em cima e os macros embaixo, na mesma pílula que vira a barra de totais quando o teclado fecha.
    private var totals: some View {
        Button(action: onTotals) { totalsContent }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("totals", in: glass)
            // Ditando, a pílula fica do tamanho dos números e o microfone leva o resto: nada corta.
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(kcal) calorias, \(grams(total.carbs)) de carboidrato, \(grams(total.protein)) de \(proteinGoal) de proteína, \(grams(total.fat)) de gordura. Ver metas")
    }

    /// Meta de proteína em gramas: a mesma conta do cartão de metas.
    private var proteinGoal: Int { Int((Double(goal) * proteinShare / 4).rounded()) }

    private var totalsContent: some View {
        VStack(spacing: 1) {
            Text("\(Text("🔥 ").font(.system(size: 13)))\(calories)")
            macros
        }
        .monospacedDigit()
        .lineLimit(1)
        // Cada linha é um texto só: número grande encolhe a linha inteira, nunca corta com reticências.
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText())
        .padding(.horizontal, 14)
        .frame(maxWidth: dictation.isRecording ? nil : .infinity)
        .frame(height: 44)
        .contentShape(.capsule)
        .animation(Motion.quick, value: total)
    }

    /// "C 250  P 45/120  G 70": a proteína mostra quanto falta pra meta e ganha cor quando chega lá.
    private var macros: Text {
        let protein = number(total.protein, color: total.protein.rounded() >= Double(proteinGoal) ? Theme.protein : nil)
        let proteinGoalText = Text("/\(proteinGoal.formatted())")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
        return Text("""
            \(letter("C", Theme.carbs))\(number(total.carbs))\
            \(letter("  P", Theme.protein))\(protein)\(proteinGoalText)\
            \(letter("  G", Theme.fat))\(number(total.fat))
            """)
    }

    private var calories: Text {
        Text(kcal.formatted())
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(kcal > goal ? Color.orange : Color.primary)
    }

    private func letter(_ letter: String, _ color: Color) -> Text {
        Text(letter + " ")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color)
    }

    private func number(_ value: Double, color: Color? = nil) -> Text {
        Text(Int(value.rounded()).formatted())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
    }

    private func grams(_ value: Double) -> String { "\(Int(value.rounded())) gramas" }

    /// Enquanto dita, o microfone engole os vizinhos e vira uma cápsula viva: a voz em barrinhas
    /// e o botão de parar.
    private var listening: some View {
        Button(action: onMic) {
            HStack(spacing: 12) {
                VoiceBars(dictation: dictation)
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("mic", in: glass)
        .accessibilityLabel("Parar ditado")
    }

    private func action(_ title: String, _ icon: String, _ color: Color, id: String,
                        _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(id, in: glass)
        .accessibilityLabel(title)
    }
}

#Preview {
    @Previewable @Namespace var glass
    ZStack {
        Theme.background
        KeyboardBar(total: Nutrition(kcal: 374, protein: 28, carbs: 41, fat: 9), goal: 2000, dictation: Dictation(),
                    glass: glass, onMic: {}, onScan: {}, onDismiss: {}, onTotals: {})
            .padding(24)
    }
}
