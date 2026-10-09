import SwiftUI
import SwiftData
import PostHog

/// O app travado: sem plano e sem as 24 horas, o Tobi no palco e os planos, sem X.
/// Em cima, a prova: o que a pessoa fez com o Tobi nas 24 horas. Sem nada anotado, o Tobi
/// mostra em ação como é fácil (`NothingWrittenHero`), com conta de verdade, nada inventado.
/// Destrava quando a compra ou a restauração dá certo, depois do confete.
struct LockedPaywall: View {
    let onUnlock: () -> Void

    @State private var tobi = TobiPerformance(mood: .attentive)
    @Query(sort: \DayNote.day) private var notes: [DayNote]

    private var story: PaywallStep.Story {
        let since = TobiStore.freePassUntil.map { $0.addingTimeInterval(-TobiStore.freePassHours * 3600) }
            ?? .now.addingTimeInterval(-TobiStore.freePassHours * 3600)
        // Nunca inventa número: sem nada anotado, a tela é outra (o Tobi mostra como é fácil).
        return PaywallRecap(notes: notes, since: since).map { .recap($0) } ?? .nothingWritten
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
        // O teclado do "escreve o seu" passa por cima dos planos em vez de espremer a tela.
        .ignoresSafeArea(.keyboard)
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
            .padding(.top, 18)
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

/// Um macro solto na tela (sem caixa, pra não parecer botão como os planos): o anel na cor
/// do macro enche até a meta, com a quantidade no meio. De 1.000 g pra cima vira kg, pra caber sempre.
private struct MacroTile: View {
    let name: String
    let grams: Double
    let goal: Double
    let color: Color
    let isShown: Bool

    private var amount: (value: String, unit: String) {
        guard grams >= 999.5 else { return (Int(grams.rounded()).formatted(), "g") }
        return ((grams / 1000).formatted(.number.precision(.fractionLength(1))), "kg")
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: goal > 0 ? min(1, grams / goal) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(amount.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: grams))
                    Text(amount.unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 50)
            }
            .frame(width: 66, height: 66)

            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
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

    /// Até o dobro, em %; daí pra cima, em vezes ("3,1x"), que é como se lê número grande.
    private var caption: String {
        let average = days > 1 ? ", na média" : ""
        if share >= 2 {
            let times = share.formatted(.number.precision(.fractionLength(share < 10 ? 1 : 0)))
            return days > 1 ? "\(times)x a sua meta, na média" : "\(times)x a sua meta do dia"
        }
        if percent > 100 { return "\(percent - 100)% acima da meta" + average }
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

// MARK: - Sem nada anotado

/// Quem não anotou nada nas 24 horas: o Tobi não inventa resumo, ele deixa testar ali mesmo.
/// O cartão de vidro é um campo de verdade. Parado, o Tobi escreve um exemplo letra por letra, a conta
/// aparece (calorias e macros subindo), ele apaga e escreve o próximo. Tocou, abre o teclado e a pessoa
/// escreve o que comeu: a conta sai na hora, do parser de verdade, com um toque a cada alimento entendido.
struct NothingWrittenHero: View {
    let isShown: Bool

    static let examples = ["2 ovos e pão francês", "arroz, feijão e bife", "café com leite e banana"]

    @State private var demo = ""
    @State private var input = ""
    @State private var editing = false
    @State private var counted = Nutrition.zero
    @State private var understood = 0
    @State private var keys = 0
    @State private var erasing = 0
    @State private var lands = 0
    @FocusState private var focused: Bool
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasResult: Bool { counted.kcal > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Faltou me contar\n\(Text("o que você comeu").foregroundStyle(.indigo))")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .reveal(isShown, order: 0)

            card
                .padding(.top, 16)
                .reveal(isShown, order: 1)

            hint
                .padding(.top, 10)
                .padding(.leading, 4)
                .reveal(isShown, order: 2)
        }
        .sensoryFeedback(.selection, trigger: keys)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: erasing)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: lands)
        .sensoryFeedback(.impact(weight: .medium), trigger: editing)
        .task(id: editing) {
            guard !editing else { return }
            await runDemo()
        }
        .onChange(of: input) { _, text in
            let estimate = FoodParser.shared.estimate(text)
            let recognized = estimate.items.filter(\.isRecognized).count
            if recognized > understood {
                lands += 1
                tobi.acknowledge()
            }
            understood = recognized
            withAnimation(Motion.quick) { counted = estimate.total }
        }
        .onChange(of: focused) { _, isFocused in
            // Fechou o teclado sem escrever nada: o Tobi volta a mostrar os exemplos.
            if !isFocused, input.trimmingCharacters(in: .whitespaces).isEmpty {
                withAnimation(Motion.surface) { editing = false }
            }
        }
    }

