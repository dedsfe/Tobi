import SwiftUI

/// Card que abre ao tocar na barra de baixo: calorias contra a meta e um anel por nutriente.
struct GoalsCard: View {
    let total: Nutrition
    let goal: Int
    /// Conteúdo visível. Desliga antes do card sair, pra o de dentro sumir primeiro.
    let isOpen: Bool
    /// Liga logo depois de aparecer: dispara a cascata (barra enche, anéis desenham, números sobem).
    @State private var revealed = false

    private var kcal: Int { Int(total.kcal.rounded()) }
    private var isOver: Bool { kcal > goal }

    // Fatias das calorias por macro. O onboarding calcula as da pessoa; sem ele, 50% carbo, 20% proteína, 30% gordura.
    @AppStorage("carbsShare") private var carbsShare = 0.5
    @AppStorage("proteinShare") private var proteinShare = 0.2
    @AppStorage("fatShare") private var fatShare = 0.3

    private var targets: [Target] {
        let kcalGoal = Double(goal)
        return [
            Target(name: "Carboidratos", value: total.carbs, goal: kcalGoal * carbsShare / 4, unit: "g", color: Theme.carbs),
            Target(name: "Proteína", value: total.protein, goal: kcalGoal * proteinShare / 4, unit: "g", color: Theme.protein),
            Target(name: "Gordura", value: total.fat, goal: kcalGoal * fatShare / 9, unit: "g", color: Theme.fat),
            Target(name: "Açúcar", value: total.sugar, goal: 50, unit: "g", color: Theme.sugar, isLimit: true),
            Target(name: "Fibras", value: total.fiber, goal: 30, unit: "g", color: Theme.fiber),
            Target(name: "Sódio", value: total.sodium, goal: 2300, unit: "mg", color: Theme.sodium, isLimit: true),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metas")
                .font(.system(size: 18, weight: .bold))
                .reveal(revealed, order: 0)

            VStack(spacing: 8) {
                HStack {
                    Text("🔥 Calorias")
                    Spacer()
                    Text("\((revealed ? kcal : 0).formatted()) / \(goal.formatted())")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(revealed ? kcal : 0)))
                        .animation(revealed ? Motion.cascade(1) : Motion.exit, value: revealed)
                }
                .font(.system(size: 15, weight: .semibold))
                .reveal(revealed, order: 1)

                ProgressBar(progress: revealed && goal > 0 ? Double(kcal) / Double(goal) : 0,
                            color: isOver ? .orange : Theme.carbs)
                    .animation(revealed ? Motion.cascade(2) : Motion.exit, value: revealed)
                    .reveal(revealed, order: 1)
            }

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(targets.prefix(4).enumerated()), id: \.element.id) { index, target in
                        NutrientRing(target: target, revealed: revealed, order: 2 + index)
                            .frame(maxWidth: .infinity)
                    }
                }
                // Segunda linha alinhada nas colunas do meio da primeira.
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    ForEach(Array(targets.suffix(2).enumerated()), id: \.element.id) { index, target in
                        NutrientRing(target: target, revealed: revealed, order: 6 + index)
                            .frame(maxWidth: .infinity)
                    }
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .animation(Motion.quick, value: total)
        .onAppear { revealed = isOpen }
        .onChange(of: isOpen) { _, open in revealed = open }
    }
}

struct Target: Identifiable {
    let name: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    /// Teto (açúcar, sódio): o bom é ficar abaixo. O resto é meta pra chegar.
    var isLimit = false

    var id: String { name }
    /// "de 120" ou "até 2.300". A unidade já está dentro do anel.
    var goalLabel: String { "\(isLimit ? "até" : "de") \(Int(goal.rounded()).formatted())" }
    var progress: Double { goal > 0 ? value / goal : 0 }
}

private struct NutrientRing: View {
    let target: Target
    let revealed: Bool
    let order: Int

    private var value: Double { revealed ? target.value : 0 }
    private var progress: Double { revealed ? min(target.progress, 1) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(target.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(Int(value.rounded()).formatted())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        // 2.345 mg de sódio já não cabe no anel: encolhe em vez de vazar.
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: value))
                    Text(target.unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                // Por dentro do traço do anel.
                .frame(maxWidth: 40)
            }
            .frame(width: 50, height: 50)

            VStack(spacing: 1) {
                Text(target.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(target.goalLabel)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .animation(revealed ? Motion.cascade(order) : Motion.exit, value: revealed)
        .reveal(revealed, order: order)
    }
}

private struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
        }
        .frame(height: 6)
    }
}

#Preview {
    ZStack {
        Theme.background
        GoalsCard(total: Nutrition(kcal: 374, protein: 21, carbs: 1, fat: 31, sodium: 758), goal: 2000, isOpen: true)
            .padding(24)
    }
}
