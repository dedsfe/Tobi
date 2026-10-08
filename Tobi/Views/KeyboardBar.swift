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
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 13))
                Text(kcal.formatted())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(kcal > goal ? Color.orange : Color.primary)
                    .contentTransition(.numericText(value: Double(kcal)))
            }
            HStack(spacing: 7) {
                macro("C", total.carbs, Theme.carbs)
                macro("P", total.protein, Theme.protein)
                macro("G", total.fat, Theme.fat)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        // Número grande encolhe um pouco em vez de cortar ou quebrar.
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .glassEffectID("totals", in: glass)
        .animation(Motion.quick, value: total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kcal) calorias, \(grams(total.carbs)) de carboidrato, \(grams(total.protein)) de proteína, \(grams(total.fat)) de gordura")
    }

    private func macro(_ letter: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(Int(value.rounded()).formatted())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: value.rounded()))
        }
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
                    glass: glass, onMic: {}, onScan: {}, onDismiss: {})
            .padding(24)
    }
}
