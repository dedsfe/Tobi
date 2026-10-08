import SwiftUI
import StoreKit

/// Telas do onboarding, na ordem. Só entra aqui o que já está feito; o resto vive no TODO.md.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case sex
    case birthday
    case height
    case objective
    case weight
    case activity
    case pace
    case goals
    case firstMeal
    case inputs
    case celebration

    /// Total de telas planejadas (ver TODO.md), pra barra de progresso não pular quando entrar tela nova.
    static let planned = 14

    #if DEBUG
    /// Tela em revisão: o atalho do Debug nos Ajustes abre direto nela. Trocar aqui quando a revisão mudar.
    static let debugJump: OnboardingStep = .celebration

    var debugName: String {
        switch self {
        case .welcome: "Boas-vindas"
        case .sex: "Gênero"
        case .birthday: "Nascimento"
        case .height: "Altura"
        case .objective: "Objetivo"
        case .weight: "Peso"
        case .activity: "Atividade"
        case .pace: "Em quanto tempo"
        case .goals: "Suas metas"
        case .firstMeal: "Primeira refeição"
        case .inputs: "Formas de registrar"
        case .celebration: "Tudo pronto"
        }
    }
    #endif
}

/// O que a pessoa respondeu. Vira as metas na tela "Suas metas".
struct OnboardingAnswers: Equatable {
    var sex: Sex?
    var birthday: Date?
    var heightCm: Int?
    var objective: Objective?
    var weightKg: Double?
    var goalWeightKg: Double?
    var activity: ActivityLevel?
    var pace: Pace?
    /// Data escolhida no Personalizado.
    var targetDate: Date?

    static let weightRange = 35.0...250.0

    /// De 100 a 13 anos atrás.
    static var birthdayRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let oldest = calendar.date(byAdding: .year, value: -100, to: .now) ?? .distantPast
        let youngest = calendar.date(byAdding: .year, value: -13, to: .now) ?? .now
        return oldest...youngest
    }

    /// Perder pede meta abaixo do peso atual; ganhar, acima.
    static func goalMatches(_ goal: Double?, weight: Double?, objective: Objective?) -> Bool {
        guard let goal, let weight, let objective else { return false }
        switch objective {
        case .lose: return goal < weight
        case .gain: return goal > weight
        case .maintain: return true
        }
    }

    /// Meta sugerida: 10 kg na direção do objetivo.
    static func suggestedGoal(weight: Double, objective: Objective) -> Double {
        let goal = objective == .lose ? weight - 10 : (objective == .gain ? weight + 10 : weight)
        return min(weightRange.upperBound, max(weightRange.lowerBound, goal))
    }

    /// Acerta o peso-meta quando ele não combina mais com o objetivo (ex.: trocou perder por ganhar).
    mutating func suggestGoalIfNeeded() {
        guard let objective, objective != .maintain, let weightKg,
              !Self.goalMatches(goalWeightKg, weight: weightKg, objective: objective) else { return }
        goalWeightKg = Self.suggestedGoal(weight: weightKg, objective: objective)
    }

    #if DEBUG
    /// Respostas de exemplo pra abrir qualquer tela direto pelo atalho do Debug.
    static var sample: OnboardingAnswers {
        var answers = OnboardingAnswers()
        answers.sex = .male
        answers.birthday = Calendar.current.date(byAdding: .year, value: -25, to: .now)
        answers.heightCm = 178
        answers.objective = .lose
        answers.weightKg = 70
        answers.goalWeightKg = 65
        answers.activity = .light
        answers.pace = .recommended
        return answers
    }
    #endif
}

/// Nível de atividade com o fator que multiplica o gasto em repouso.
enum ActivityLevel: CaseIterable, Identifiable {
    case sedentary, light, moderate, active

    var id: Self { self }

    var title: String {
        switch self {
        case .sedentary: "Sedentário"
        case .light: "Levemente ativo"
        case .moderate: "Moderadamente ativo"
        case .active: "Muito ativo"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Pouco ou nenhum exercício"
        case .light: "1 a 3 treinos por semana"
        case .moderate: "3 a 5 treinos por semana"
        case .active: "6 a 7 treinos por semana"
        }
    }

    var symbol: String {
        switch self {
        case .sedentary: "chair.fill"
        case .light: "figure.walk"
        case .moderate: "figure.run"
        case .active: "figure.strengthtraining.traditional"
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        }
    }
}

/// O que a pessoa quer. Decide se a meta fica abaixo, igual ou acima do gasto do dia.
enum Objective: CaseIterable, Identifiable {
    case lose, maintain, gain

    var id: Self { self }

