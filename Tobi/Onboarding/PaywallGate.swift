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

/// Um alimento que a pessoa anotou, do jeito que ela escreveu, com as calorias que o Tobi deu.
struct RecapFood: Equatable, Identifiable {
    let id: Int
    let text: String
    let kcal: Int
}

/// O que a pessoa anotou desde que as 24 horas começaram: cada alimento na ordem, a proteína
/// e em quantos dias, pra comparar com a meta diária.
struct PaywallRecap: Equatable {
    var items: [RecapFood]
    var proteinGrams: Int
    var days: Int

    var kcal: Int { items.reduce(0) { $0 + $1.kcal } }
    var foods: Int { items.count }

    static let sample = PaywallRecap(
        items: [("pão francês", 135), ("2 ovos mexidos", 182), ("café com leite", 68), ("arroz", 156),
                ("feijão", 108), ("frango grelhado", 248), ("salada", 24), ("pão de queijo", 152)]
            .enumerated().map { RecapFood(id: $0.offset, text: $0.element.0, kcal: $0.element.1) },
        proteinGrams: 84, days: 1)

    /// Quanto da meta de calorias foi, na média dos dias anotados (1 = bateu a meta).
    func share(of goal: Int) -> Double {
        guard goal > 0, days > 0 else { return 0 }
        return Double(kcal) / Double(goal * days)
    }

    /// nil se não tem nenhum alimento reconhecido no período.
    init?(notes: [DayNote], since: Date, parser: FoodParser = .shared) {
        let start = Calendar.current.startOfDay(for: since)
        var items: [RecapFood] = []
        var protein = 0.0
        var days = 0
        for note in notes where note.day >= start {
            let before = items.count
            for line in note.text.split(separator: "\n").map(String.init) {
                let estimate = parser.estimate(line)
                for item in estimate.items where item.isRecognized {
                    items.append(RecapFood(id: items.count, text: Self.written(item, in: line),
                                           kcal: Int(item.nutrition.kcal.rounded())))
                }
                protein += estimate.total.protein
            }
            if items.count > before { days += 1 }
        }
        guard !items.isEmpty else { return nil }
        self.init(items: items, proteinGrams: Int(protein.rounded()), days: days)
    }

    /// O pedaço da linha como a pessoa escreveu, com acento ("feijão"); o parser devolve sem.
    private static func written(_ item: ItemEstimate, in line: String) -> String {
        let piece = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !piece.isEmpty, let range = line.range(of: piece, options: [.caseInsensitive, .diacriticInsensitive]) {
            return String(line[range])
        }
        return item.foodName ?? piece
    }

    init(items: [RecapFood], proteinGrams: Int, days: Int) {
        self.items = items
        self.proteinGrams = proteinGrams
        self.days = days
    }
}

/// A prova em cima dos planos: o que a pessoa comeu cai, um alimento por vez, e cada um soma
/// no número gigante com um toque e o Tobi acenando. Quando assenta, o número pula e fica índigo.
/// A barra da meta só aparece se a pessoa anotou pelo menos metade do dia (menos que isso parece falha).
struct RecapHero: View {
    let recap: PaywallRecap
    let isShown: Bool

    /// A meta salva em "Suas metas".
    @AppStorage("dailyGoal") private var goal = 2000

    @State private var counted = 0
    @State private var dropped = 0
    @State private var landed = false
    @Environment(\.tobiReactions) private var tobi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsGoal: Bool { recap.share(of: goal) >= 0.5 }

    /// Quantas pílulas cabem: duas fileiras, ou uma quando a barra da meta também aparece.
    /// O que não couber não aparece, mas entra na conta do número.
    private var visibleFoods: [RecapFood] {
        FoodPills.fitting(recap.items, rows: showsGoal ? 1 : 2)
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
                Spacer(minLength: 0)
                Text("\(recap.proteinGrams) g de proteína")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(landed ? 1 : 0)
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
                GoalBar(share: shareSoFar, days: recap.days)
                    .padding(.top, 4)
                    .reveal(isShown, order: 2)
            }

            FoodPills(foods: visibleFoods, dropped: isShown ? dropped : 0)
                .padding(.top, 12)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.75), trigger: dropped)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: landed)
        .sensoryFeedback(.impact(weight: .medium), trigger: showsGoal && shareSoFar >= 1)
        .task { await drop() }
    }

    /// A barra anda junto com o número que está subindo.
    private var shareSoFar: Double {
        recap.kcal > 0 ? recap.share(of: goal) * Double(counted) / Double(recap.kcal) : 0
    }

    /// Cada alimento cai e soma. Muitos alimentos aceleram, pra cena nunca passar de uns 2 segundos;
    /// os que não couberam somam juntos no fim, quando o número assenta.
    private func drop() async {
        let foods = visibleFoods
        guard !reduceMotion else {
            dropped = foods.count
            counted = recap.kcal
            landed = true
            return
        }
        tobi.mood(.presenting)
        try? await Task.sleep(for: .milliseconds(320))
        let pause = min(0.24, 1.7 / Double(max(1, foods.count)))
        var total = 0
        for (index, food) in foods.enumerated() {
            total += food.kcal
            withAnimation(Motion.surface) {
                dropped = index + 1
                counted = total
            }
            tobi.acknowledge()
            try? await Task.sleep(for: .seconds(pause))
        }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(Motion.surface) {
            counted = recap.kcal
            landed = true
        }
    }
}

/// As pílulas de vidro com o que a pessoa comeu. Cada uma cai de cima com um quique quando chega a vez.
private struct FoodPills: View {
    let foods: [RecapFood]
    /// Quantas já caíram.
    let dropped: Int

    private static let spacing: CGFloat = 8
    private static let width: CGFloat = 345

    /// Largura aproximada de uma pílula, pra saber quantas cabem sem cortar nada.
    private static func estimatedWidth(_ food: RecapFood) -> CGFloat {
        CGFloat(food.text.count) * 8.4 + CGFloat(food.kcal.formatted().count) * 7.6 + 38
    }

    /// As primeiras que cabem inteiras em `rows` fileiras.
    static func fitting(_ foods: [RecapFood], rows: Int) -> [RecapFood] {
        var row = 1
        var used: CGFloat = 0
        var fitted: [RecapFood] = []
        for food in foods {
            let pill = min(estimatedWidth(food), width)
            if used + pill > width {
                guard row < rows else { break }
                row += 1
                used = 0
            }
            fitted.append(food)
            used += pill + spacing
        }
        return fitted
    }

    var body: some View {
        FlowRows(spacing: Self.spacing) {
            ForEach(Array(foods.enumerated()), id: \.element.id) { index, food in
                pill {
                    Text(food.text.prefix(1).uppercased() + food.text.dropFirst())
                        .font(.system(size: 15, weight: .medium))
                    Text(food.kcal.formatted())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .dropIn(index < dropped)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
    }
}

private extension View {
    /// Cai de cima pro lugar dela: chega desfocada, um pouco maior, e quica ao assentar.
    func dropIn(_ isDropped: Bool) -> some View {
        self
            .opacity(isDropped ? 1 : 0)
            .blur(radius: isDropped ? 0 : 6)
            .scaleEffect(isDropped ? 1 : 1.25)
            .offset(y: isDropped ? 0 : -26)
            .animation(.spring(duration: 0.42, bounce: 0.45), value: isDropped)
    }
}

/// Fileiras que quebram linha quando a próxima peça não cabe.
private struct FlowRows: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
