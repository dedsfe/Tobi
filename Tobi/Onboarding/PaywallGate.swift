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

/// O que a pessoa anotou desde que as 24 horas começaram: calorias, alimentos, proteína
/// e em quantos dias, pra comparar com a meta diária.
struct PaywallRecap: Equatable {
    var kcal: Int
    var foods: Int
    var proteinGrams: Int
    var days: Int

    static let sample = PaywallRecap(kcal: 2140, foods: 6, proteinGrams: 84, days: 1)

    /// Quanto da meta de calorias foi, na média dos dias anotados (1 = bateu a meta).
    func share(of goal: Int) -> Double {
        guard goal > 0, days > 0 else { return 0 }
        return Double(kcal) / Double(goal * days)
    }

    /// nil se não tem nenhum alimento reconhecido no período.
    init?(notes: [DayNote], since: Date, parser: FoodParser = .shared) {
        let start = Calendar.current.startOfDay(for: since)
        var kcal = 0.0
        var protein = 0.0
        var foods = 0
        var days = 0
        for note in notes where note.day >= start {
            var foodsToday = 0
            for line in note.text.split(separator: "\n") {
                let estimate = parser.estimate(String(line))
                foodsToday += estimate.items.filter(\.isRecognized).count
                kcal += estimate.total.kcal
                protein += estimate.total.protein
            }
            foods += foodsToday
            if foodsToday > 0 { days += 1 }
        }
        guard foods > 0 else { return nil }
        self.init(kcal: Int(kcal.rounded()), foods: foods, proteinGrams: Int(protein.rounded()), days: days)
    }

    init(kcal: Int, foods: Int, proteinGrams: Int, days: Int) {
        self.kcal = kcal
        self.foods = foods
        self.proteinGrams = proteinGrams
        self.days = days
    }
}

/// A prova em cima dos planos: as calorias que o Tobi contou sobem num número gigante,
/// com um toque a cada degrau, e a barra da meta enche junto. Quando assenta, o número pula,
/// fica índigo e os destaques chegam em vidro.
struct RecapHero: View {
    let recap: PaywallRecap
    let isShown: Bool

    /// A meta salva em "Suas metas".
    @AppStorage("dailyGoal") private var goal = 2000

    @State private var counted = 0
    @State private var landed = false
    @State private var chips = 0
    @State private var ticks = 0
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Olha o que a gente\nfez em \(Text("24 horas").foregroundStyle(.indigo))")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .reveal(isShown, order: 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(counted.formatted())
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
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

            GoalBar(share: shareSoFar, days: recap.days)
                .padding(.top, 8)
                .reveal(isShown, order: 2)

            HStack(spacing: 10) {
                RecapChip(value: recap.foods.formatted(), label: recap.foods == 1 ? "alimento anotado" : "alimentos anotados",
                          isShown: isShown && chips >= 1)
                RecapChip(value: "\(recap.proteinGrams) g", label: "de proteína", isShown: isShown && chips >= 2)
            }
            .padding(.top, 16)
        }
        .sensoryFeedback(.selection, trigger: ticks)
        .sensoryFeedback(.impact(weight: .medium), trigger: shareSoFar >= 1)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: landed)
        .sensoryFeedback(.impact(weight: .light), trigger: chips)
        .task { await count() }
    }

    /// A barra anda junto com o número que está subindo.
    private var shareSoFar: Double {
        recap.kcal > 0 ? recap.share(of: goal) * Double(counted) / Double(recap.kcal) : 0
    }

    /// Sobe rápido e freia no fim, como contador de placar.
    private func count() async {
        guard !reduceMotion else {
            counted = recap.kcal
            landed = true
            chips = 2
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
        for chip in 1...2 {
            withAnimation(Motion.surface) { chips = chip }
            try? await Task.sleep(for: .milliseconds(140))
        }
    }
}

/// Quanto da meta de calorias a pessoa fez: a barra índigo enche e o texto acompanha.
/// Passou da meta, a barra fica cheia e o texto diz quanto passou, sem bronca.
private struct GoalBar: View {
    let share: Double
    let days: Int

    private var percent: Int { Int((share * 100).rounded()) }

    private var caption: String {
        if percent > 100 { return "\(percent - 100)% acima da meta" + (days > 1 ? ", na média" : "") }
        return days > 1 ? "\(percent)% da sua meta, na média" : "\(percent)% da sua meta do dia"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(.primary.opacity(0.08))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient(colors: [.indigo.opacity(0.55), .indigo],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, proxy.size.width * min(1, share)))
                    }
                }
            Text(caption)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(percent)))
        }
        .animation(Motion.quick, value: share)
        .accessibilityElement(children: .combine)
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
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .scaleEffect(isShown ? 1 : 0.82, anchor: .bottom)
        .reveal(isShown, order: 0)
        .animation(Motion.surface, value: isShown)
    }
}