    var title: String {
        switch self {
        case .lose: "Perder peso"
        case .maintain: "Manter o peso"
        case .gain: "Ganhar massa"
        }
    }

    var detail: String {
        switch self {
        case .lose: "Comer um pouco menos do que gasta"
        case .maintain: "Comer o mesmo que gasta"
        case .gain: "Comer mais, com mais proteína"
        }
    }

    var symbol: String {
        switch self {
        case .lose: "arrow.down.right"
        case .maintain: "equal"
        case .gain: "dumbbell.fill"
        }
    }
}

/// Velocidade até o peso-meta. Os kg por semana de cada uma estão em `NutritionPlan.weeklyRate`.
enum Pace: CaseIterable, Identifiable {
    case relaxed, recommended, fast
    /// A pessoa escolhe a data (`OnboardingAnswers.targetDate`).
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .relaxed: "Tranquilo"
        case .recommended: "Recomendado"
        case .fast: "Rápido"
        case .custom: "Personalizado"
        }
    }

    var symbol: String {
        switch self {
        case .relaxed: "tortoise.fill"
        case .recommended: "checkmark.seal.fill"
        case .fast: "hare.fill"
        case .custom: "calendar"
        }
    }
}

/// Sexo pro cálculo do gasto calórico (Mifflin-St Jeor). Quem prefere não dizer recebe a média das duas fórmulas.
enum Sex: String, CaseIterable, Identifiable {
    case male, female, undisclosed

    var id: Self { self }

    var title: String {
        switch self {
        case .male: "Masculino"
        case .female: "Feminino"
        case .undisclosed: "Prefiro não dizer"
        }
    }

    var symbol: String {
        switch self {
        case .male: "figure.stand"
        case .female: "figure.stand.dress"
        case .undisclosed: "questionmark.circle"
        }
    }
}

/// O onboarding inteiro: espaço do Tobi fixo no topo, a tela da vez embaixo.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step: OnboardingStep
    @State private var answers: OnboardingAnswers

    /// `start` diferente de boas-vindas só vem do atalho do Debug, que já entra com respostas de exemplo.
    init(start: OnboardingStep = .welcome, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: start)
        #if DEBUG
        _answers = State(initialValue: start == .welcome ? OnboardingAnswers() : .sample)
        #else
        _answers = State(initialValue: OnboardingAnswers())
        #endif
    }

    var body: some View {
        ZStack {
            if step == .firstMeal {
                // A tela de verdade do app, não uma cópia: a primeira refeição já fica salva no dia.
                DayView(onFirstMealDone: advance)
                    .transition(.emerge)
            } else {
                questions
                    .transition(.opacity)
            }
        }
        .animation(Motion.surface, value: step == .firstMeal)
    }

    private var questions: some View {
        VStack(spacing: 0) {
            TobiStage()
                .overlay(alignment: .top) {
                    if step != .welcome {
                        OnboardingHeader(progress: progress, onBack: goBack)
                            .transition(.opacity)
                    }
                }
            ZStack {
                switch step {
                case .welcome:
                    WelcomeStep(onStart: advance)
                        .transition(.opacity)
                case .sex:
                    SexStep(selection: $answers.sex, onContinue: advance)
                        .transition(.opacity)
                case .birthday:
                    BirthdayStep(birthday: $answers.birthday, onContinue: advance)
                        .transition(.opacity)
                case .height:
                    HeightStep(heightCm: $answers.heightCm, onContinue: advance)
                        .transition(.opacity)
                case .objective:
                    ObjectiveStep(selection: $answers.objective, onContinue: advance)
                        .transition(.opacity)
                case .weight:
                    WeightStep(objective: answers.objective ?? .maintain, weight: $answers.weightKg,
                               goal: $answers.goalWeightKg, onContinue: advance)
                        .transition(.opacity)
                case .activity:
                    ActivityStep(selection: $answers.activity, onContinue: advance)
                        .transition(.opacity)
                case .pace:
                    PaceStep(answers: $answers, onContinue: advance)
                        .transition(.opacity)
                case .goals:
                    GoalsStep(answers: $answers) { chosen in
                        chosen.save()
                        advance()
                    }
                    .transition(.opacity)
                case .firstMeal:
                    EmptyView()
                case .inputs:
                    InputsStep(onContinue: advance)
                        .transition(.opacity)
                case .celebration:
                    CelebrationStep(answers: answers, onContinue: advance)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background { Theme.background }
    }

    private var progress: Double {
        Double(step.rawValue) / Double(OnboardingStep.planned)
    }

    private func advance() {
        guard let next = neighbor(of: step, by: 1) else { return onFinish() }
        withAnimation(Motion.surface) { step = next }
    }

    private func goBack() {
        guard let previous = neighbor(of: step, by: -1) else { return }
        withAnimation(Motion.surface) { step = previous }
    }

    /// Próxima (ou anterior) tela, pulando o prazo pra quem quer manter o peso.
    private func neighbor(of step: OnboardingStep, by offset: Int) -> OnboardingStep? {
        var index = step.rawValue + offset
        while let candidate = OnboardingStep(rawValue: index) {
            if candidate == .pace, answers.objective == .maintain { index += offset; continue }
            return candidate
        }
        return nil
    }
}

/// Palco do Tobi no topo de toda tela. Hoje mostra um emoji; quando a arte chegar,
/// as animações do Tobi entram aqui sem mexer no resto do layout.
struct TobiStage: View {
    /// Altura do palco em todas as telas. Mudou aqui, muda no onboarding inteiro.
    static let height: CGFloat = 200

    var body: some View {
        Text("🐶")
            .font(.system(size: 80))
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .accessibilityLabel("Tobi")
    }
}

// MARK: - Peças comuns

/// Voltar + barra de progresso, por cima do palco do Tobi.
private struct OnboardingHeader: View {
    let progress: Double
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Voltar", systemImage: "chevron.left", action: onBack)
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 30, height: 30)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .foregroundStyle(.primary)

            Capsule()
                .fill(.primary.opacity(0.08))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.indigo)
                            .frame(width: max(6, proxy.size.width * progress))
                    }
                }
                .animation(Motion.surface, value: progress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

/// Botão principal do onboarding: vidro índigo, largura cheia.
private struct OnboardingButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo)
        .disabled(!isEnabled)
        .animation(Motion.quick, value: isEnabled)
    }
}

