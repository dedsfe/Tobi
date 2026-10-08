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

/// O que a pessoa anotou desde que as 24 horas começaram: calorias e macros,
/// e em quantos dias, pra comparar com as metas diárias.
struct PaywallRecap: Equatable {
    var kcal: Int
    var carbsGrams: Int
    var proteinGrams: Int
    var fatGrams: Int
    var days: Int

    static let sample = PaywallRecap(kcal: 2140, carbsGrams: 236, proteinGrams: 112, fatGrams: 74, days: 1)

    /// Quanto da meta de calorias foi, na média dos dias anotados (1 = bateu a meta).
    func share(of goal: Int) -> Double {
        guard goal > 0, days > 0 else { return 0 }
        return Double(kcal) / Double(goal * days)
    }

    /// nil se não tem nenhum alimento reconhecido no período.
    init?(notes: [DayNote], since: Date, parser: FoodParser = .shared) {
        let start = Calendar.current.startOfDay(for: since)
        var total = [Nutrition]()
        var days = 0
        for note in notes where note.day >= start {
            let estimates = note.text.split(separator: "\n").map { parser.estimate(String($0)) }
            guard estimates.contains(where: { $0.items.contains(where: \.isRecognized) }) else { continue }
            total += estimates.map(\.total)
            days += 1
        }
        guard days > 0 else { return nil }
        let sum = total.total
        self.init(kcal: Int(sum.kcal.rounded()), carbsGrams: Int(sum.carbs.rounded()),
                  proteinGrams: Int(sum.protein.rounded()), fatGrams: Int(sum.fat.rounded()), days: days)
    }

    init(kcal: Int, carbsGrams: Int, proteinGrams: Int, fatGrams: Int, days: Int) {
        self.kcal = kcal
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.days = days
    }
}

/// A prova em cima dos planos: as calorias que o Tobi contou sobem num número gigante, com um toque
/// a cada degrau, e os anéis de carboidratos, proteína e gordura enchem junto, no desenho das metas do app.
/// Quando assenta, o número pula e fica índigo. A barra da meta só aparece a partir de metade do dia
/// (menos que isso parece falha, quando a pessoa só anotou um pedaço).
struct RecapHero: View {
    let recap: PaywallRecap
    let isShown: Bool

    // A meta e as fatias dos macros salvas em "Suas metas" (sem elas, as mesmas da tela de metas).
    @AppStorage("dailyGoal") private var goal = 2000
    @AppStorage("carbsShare") private var carbsShare = 0.5
    @AppStorage("proteinShare") private var proteinShare = 0.2
    @AppStorage("fatShare") private var fatShare = 0.3

    @State private var counted = 0
    @State private var tiles = 0
    @State private var ticks = 0
    @State private var landed = false
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsGoal: Bool { recap.share(of: goal) >= 0.5 }

    /// O quanto do número já subiu (0 a 1): os anéis andam junto.
    private var progress: Double {
        recap.kcal > 0 ? Double(counted) / Double(recap.kcal) : (landed ? 1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Olha o que a gente\nfez em \(Text("24 horas").foregroundStyle(.indigo))")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .reveal(isShown, order: 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(counted.formatted())
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(landed ? Color.indigo : Color.primary)
                    .contentTransition(.numericText(value: Double(counted)))
                Text("cal")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .keyframeAnimator(initialValue: 1.0, trigger: landed) { number, scale in
                number.scaleEffect(scale, anchor: .bottomLeading)
            } keyframes: { _ in
                SpringKeyframe(1.08, duration: 0.14)
                SpringKeyframe(1, duration: 0.4)
            }
            .padding(.top, 6)
            .reveal(isShown, order: 1)

            if showsGoal {
                GoalBar(share: recap.share(of: goal) * progress, days: recap.days)
                    .padding(.top, 4)
                    .reveal(isShown, order: 2)
            }

            HStack(spacing: 10) {
                MacroTile(name: "Carboidratos", grams: Double(recap.carbsGrams) * progress,
                          goal: macroGoal(carbsShare, kcalPerGram: 4), color: Theme.carbs,
                          isShown: isShown && tiles >= 1)
                MacroTile(name: "Proteína", grams: Double(recap.proteinGrams) * progress,
                          goal: macroGoal(proteinShare, kcalPerGram: 4), color: Theme.protein,
                          isShown: isShown && tiles >= 2)
                MacroTile(name: "Gordura", grams: Double(recap.fatGrams) * progress,
                          goal: macroGoal(fatShare, kcalPerGram: 9), color: Theme.fat,
                          isShown: isShown && tiles >= 3)
            }
            .padding(.top, 14)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tiles)
        .sensoryFeedback(.selection, trigger: ticks)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: landed)
        .sensoryFeedback(.impact(weight: .medium), trigger: showsGoal && landed && recap.share(of: goal) >= 1)
        .task { await count() }
    }

    /// Meta do macro em gramas, somando os dias anotados.
    private func macroGoal(_ share: Double, kcalPerGram: Double) -> Double {
        Double(goal) * share / kcalPerGram * Double(max(1, recap.days))
    }

    /// Os anéis chegam um a um; depois tudo sobe junto, rápido e freando no fim, como placar.
    private func count() async {
        guard !reduceMotion else {
            tiles = 3
            counted = recap.kcal
            landed = true
            return
        }
        tobi.mood(.presenting)
        try? await Task.sleep(for: .milliseconds(260))
        for tile in 1...3 {
            withAnimation(Motion.surface) { tiles = tile }
            try? await Task.sleep(for: .milliseconds(110))
        }
        try? await Task.sleep(for: .milliseconds(120))
        let steps = 26
        for step in 1...steps {
            let eased = 1 - pow(1 - Double(step) / Double(steps), 3)
            withAnimation(Motion.quick) { counted = Int(Double(recap.kcal) * eased) }
            if step.isMultiple(of: 2) { ticks += 1 }
            try? await Task.sleep(for: .milliseconds(40))
        }
        withAnimation(Motion.surface) {
            counted = recap.kcal
            landed = true
        }
        tobi.acknowledge()
    }
}

/// Um macro em vidro: o anel na cor do macro enche até a meta, com os gramas no meio.
private struct MacroTile: View {
    let name: String
    let grams: Double
    let goal: Double
    let color: Color
    let isShown: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: goal > 0 ? min(1, grams / goal) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(Int(grams.rounded()).formatted())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: grams))
                    Text("g")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
            }
            .frame(width: 56, height: 56)

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .scaleEffect(isShown ? 1 : 0.82, anchor: .bottom)
        .reveal(isShown, order: 0)
        .animation(Motion.surface, value: isShown)
        .accessibilityElement(children: .combine)
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
