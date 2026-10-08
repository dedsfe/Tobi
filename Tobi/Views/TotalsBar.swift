import SwiftUI

/// Barra de vidro flutuando embaixo: calorias do dia e macros.
struct TotalsBar: View {
    let total: Nutrition
    let goal: Int
    let glass: Namespace.ID
    var onTap: () -> Void = {}

    private var kcal: Int { Int(total.kcal.rounded()) }
    private var isOver: Bool { kcal > goal }

    var body: some View {
        Button(action: onTap) { content }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("totals", in: glass)
            .accessibilityLabel("\(kcal) calorias. Ver metas")
    }

    private var content: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 14))
                number(kcal)
                    .foregroundStyle(isOver ? Color.orange : Color.primary)
            }
            // Com número grande, os macros encolhem antes das calorias.
            .layoutPriority(1)
            dot
            macro("C", total.carbs, Theme.carbs)
            dot
            macro("P", total.protein, Theme.protein)
            dot
            macro("G", total.fat, Theme.fat)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.capsule)
        .animation(Motion.quick, value: total)
    }

    private func macro(_ letter: String, _ grams: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(letter)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            number(Int(grams.rounded()))
        }
    }

    private func number(_ value: Int) -> some View {
        Text(value.formatted())
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .monospacedDigit()
            // Nunca quebra linha: encolhe um pouco quando o número não cabe.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText(value: Double(value)))
    }

    private var dot: some View {
        Circle().fill(.tertiary).frame(width: 3, height: 3)
    }
}

#Preview {
    @Previewable @Namespace var glass
    ZStack {
        Theme.background
        TotalsBar(total: Nutrition(kcal: 760, protein: 45, carbs: 90, fat: 20), goal: 2000, glass: glass)
            .padding(32)
    }
}