/// Pergunta com título, explicação curta, opções roláveis e o botão fixo embaixo.
private struct QuestionStep<Content: View>: View {
    let title: String
    let subtitle: String
    let canContinue: Bool
    let onContinue: () -> Void
    @ViewBuilder let content: (_ visible: Bool) -> Content

    @State private var visible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .reveal(visible, order: 0)
                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .reveal(visible, order: 1)
                content(visible)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            OnboardingButton(title: "Continuar", isEnabled: canContinue, action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .reveal(visible, order: 6)
        }
        .onAppear { visible = true }
    }
}

/// Opção de escolha: card de vidro que ganha tinta índigo e um check quando escolhido.
private struct ChoiceRow: View {
    let title: String
    var detail: String?
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? .indigo : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .medium))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                // Uma linha por texto, pra lista inteira caber sem rolar.
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.indigo)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.indigo.opacity(0.18)).interactive() : .regular.interactive(),
                     in: .rect(cornerRadius: 22))
        .animation(Motion.quick, value: isSelected)
    }
}

// MARK: - 1 · Boas-vindas

private struct WelcomeStep: View {
    let onStart: () -> Void
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bem-vindo ao Tobi")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .reveal(visible, order: 0)
            Group {
                Text("O contador de calorias mais simples do mundo.")
                    .reveal(visible, order: 1)
                Text("É só escrever o que você comeu, como num bloco de notas.")
                    .reveal(visible, order: 2)
            }
            .foregroundStyle(.secondary)

            Spacer()

            OnboardingButton(title: "Começar", action: onStart)
                .reveal(visible, order: 3)
        }
        .font(.system(size: 19))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .onAppear { visible = true }
    }
}

// MARK: - 2 · Gênero

private struct SexStep: View {
    @Binding var selection: Sex?
    let onContinue: () -> Void

    var body: some View {
        QuestionStep(
            title: "Qual é o seu gênero?",
            subtitle: "Isso muda o cálculo das suas calorias e macros.",
            canContinue: selection != nil,
            onContinue: onContinue
        ) { visible in
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(Array(Sex.allCases.enumerated()), id: \.element) { index, sex in
                        ChoiceRow(title: sex.title, symbol: sex.symbol, isSelected: selection == sex) {
                            selection = sex
                        }
                        .reveal(visible, order: 2 + index)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

/// Card de vidro com o valor escolhido (ou o convite pra escolher). Tocar abre a folha do seletor.
private struct ValueCard: View {
    let value: String?
    var detail: String?
    let placeholder: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value ?? placeholder)
                        .font(.system(size: value == nil ? 20 : 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.indigo)
                        .contentTransition(.numericText())
                    if value != nil, let detail {
                        Text(detail)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 76)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}

/// Folha curta com um seletor de roleta e o botão "Concluir".
private struct PickerSheet<Picker: View>: View {
    let title: String
    var height: CGFloat = 360
    let onDone: () -> Void
    @ViewBuilder let picker: Picker

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 20)
            picker
            OnboardingButton(title: "Concluir", action: onDone)
                .padding(.horizontal, 24)
        }
        .presentationDetents([.height(height)])
    }
}

private struct PrivacyNote: View {
    var body: some View {
        Label("Seus dados ficam só no seu iPhone", systemImage: "lock.fill")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
    }
}

// MARK: - 3 · Nascimento

private struct BirthdayStep: View {
    @Binding var birthday: Date?
    let onContinue: () -> Void

