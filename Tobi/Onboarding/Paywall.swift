import SwiftUI

// MARK: - 14 · Paywall

/// Última tela: o que o Tobi faz, como corre o teste grátis e os dois planos.
/// O X mora no palco (`PaywallCloseButton`) e liga `declined`; aí chega a carta do Tobi (`TobiLetter`).
/// Com o app travado, a parte de cima vira o resumo do que a pessoa fez nas 24 horas (`RecapHero`).
struct PaywallStep: View {
    /// O que vende em cima dos planos: a promessa (onboarding) ou a prova (o que já foi feito).
    enum Story: Equatable {
        case onboarding
        case recap(PaywallRecap)
        /// App travado sem nada anotado nas 24 horas.
        case nothingWritten
    }

    @Binding var declined: Bool
    var story = Story.onboarding
    let onFinish: () -> Void

    @State private var store = TobiStore.shared
    @State private var plan = TobiPlan.annual
    @State private var visible = false
    /// Coreografia da entrada: benefícios desenhados, marcos da linha do tempo acesos, planos na tela.
    @State private var benefits = 0
    @State private var milestones = 0
    @State private var plansIn = false
    @State private var badgeIn = false
    @State private var offering = false
    @State private var buying = false
    @State private var notice: String?
    @State private var celebrating = false
    @State private var buyTaps = 0
    @State private var successes = 0
    @State private var warnings = 0
    @Environment(\.tobiReactions) private var tobi
    @Namespace private var selection

    private var shown: Bool { visible && !declined }

    var body: some View {
        ZStack {
            content
                .allowsHitTesting(!declined && !celebrating)
            if offering {
                TobiLetter(onAccept: acceptFreePass, onBack: { declined = false })
            }
        }
        .overlay(alignment: .bottom) {
            // Presa embaixo e mais alta que a tela: os canhões saem do pé da tela e o papel passa por cima do Tobi.
            if celebrating {
                ConfettiCannons()
                    .frame(height: 1000)
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.selection, trigger: benefits)
        .sensoryFeedback(.impact(weight: .light), trigger: milestones)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: plansIn)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: badgeIn)
        .sensoryFeedback(.selection, trigger: plan)
        .sensoryFeedback(.impact(weight: .medium), trigger: buyTaps)
        .sensoryFeedback(.success, trigger: successes)
        .sensoryFeedback(.warning, trigger: warnings)
        .onChange(of: declined) { _, isDeclined in
            if isDeclined {
                // Primeiro a oferta sai rápida, depois o balão do Tobi nasce.
                Task {
                    try? await Task.sleep(for: .seconds(Motion.exitDuration))
                    withAnimation(Motion.surface) { offering = true }
                }
            } else {
                withAnimation(Motion.exit) { offering = false }
            }
        }
        .task { await store.load() }
        .task { await choreograph() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch story {
            case .onboarding:
                promise
            case .recap(let recap):
                RecapHero(recap: recap, isShown: shown)
                Spacer(minLength: 14)
            case .nothingWritten:
                NothingWrittenHero(isShown: shown)
                Spacer(minLength: 14)
            }

            plans
                .reveal(shown && plansIn, order: 0)

            Spacer(minLength: 16)

            checkout
                .reveal(shown, order: 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    /// A promessa: o que o Tobi faz e como corre o teste grátis.
    @ViewBuilder
    private var promise: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.trialEligible ? "Teste o Tobi" : "Continue com o Tobi")
            Text(store.trialEligible ? "\(TobiPlan.trialDays) dias de graça" : "Escolha seu plano")
                .foregroundStyle(.indigo)
        }
        .font(.system(size: 32, weight: .heavy, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .reveal(shown, order: 0)

        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(symbol: "pencil.and.scribble", text: "Escreve do seu jeito, ele conta tudo",
                       isShown: shown && benefits >= 1)
            BenefitRow(symbol: "waveform", text: "Fala ou escaneia o rótulo, e pronto",
                       isShown: shown && benefits >= 2)
            BenefitRow(symbol: "scope", text: "Metas sob medida pro seu objetivo",
                       isShown: shown && benefits >= 3)
        }
        .padding(.top, 20)

        Spacer(minLength: 14)

        if store.trialEligible {
            TrialTimeline(reached: shown ? milestones : 0)
                .reveal(shown, order: 2)
            Spacer(minLength: 14)
        }
    }

    // MARK: Planos

    private var plans: some View {
        HStack(spacing: 12) {
            ForEach(TobiPlan.allCases) { option in
                PlanCard(
                    plan: option,
                    price: store.displayPrice(option),
                    detail: option == .annual ? "\(store.weeklyPrice(option)) por semana" : "por semana",
                    badge: option == .annual && store.annualSavings > 0 ? "ECONOMIZE \(store.annualSavings)%" : nil,
                    badgeIn: badgeIn,
                    isSelected: plan == option,
                    namespace: selection
                ) {
                    guard plan != option else { return }
                    withAnimation(Motion.surface) { plan = option }
                    tobi.acknowledge()
                }
            }
        }
        // Espaço pro selo que sai por cima do card.
        .padding(.top, 10)
    }