    // MARK: Cartão

    /// O campo em vidro: a linha escrita à esquerda, a conta à direita e os macros embaixo,
    /// no mesmo jeito da barra do dia (letra colorida e número).
    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                line
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Int(counted.kcal.rounded()).formatted())
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(hasResult ? Color.indigo : Color.secondary.opacity(0.4))
                        .contentTransition(.numericText(value: counted.kcal))
                    Text("cal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .fixedSize()
            }

            HStack(spacing: 16) {
                macro("C", counted.carbs, Theme.carbs)
                macro("P", counted.protein, Theme.protein)
                macro("G", counted.fat, Theme.fat)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect(cornerRadius: 26))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .onTapGesture(perform: startEditing)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Escreva o que você comeu e o Tobi faz a conta")
    }

    /// Parado: o exemplo sendo escrito com o cursor. Tocado: o campo de verdade.
    @ViewBuilder
    private var line: some View {
        if editing {
            // Uma linha só (texto longo rola pro lado): o cartão nunca cresce e empurra os planos.
            TextField("O que você comeu hoje?", text: $input)
                .font(.system(size: 19))
                .postHogMask()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { focused = false }
                .tint(.indigo)
        } else {
            HStack(spacing: 1) {
                Text(demo)
                    .font(.system(size: 19))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Caret()
            }
        }
    }

    private func macro(_ letter: String, _ grams: Double, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(letter)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text("\(Int(grams.rounded()).formatted()) g")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: grams))
        }
        .lineLimit(1)
        .opacity(hasResult ? 1 : 0.35)
    }

    /// Embaixo do cartão: o convite pra tocar, ou o "viu?" quando a conta da pessoa saiu.
    private var hint: some View {
        Group {
            if editing && hasResult {
                Label("Viu? Você escreve, eu faço a conta.", systemImage: "checkmark")
                    .foregroundStyle(.indigo)
            } else if editing {
                Label("Escreve do seu jeito, com quantidade ou não", systemImage: "pencil")
                    .foregroundStyle(.secondary)
            } else {
                Label("Toca no cartão e escreve o seu", systemImage: "hand.tap.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .contentTransition(.opacity)
        .animation(Motion.quick, value: editing)
        .animation(Motion.quick, value: hasResult)
    }

    // MARK: Coreografia

    private func startEditing() {
        guard !editing else { return }
        demo = ""
        input = ""
        understood = 0
        withAnimation(Motion.surface) {
            counted = .zero
            editing = true
        }
        tobi.mood(.attentive)
        focused = true
    }

    /// Escreve, mostra a conta, segura, apaga e passa pro próximo. Para quando a pessoa toca.
    private func runDemo() async {
        if reduceMotion {
            demo = Self.examples[0]
            counted = FoodParser.shared.estimate(demo).total
            return
        }
        tobi.mood(.curious)
        try? await Task.sleep(for: .milliseconds(800))
        while !Task.isCancelled {
            for example in Self.examples {
                for count in 1...example.count {
                    guard !Task.isCancelled else { return }
                    demo = String(example.prefix(count))
                    keys += 1
                    try? await Task.sleep(for: .milliseconds(45))
                }
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.surface) { counted = FoodParser.shared.estimate(example).total }
                lands += 1
                tobi.acknowledge()
                try? await Task.sleep(for: .milliseconds(1600))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.quick) { counted = .zero }
                for count in stride(from: example.count - 1, through: 0, by: -1) {
                    guard !Task.isCancelled else { return }
                    demo = String(example.prefix(count))
                    if count.isMultiple(of: 3) { erasing += 1 }
                    try? await Task.sleep(for: .milliseconds(16))
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }
}

/// O cursor piscando na linha que está sendo escrita.
private struct Caret: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.indigo)
            .frame(width: 2, height: 22)
            .phaseAnimator([1.0, 0.0]) { caret, opacity in
                caret.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.45)
            }
    }
}