    @State private var picking = false
    @State private var draft = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now

    private var range: ClosedRange<Date> { OnboardingAnswers.birthdayRange }

    var body: some View {
        QuestionStep(
            title: "Quando é seu aniversário?",
            subtitle: "A idade entra no cálculo das suas metas.",
            canContinue: birthday != nil,
            onContinue: onContinue
        ) { visible in
            VStack(spacing: 16) {
                ValueCard(
                    value: birthday?.formatted(.dateTime.day().month(.abbreviated).year()),
                    detail: birthday.map { "\(age(at: $0)) anos" },
                    placeholder: "Escolher data",
                    symbol: "calendar"
                ) { picking = true }
                .reveal(visible, order: 2)

                PrivacyNote()
                    .reveal(visible, order: 3)
            }
        }
        .sheet(isPresented: $picking) {
            PickerSheet(title: "Data de nascimento") {
                withAnimation(Motion.quick) { birthday = draft }
                picking = false
            } picker: {
                DatePicker("Data de nascimento", selection: $draft, in: range, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .onAppear { if let birthday { draft = birthday } }
        }
    }

    private func age(at date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
    }
}

// MARK: - 4 · Altura

private struct HeightStep: View {
    @Binding var heightCm: Int?
    let onContinue: () -> Void

    @State private var picking = false
    @State private var draft = 170

    var body: some View {
        QuestionStep(
            title: "Qual é sua altura?",
            subtitle: "Entra no cálculo de quanto você gasta por dia.",
            canContinue: heightCm != nil,
            onContinue: onContinue
        ) { visible in
            VStack(spacing: 16) {
                ValueCard(
                    value: heightCm.map { "\($0) cm" },
                    placeholder: "Escolher altura",
                    symbol: "ruler"
                ) { picking = true }
                .reveal(visible, order: 2)

                PrivacyNote()
                    .reveal(visible, order: 3)
            }
        }
        .sheet(isPresented: $picking) {
            PickerSheet(title: "Sua altura") {
                withAnimation(Motion.quick) { heightCm = draft }
                picking = false
            } picker: {
                Picker("Sua altura", selection: $draft) {
                    ForEach(120...220, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .onAppear { if let heightCm { draft = heightCm } }
        }
    }
}

// MARK: - 5 · Objetivo

private struct ObjectiveStep: View {
    @Binding var selection: Objective?
    let onContinue: () -> Void

    var body: some View {
        QuestionStep(
            title: "Qual é o seu objetivo?",
            subtitle: "É ele que decide quanto você vai comer por dia.",
            canContinue: selection != nil,
            onContinue: onContinue
        ) { visible in
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(Array(Objective.allCases.enumerated()), id: \.element) { index, objective in
                        ChoiceRow(title: objective.title, detail: objective.detail, symbol: objective.symbol,
                                  isSelected: selection == objective) {
                            selection = objective
                        }
                        .reveal(visible, order: 2 + index)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

// MARK: - 6 · Peso atual e peso-meta

private struct WeightStep: View {
    let objective: Objective
    @Binding var weight: Double?
    @Binding var goal: Double?
    let onContinue: () -> Void

    private enum Field: Identifiable {
        case current, goal
        var id: Self { self }
    }

    @State private var editing: Field?
    @State private var draft = 70.0

    private static let options = Array(stride(from: OnboardingAnswers.weightRange.lowerBound,
                                               through: OnboardingAnswers.weightRange.upperBound, by: 0.5))

    var body: some View {
        QuestionStep(
            title: "Qual é seu peso?",
            subtitle: objective == .maintain ? "É o peso que você quer manter." : "E onde você quer chegar. Dá pra mudar depois.",
            canContinue: weight != nil && (objective == .maintain || goalMatchesObjective),
            onContinue: onContinue
        ) { visible in
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Peso atual")
                    .reveal(visible, order: 2)
                ValueCard(value: weight.map(Self.kg), placeholder: "Escolher peso", symbol: "scalemass") {
                    open(.current)
                }
                .reveal(visible, order: 2)

                if objective != .maintain {
                    fieldLabel("Peso-meta")
                        .padding(.top, 8)
                        .reveal(visible, order: 3)
                    ValueCard(value: goal.map(Self.kg), detail: goalDetail, placeholder: "Escolher meta", symbol: "flag") {
                        open(.goal)
                    }
                    .reveal(visible, order: 3)
                }

                PrivacyNote()
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                    .reveal(visible, order: 4)
            }
        }
        .onAppear(perform: suggestGoal)
        .onChange(of: weight) { suggestGoal() }
        .sheet(item: $editing) { field in
            PickerSheet(title: field == .current ? "Peso atual" : "Peso-meta") {
                withAnimation(Motion.quick) {
                    if field == .current { weight = draft } else { goal = draft }
                }
                editing = nil
            } picker: {
                Picker("Peso", selection: $draft) {
                    ForEach(Self.options, id: \.self) { Text(Self.kg($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
    }

    /// A roleta abre no valor já escolhido.
    private func open(_ field: Field) {
        draft = (field == .current ? weight : goal) ?? weight ?? 70
        editing = field
    }

    /// Com o peso atual escolhido, a meta já aparece 10 kg na direção do objetivo,
    /// a menos que a pessoa já tenha escolhido uma meta que combina com ele.
    private func suggestGoal() {
        guard objective != .maintain, let weight, !goalMatchesObjective else { return }
        withAnimation(Motion.quick) { goal = OnboardingAnswers.suggestedGoal(weight: weight, objective: objective) }
    }

    private var goalMatchesObjective: Bool {
        OnboardingAnswers.goalMatches(goal, weight: weight, objective: objective)
    }

    private var goalDetail: String? {
        guard let weight, let goal else { return nil }
        guard goalMatchesObjective else {
            return objective == .lose ? "Escolha um peso menor que o atual" : "Escolha um peso maior que o atual"
        }
        let difference = abs(goal - weight)
        return objective == .lose ? "Perder \(Self.kg(difference))" : "Ganhar \(Self.kg(difference))"
    }

    private static func kg(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}

// MARK: - 7 · Atividade

private struct ActivityStep: View {
    @Binding var selection: ActivityLevel?
    let onContinue: () -> Void

    var body: some View {
        QuestionStep(
            title: "Qual é seu nível de atividade?",
            subtitle: "Seja sincero, isso muda quanto você gasta por dia.",
            canContinue: selection != nil,
            onContinue: onContinue
        ) { visible in
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, level in
                        ChoiceRow(title: level.title, detail: level.detail, symbol: level.symbol,
                                  isSelected: selection == level) {
                            selection = level
                        }
                        .reveal(visible, order: 2 + index)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

// MARK: - 8 · Em quanto tempo

private struct PaceStep: View {
    @Binding var answers: OnboardingAnswers
    let onContinue: () -> Void

    @State private var pickingDate = false

    var body: some View {
        QuestionStep(
            title: "Em quanto tempo?",
            subtitle: "Pra chegar nos \(kg(answers.goalWeightKg ?? 0)). Quanto mais rápido, mais apertada fica a meta.",
            canContinue: answers.pace != nil && (answers.pace != .custom || answers.targetDate != nil),
            onContinue: onContinue
        ) { visible in
            VStack(alignment: .leading, spacing: 10) {
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        ForEach(Array(Pace.allCases.enumerated()), id: \.element) { index, pace in
                            ChoiceRow(title: pace.title, detail: detail(for: pace), symbol: pace.symbol,
                                      isSelected: answers.pace == pace) {
                                if pace == .custom {
                                    pickingDate = true
                                } else {
                                    answers.pace = pace
                                }
                            }
                            .reveal(visible, order: 2 + index)
                        }
                    }
                }
                if answers.pace == .custom, let warning = answers.paceWarning {
                    PaceWarningLabel(warning: warning)
                        .transition(.opacity)
                }
            }
            .animation(Motion.quick, value: answers.pace)
            .sensoryFeedback(.selection, trigger: answers.pace)
        }
        .sheet(isPresented: $pickingDate) {
            CustomPaceSheet(answers: $answers) { pickingDate = false }
        }
    }

    /// "0,5 kg por semana · mar. de 2027": a velocidade e quando a pessoa chega na meta.
    private func detail(for pace: Pace) -> String? {
        if pace == .custom, answers.pace != .custom || answers.targetDate == nil { return "Escolha a data" }
        var preview = answers
        preview.pace = pace
        guard let rate = preview.weeklyRate, rate > 0,
              let weight = answers.weightKg, let goal = answers.goalWeightKg else { return nil }
        let arrival = pace == .custom
            ? answers.targetDate ?? .now
            : Calendar.current.date(byAdding: .day, value: Int((abs(goal - weight) / rate * 7).rounded()), to: .now) ?? .now
        let speed = rate.formatted(.number.precision(.fractionLength(1...2)))
        return "\(speed) kg por semana · \(arrival.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private func kg(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}

/// Folha do Personalizado: a pessoa escolhe a data. O calendário não deixa passar do ritmo máximo,
/// e mostra na hora a velocidade e o aviso, se tiver.
private struct CustomPaceSheet: View {
    @Binding var answers: OnboardingAnswers
    let onDone: () -> Void

    @State private var draft = Date.now

    private var preview: OnboardingAnswers {
        var preview = answers
        preview.pace = .custom
        preview.targetDate = draft
        return preview
    }

    var body: some View {
        PickerSheet(title: "Chegar na meta em", height: 640) {
            withAnimation(Motion.quick) {
                answers.pace = .custom
                answers.targetDate = draft
            }
            onDone()
        } picker: {
            VStack(spacing: 6) {
                // Calendário de mês em vez de roleta: na roleta, dia/mês/ano giram separados e o mês
                // voltava sozinho ao cair fora do intervalo.
                DatePicker("Chegar na meta em", selection: $draft, in: answers.targetDateRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.indigo)
                    .padding(.horizontal, 16)
                // O ritmo em destaque: "pensa" com brilho de cores a cada data e aparece num puff.
                ThinkingReveal(trigger: draft) {
                    VStack(spacing: 4) {
                        if let rate = preview.weeklyRate {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(rate.formatted(.number.precision(.fractionLength(1...2))))
                                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                Text("kg por semana")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        PaceWarningLabel(warning: preview.paceWarning)
                            .frame(height: 18)
                    }
                }
                .frame(height: 74)
            }
        }
        .onAppear {
            draft = answers.targetDate ?? answers.recommendedTargetDate ?? answers.targetDateRange.lowerBound
        }
    }
}

/// Aviso pequeno do ritmo: amarelo quando não indicamos, vermelho quando pede acompanhamento médico.
struct PaceWarningLabel: View {
    let warning: PaceWarning?

    var body: some View {
        if let warning {
            Label(warning.text, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(warning.isSevere ? Color.red : Color(red: 0.85, green: 0.6, blue: 0))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

// MARK: - 11 · Formas de registrar

private struct InputsStep: View {
    let onContinue: () -> Void

    var body: some View {
        QuestionStep(
            title: "Do jeito mais fácil",
            subtitle: "Escreva, fale ou escaneie. O Tobi entende.",
            canContinue: true,
            onContinue: onContinue
        ) { visible in
            InputMethodsShowcase()
                .reveal(visible, order: 2)
        }
    }
}

// MARK: - 12 · Tudo pronto

/// Comemoração: o resumo do plano, confete e, logo depois, o pedido de avaliação da Apple
/// (quem decide se ele aparece de fato é o sistema).
private struct CelebrationStep: View {
    let answers: OnboardingAnswers
    let onContinue: () -> Void

    /// A meta salva em "Suas metas" (inclui o que a pessoa mudou na mão).
    @AppStorage("dailyGoal") private var dailyGoal = 2000
    @Environment(\.requestReview) private var requestReview
    @State private var celebrated = false

    private var plan: NutritionPlan? {
        NutritionPlan(answers: answers).map { $0.adjusted(kcal: dailyGoal) }
    }

    /// "65 kg em mar. de 2027", ou "Manter os 70 kg".
    private var goalLine: String? {
        guard let plan else { return nil }
        let goal = plan.goalWeightKg.formatted(.number.precision(.fractionLength(0...1)))
        let weekly = abs(plan.weeklyChangeKg)
        guard plan.objective != .maintain, weekly >= 0.05 else { return "Manter os \(goal) kg" }
        let weeks = abs(plan.goalWeightKg - plan.weightKg) / weekly
        let arrival = Calendar.current.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: .now) ?? .now
        return "\(goal) kg em \(arrival.formatted(.dateTime.month(.abbreviated).year()))"
    }

    var body: some View {
        QuestionStep(
            title: "Tá tudo pronto!",
            subtitle: "Seu plano já está na nota. Agora é só escrever o que comer.",
            canContinue: true,
            onContinue: onContinue
        ) { visible in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("🔥").font(.system(size: 28))
                    Text((visible ? dailyGoal : 0).formatted())
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(visible ? dailyGoal : 0)))
                        .animation(visible ? Motion.cascade(3) : Motion.exit, value: visible)
                    Text("cal por dia")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                if let goalLine {
                    Label(goalLine, systemImage: "flag.checkered")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .reveal(visible, order: 4)
                }
            }
            .tobiGlassSurface()
            .reveal(visible, order: 2)
        }
        .overlay { Confetti() }
        .sensoryFeedback(.success, trigger: celebrated)
        .task {
            celebrated = true
            // Deixa o confete cair antes de pedir a avaliação.
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            requestReview()
        }
    }
}

// MARK: - 9 · Suas metas

private struct GoalsStep: View {
    @Binding var answers: OnboardingAnswers
    let onContinue: (NutritionPlan) -> Void

    /// Calorias que a pessoa escolheu na mão em "Mudar meta". nil = a calculada.
    @State private var customKcal: Int?
    @State private var explaining = false
    @State private var editing = false

    private var plan: NutritionPlan? {
        NutritionPlan(answers: answers).map { plan in customKcal.map(plan.adjusted) ?? plan }
    }

    var body: some View {
        if let current = plan {
            QuestionStep(
                title: "Suas metas",
                subtitle: summary(current),
                canContinue: true,
                onContinue: { onContinue(current) }
            ) { visible in
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("🔥").font(.system(size: 28))
                            Text((visible ? current.kcal : 0).formatted())
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(visible ? current.kcal : 0)))
                                .animation(visible ? Motion.cascade(3) : Motion.exit, value: visible)
                                .animation(Motion.quick, value: current.kcal)
                            Text("cal por dia")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 0) {
                            MacroGoal(name: "Proteína", grams: current.proteinGrams, color: Theme.protein)
                            MacroGoal(name: "Carboidratos", grams: current.carbsGrams, color: Theme.carbs)
                            MacroGoal(name: "Gordura", grams: current.fatGrams, color: Theme.fat)
                        }
                        .animation(Motion.quick, value: current)
                    }
                    .tobiGlassSurface()
                    .reveal(visible, order: 2)

                    HStack(spacing: 10) {
                        Button { explaining = true } label: {
                            GlassButtonLabel(title: "Como calculei", symbol: "function")
                        }
                        Button { editing = true } label: {
                            GlassButtonLabel(title: "Mudar meta", symbol: "slider.horizontal.3")
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .foregroundStyle(.primary)
                    .reveal(visible, order: 4)
                }
            }
            .sheet(isPresented: $explaining) { GoalsExplanation(plan: current) }
            .sheet(isPresented: $editing) {
                GoalsEditor(answers: $answers, customKcal: $customKcal,
                            calculatedKcal: NutritionPlan(answers: answers)?.kcal ?? current.kcal)
            }
        }
    }

    /// Explica o número grande: é o quanto comer, e o que acontece comendo isso.
    private func summary(_ current: NutritionPlan) -> String {
        let weekly = current.weeklyChangeKg
        let amount = abs(weekly).formatted(.number.precision(.fractionLength(1...2)))
        let goal = "\(current.goalWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
        if abs(weekly) < 0.1 { return "Comendo isso por dia, você mantém seu peso." }
        let direction = weekly < 0 ? "perde" : "ganha"
        // Só fala do peso-meta quando a meta de calorias anda na direção dele.
        let headingToGoal = (current.goalWeightKg - current.weightKg) * weekly > 0
        let target = headingToGoal ? " até chegar nos \(goal)" : ""
        return "Comendo isso por dia, você \(direction) uns \(amount) kg por semana\(target)."
    }
}

/// "Mudar meta": todas as respostas numa folha só, pra corrigir qualquer uma sem voltar o onboarding.
/// Mexer numa resposta recalcula tudo; as calorias também dá pra escolher na mão.
private struct GoalsEditor: View {
    @Binding var answers: OnboardingAnswers
    @Binding var customKcal: Int?
    let calculatedKcal: Int
    @Environment(\.dismiss) private var dismiss

    private var kcal: Binding<Int> {
        Binding(get: { customKcal ?? calculatedKcal },
                set: { customKcal = $0 == calculatedKcal ? nil : $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: kcal, in: NutritionPlan.minimumKcal...5000, step: 50) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(kcal.wrappedValue.formatted())
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(kcal.wrappedValue)))
                            Text("cal por dia").foregroundStyle(.secondary)
                        }
                    }
                    if customKcal != nil {
                        Button("Usar a calculada (\(calculatedKcal.formatted()) cal)") {
                            withAnimation(Motion.quick) { customKcal = nil }
                        }
                    }
                } footer: {
                    Text(customKcal == nil ? "Calculada a partir das respostas abaixo." : "Você escolheu na mão.")
                }

                Section("Objetivo") {
                    Picker("Objetivo", selection: required(\.objective, default: .maintain)) {
                        ForEach(Objective.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(value: required(\.weightKg, default: 70), in: OnboardingAnswers.weightRange, step: 0.5) {
                        LabeledContent("Peso atual", value: kg(answers.weightKg))
                    }
                    if answers.objective != .maintain {
                        Stepper(value: required(\.goalWeightKg, default: 70), in: OnboardingAnswers.weightRange, step: 0.5) {
                            LabeledContent("Peso-meta", value: kg(answers.goalWeightKg))
                        }
                        Picker("Em quanto tempo", selection: required(\.pace, default: .recommended)) {
                            ForEach(Pace.allCases) { Text($0.title).tag($0) }
                        }
                        if answers.pace == .custom {
                            DatePicker("Chegar em", selection: required(\.targetDate, default: answers.recommendedTargetDate ?? .now),
                                       in: answers.targetDateRange, displayedComponents: .date)
                        }
                        if let rate = answers.weeklyRate {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Ritmo", value: "\(rate.formatted(.number.precision(.fractionLength(1...2)))) kg por semana")
                                if answers.pace == .custom { PaceWarningLabel(warning: answers.paceWarning) }
                            }
                        }
                    }
                }

                Section("Você") {
                    Picker("Gênero", selection: required(\.sex, default: .undisclosed)) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Nascimento", selection: required(\.birthday, default: .now),
                               in: OnboardingAnswers.birthdayRange, displayedComponents: .date)
                    Stepper(value: required(\.heightCm, default: 170), in: 120...220) {
                        LabeledContent("Altura", value: "\(answers.heightCm ?? 170) cm")
                    }
                    Picker("Atividade", selection: required(\.activity, default: .light)) {
                        ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle("Mudar meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            // Resposta nova = conta nova: volta pra calculada e acerta o peso-meta se o objetivo mudou.
            .onChange(of: answers) {
                customKcal = nil
                answers.suggestGoalIfNeeded()
                if answers.pace == .custom, answers.targetDate == nil {
                    answers.targetDate = answers.recommendedTargetDate
                }
            }
            .sensoryFeedback(.selection, trigger: answers)
        }
        .presentationDetents([.large])
    }

    /// Binding de uma resposta opcional que, aqui, sempre tem valor.
    private func required<Value>(_ keyPath: WritableKeyPath<OnboardingAnswers, Value?>,
                                 default fallback: Value) -> Binding<Value> {
        Binding(get: { answers[keyPath: keyPath] ?? fallback },
                set: { answers[keyPath: keyPath] = $0 })
    }

    private func kg(_ value: Double?) -> String {
        "\((value ?? 0).formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}

/// Ícone e texto centralizados numa linha só, pros botões de vidro lado a lado.
struct GlassButtonLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MacroGoal: View {
    let name: String
    let grams: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(grams)g")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(grams)))
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A conta aberta, sem mistério: de onde saiu cada número.
private struct GoalsExplanation: View {
    let plan: NutritionPlan

    private var weekly: String {
        "\(abs(plan.weeklyChangeKg).formatted(.number.precision(.fractionLength(1...2)))) kg por semana"
    }

    /// Parte do objetivo: quanto comer a mais ou a menos do que gasta, e o que isso dá.
    private var objectiveLine: String {
        let difference = plan.kcal - plan.dailyBurnKcal
        switch plan.objective {
        case .lose where difference < 0:
            return "Você quer perder peso, então come \((-difference).formatted()) cal a menos do que gasta. Isso dá uns \(weekly)."
        case .gain where difference > 0:
            return "Você quer ganhar massa, então come \(difference.formatted()) cal a mais do que gasta. Isso dá uns \(weekly)."
        case .maintain where difference == 0:
            return "Você quer manter o peso, então come o mesmo que gasta."
        default:
            return "Você escolheu comer \(plan.kcal.formatted()) cal por dia."
        }
    }

    private var proteinLine: String {
        let grams = plan.proteinPerKg.formatted(.number.precision(.fractionLength(1)))
        let weight = plan.weightKg.formatted(.number.precision(.fractionLength(0...1)))
        let reason = plan.objective == .gain ? ", porque músculo precisa de proteína" : ""
        return "Proteína: \(grams) g por kg do seu peso (\(weight) kg)\(reason). Gordura: \(Int(plan.fatShare * 100))% das calorias. O que sobra vira carboidrato."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Como calculei")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            Text("Parado, seu corpo gasta \(plan.restingKcal.formatted()) cal por dia (fórmula de Mifflin-St Jeor, com seu peso, altura, idade e sexo). Com a sua atividade, isso vira \(plan.dailyBurnKcal.formatted()) cal.")
            Text(objectiveLine)
            Text(proteinLine)
            Spacer(minLength: 0)
        }
        .font(.system(size: 17))
        .padding(24)
        .padding(.top, 8)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    OnboardingView {}
}