    // MARK: Compra

    private var checkout: some View {
        VStack(spacing: 8) {
            Label("Sem cobrança hoje", systemImage: "checkmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.indigo)
                .opacity(store.trialEligible ? 1 : 0)

            PaywallButton(title: store.trialEligible ? "Começar meus \(TobiPlan.trialDays) dias grátis" : "Assinar o Tobi",
                          isLoading: buying, action: buy)

            Text(notice ?? disclosure)
                .font(.system(size: 12))
                .foregroundStyle(notice == nil ? .secondary : .primary)
                .multilineTextAlignment(.center)
                // Preço e renovação nunca encolhem nem cortam: é a outra parte da tela que cede.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(Motion.quick, value: notice ?? disclosure)

            HStack(spacing: 18) {
                Button("Restaurar compras", action: restore)
                Link("Termos", destination: PaywallLinks.terms)
                if let privacy = PaywallLinks.privacy {
                    Link("Privacidade", destination: privacy)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(height: 22)
        }
    }

    /// Preço, período e renovação sempre visíveis, do plano escolhido (Apple 3.1.2).
    private var disclosure: String {
        let price = "\(store.displayPrice(plan)) por \(plan.period)"
        return store.trialEligible
            ? "\(TobiPlan.trialDays) dias grátis, depois \(price). Renova sozinho, cancele quando quiser."
            : "\(price). Renova sozinho, cancele quando quiser."
    }

    private func buy() {
        buyTaps += 1
        buying = true
        Task {
            defer { buying = false }
            do {
                switch try await store.purchase(plan) {
                case .purchased: celebrate()
                case .pending: say("Sua compra tá esperando aprovação. Assim que passar, o Tobi libera tudo.")
                case .cancelled: break
                }
            } catch TobiStore.Failure.unavailable {
                say("A App Store não respondeu. Tenta de novo daqui a pouquinho.")
            } catch {
                say("Não deu certo dessa vez. Tenta de novo?")
            }
        }
    }

    private func restore() {
        Task {
            if await store.restore() {
                celebrate()
            } else {
                say("Não achei nenhuma assinatura nessa conta da Apple.")
            }
        }
    }

    private func acceptFreePass() {
        store.grantFreePass()
        celebrate()
    }

    /// Deu certo: confete, o Tobi comemora e o app abre.
    private func celebrate() {
        successes += 1
        celebrating = true
        tobi.celebrate()
        Task {
            // Tempo de ver o confete subir e começar a cair antes de abrir o app.
            try? await Task.sleep(for: .seconds(2.6))
            onFinish()
        }
    }

    /// Recado curto no lugar das letras miúdas, que volta sozinho.
    private func say(_ message: String) {
        warnings += 1
        notice = message
        Task {
            try? await Task.sleep(for: .seconds(4))
            if notice == message { notice = nil }
        }
    }

    private func choreograph() async {
        visible = true
        if story != .onboarding {
            // O resumo conta (ou o Tobi escreve) sozinho; os planos chegam quando a cena já respirou.
            try? await Task.sleep(for: .milliseconds(story == .nothingWritten ? 1200 : 1900))
            withAnimation(Motion.surface) { plansIn = true }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(Motion.surface) { badgeIn = true }
            return
        }
        try? await Task.sleep(for: .milliseconds(260))
        for index in 1...3 {
            withAnimation(Motion.surface) { benefits = index }
            try? await Task.sleep(for: .milliseconds(130))
        }
        if store.trialEligible {
            try? await Task.sleep(for: .milliseconds(120))
            for index in 1...3 {
                withAnimation(Motion.surface) { milestones = index }
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
        withAnimation(Motion.surface) { plansIn = true }
        try? await Task.sleep(for: .milliseconds(320))
        withAnimation(Motion.surface) { badgeIn = true }
    }
}

enum PaywallLinks {
    /// Termos padrão da Apple pra assinaturas (EULA).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Ainda sem página. Precisa existir antes de mandar pra revisão da Apple.
    static let privacy: URL? = nil
}

// MARK: - Peças

/// O que o Tobi faz, numa linha. O ícone se desenha quando a linha entra.
private struct BenefitRow: View {
    let symbol: String
    let text: String
    let isShown: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isShown {
                    Image(systemName: symbol)
                        .transition(.symbolEffect(.drawOn))
                }
            }
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.indigo)
            .frame(width: 26)

            Text(text)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .reveal(isShown, order: 0)
        }
    }
}

/// Hoje, o aviso e a cobrança, com as datas de verdade. Os marcos acendem um a um.
private struct TrialTimeline: View {
    /// Quantos marcos já acenderam (0 a 3).
    let reached: Int

