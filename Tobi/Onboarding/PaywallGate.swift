import SwiftUI
import SwiftData

/// O app travado: sem plano e sem as 24 horas, o Tobi no palco e os planos, sem X.
/// Em cima, a prova: o que a pessoa fez com o Tobi nas 24 horas. Sem nada anotado, volta a promessa.
/// Destrava quando a compra ou a restauração dá certo, depois do confete.
struct LockedPaywall: View {
    let onUnlock: () -> Void

    @State private var tobi = TobiPerformance(mood: .attentive)
    @Query(sort: \DayNote.day) private var notes: [DayNote]

    private var story: PaywallStep.Story {
        let since = TobiStore.freePassUntil.map { $0.addingTimeInterval(-TobiStore.freePassHours * 3600) }
            ?? .now.addingTimeInterval(-TobiStore.freePassHours * 3600)
        if let recap = PaywallRecap(notes: notes, since: since) { return .recap(recap) }
        #if DEBUG
        // Sem refeições no aparelho de teste, mostra o resumo com números de exemplo pra revisar o desenho.
        return .recap(.sample)
        #else
        return .onboarding
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            TobiStage(performance: tobi, onPet: { tobi.pets += 1 })
                #if DEBUG
                .overlay(alignment: .topTrailing) {
                    // Só no Debug: volta pro app sem comprar, pra revisar a tela travada quantas vezes quiser.
                    Button("Destravar", systemImage: "lock.open", action: onUnlock)
                        .font(.system(size: 14, weight: .semibold))
                        .buttonStyle(.glass)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                #endif
            PaywallStep(declined: .constant(false), story: story, onFinish: onUnlock)
                .frame(maxHeight: .infinity)
                .environment(\.tobiReactions, TobiReactions(
                    acknowledge: {
                        tobi.mood = .joyful
                        tobi.entering = false
                        tobi.acknowledgements += 1
                    },
                    celebrate: { perform(.celebrating) },
                    mood: perform
                ))
        }
        .background { Theme.background }
    }

    private func perform(_ mood: TobiIdleBehavior.Mood) {
        tobi.mood = mood
        tobi.entering = true
        tobi.scene += 1
    }
}

// MARK: - Resumo das 24 horas

/// O que a pessoa anotou desde que as 24 horas começaram: calorias, alimentos e proteína.
struct PaywallRecap: Equatable {
    var kcal: Int
    var foods: Int
    var proteinGrams: Int

    static let sample = PaywallRecap(kcal: 2140, foods: 6, proteinGrams: 84)

    /// nil se não tem nenhum alimento reconhecido no período.
    init?(notes: [DayNote], since: Date, parser: FoodParser = .shared) {
        let start = Calendar.current.startOfDay(for: since)
        var kcal = 0.0
        var protein = 0.0
        var foods = 0
        for note in notes where note.day >= start {
            for line in note.text.split(separator: "\n") {
                let estimate = parser.estimate(String(line))
                foods += estimate.items.filter(\.isRecognized).count
                kcal += estimate.total.kcal
                protein += estimate.total.protein
            }
        }
        guard foods > 0 else { return nil }
        self.init(kcal: Int(kcal.rounded()), foods: foods, proteinGrams: Int(protein.rounded()))
    }

    init(kcal: Int, foods: Int, proteinGrams: Int) {
        self.kcal = kcal
        self.foods = foods
        self.proteinGrams = proteinGrams
    }
}

/// A prova em cima dos planos: as calorias que o Tobi contou sobem num número gigante,
/// com um toque a cada degrau; quando assenta, ele pula, fica índigo e os destaques chegam em vidro.
struct RecapHero: View {
    let recap: PaywallRecap
    let isShown: Bool

    @State private var counted = 0
    @State private var landed = false
    @State private var chips = 0
    @State private var ticks = 0
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Olha o que a gente\nfez em \(Text("24 horas").foregroundStyle(.indigo))")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .reveal(isShown, order: 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(counted.formatted())
                    .font(.system(size: 62, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(landed ? Color.indigo : Color.primary)
                    .contentTransition(.numericText(value: Double(counted)))
                Text("cal")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .keyframeAnimator(initialValue: 1.0, trigger: landed) { number, scale in
                number.scaleEffect(scale, anchor: .bottomLeading)
            } keyframes: { _ in
                SpringKeyframe(1.08, duration: 0.14)
                SpringKeyframe(1, duration: 0.4)
            }
            .padding(.top, 10)
            .reveal(isShown, order: 1)

            Text("que eu contei pra você, sem conta nenhuma")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .reveal(isShown, order: 2)

            HStack(spacing: 10) {
                RecapChip(value: recap.foods.formatted(), label: recap.foods == 1 ? "alimento" : "alimentos",
                          isShown: isShown && chips >= 1)
                RecapChip(value: "\(recap.proteinGrams) g", label: "de proteína", isShown: isShown && chips >= 2)
                RecapChip(value: "0", label: "contas suas", isShown: isShown && chips >= 3)
            }
            .padding(.top, 16)
        }
        .sensoryFeedback(.selection, trigger: ticks)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: landed)
        .sensoryFeedback(.impact(weight: .light), trigger: chips)
        .task { await count() }
    }

    /// Sobe rápido e freia no fim, como contador de placar.
    private func count() async {
        guard !reduceMotion else {
            counted = recap.kcal
            landed = true
            chips = 3
            return
        }
        tobi.mood(.presenting)
        try? await Task.sleep(for: .milliseconds(300))
        let steps = 26
        for step in 1...steps {
            let progress = 1 - pow(1 - Double(step) / Double(steps), 3)
            withAnimation(Motion.quick) { counted = Int(Double(recap.kcal) * progress) }
            if step.isMultiple(of: 2) { ticks += 1 }
            try? await Task.sleep(for: .milliseconds(42))
        }
        withAnimation(Motion.surface) {
            counted = recap.kcal
            landed = true
        }
        tobi.acknowledge()
        try? await Task.sleep(for: .milliseconds(220))
        for chip in 1...3 {
            withAnimation(Motion.surface) { chips = chip }
            try? await Task.sleep(for: .milliseconds(140))
        }
    }
}

/// Um destaque do resumo em vidro: o número grande e o que ele é.
private struct RecapChip: View {
    let value: String
    let label: String
    let isShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .scaleEffect(isShown ? 1 : 0.82, anchor: .bottom)
        .reveal(isShown, order: 0)
        .animation(Motion.surface, value: isShown)
    }
}