    private var milestones: [(title: String, detail: String)] {
        let calendar = Calendar.current
        let charge = calendar.date(byAdding: .day, value: TobiPlan.trialDays, to: .now) ?? .now
        let reminder = calendar.date(byAdding: .day, value: -1, to: charge) ?? .now
        return [("Hoje", "Tudo liberado"),
                (Self.day(reminder), "Te aviso antes"),
                (Self.day(charge), "Começa a cobrança")]
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Quanto da linha está pintado: até o marco aceso mais recente.
    private var fill: CGFloat {
        switch reached {
        case ...1: 0
        case 2: 0.5
        default: 1
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [.indigo.opacity(0.5), .indigo], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, (width - 12) * fill + 6), height: 4)
                        .opacity(reached >= 2 ? 1 : 0)
                    ForEach(0..<3, id: \.self) { index in
                        Milestone(isLit: index < reached, isNow: index == 0)
                            .position(x: 6 + (width - 12) * CGFloat(index) / 2, y: 7)
                    }
                }
            }
            .frame(height: 14)
            .animation(Motion.surface, value: reached)

            HStack(alignment: .top) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                    let alignment: HorizontalAlignment = index == 0 ? .leading : index == 1 ? .center : .trailing
                    VStack(alignment: alignment, spacing: 2) {
                        Text(milestone.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(index < reached ? .primary : .secondary)
                        Text(milestone.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
                    .animation(Motion.quick, value: reached)
                }
            }
        }
    }
}

/// Um ponto da linha do tempo. "Hoje" pulsa de leve, pra dizer que é agora.
private struct Milestone: View {
    let isLit: Bool
    let isNow: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(isLit ? Color.indigo : Color.primary.opacity(0.15))
            .frame(width: 12, height: 12)
            .scaleEffect(isLit ? 1 : 0.7)
            .shadow(color: .indigo.opacity(isLit ? 0.45 : 0), radius: 6)
            .background {
                if isNow && isLit && !reduceMotion {
                    Circle()
                        .fill(.indigo)
                        .phaseAnimator([false, true]) { ring, expanded in
                            ring
                                .scaleEffect(expanded ? 2.6 : 1)
                                .opacity(expanded ? 0 : 0.35)
                        } animation: { expanded in
                            expanded ? .easeOut(duration: 1.6) : nil
                        }
                }
            }
    }
}

/// Um plano em vidro. O contorno índigo desliza de um card pro outro quando a escolha muda.
private struct PlanCard: View {
    let plan: TobiPlan
    let price: String
    let detail: String
    let badge: String?
    let badgeIn: Bool
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .indigo : .secondary)
                Text(price)
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.indigo.opacity(0.16)).interactive() : .regular.interactive(),
                     in: .rect(cornerRadius: 24))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.indigo, lineWidth: 2)
                    .matchedGeometryEffect(id: "selected", in: namespace)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.indigo)
                    .padding(12)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.indigo, in: .capsule)
                    .fixedSize()
                    .offset(y: -10)
                    .scaleEffect(badgeIn ? 1 : 0.4)
                    .opacity(badgeIn ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Botão de compra: vidro índigo que, de tempos em tempos, respira um pouquinho
/// enquanto uma luz macia atravessa de ponta a ponta.
struct PaywallButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || isLoading {
            button
        } else {
            button
                .keyframeAnimator(initialValue: Pulse(), repeating: true) { content, pulse in
                    content
                        .scaleEffect(pulse.scale)
                        .overlay {
                            Shine(position: pulse.shine)
                                .clipShape(.capsule)
                                .allowsHitTesting(false)
                        }
                } keyframes: { _ in
                    KeyframeTrack(\.shine) {
                        LinearKeyframe(-0.6, duration: 2.2)
                        CubicKeyframe(1.6, duration: 1.1)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: 2.35)
                        SpringKeyframe(1.03, duration: 0.4, spring: .smooth)
                        SpringKeyframe(1, duration: 0.55, spring: .smooth)
                    }
                }
        }
    }

    private var button: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo)
        .disabled(isLoading)
        .animation(Motion.quick, value: isLoading)
    }

    /// Onde está a luz (de fora à esquerda até fora à direita) e o quanto o botão cresceu.
    private struct Pulse {
        var shine = -0.6
        var scale = 1.0
    }
}

/// A luz que atravessa o botão: uma faixa larga, reta e de bordas bem macias.
private struct Shine: View {
    let position: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                   .init(color: .white.opacity(0.22), location: 0.5),
                                   .init(color: .white.opacity(0), location: 1)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.5)
                .offset(x: position * width - width * 0.25)
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - X do palco

/// O X no lugar do Voltar. Chega um instante depois da tela, pra oferta respirar primeiro.
struct PaywallCloseButton: View {
    let action: () -> Void
    @State private var shown = false
    @State private var taps = 0

    var body: some View {
        HStack {
            Button("Fechar", systemImage: "xmark") {
                taps += 1
                action()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 30, height: 30)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(.secondary)
            .reveal(shown, order: 0)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: taps)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            shown = true
        }
    }
}
