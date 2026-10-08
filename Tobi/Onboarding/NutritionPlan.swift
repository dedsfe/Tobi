import Foundation

/// Metas do dia calculadas a partir das respostas do onboarding.
/// Gasto em repouso pela fórmula de Mifflin-St Jeor, vezes o fator de atividade, mais ou menos o objetivo.
struct NutritionPlan: Equatable {
    /// Gasto em repouso (BMR).
    let restingKcal: Int
    /// Gasto do dia com a atividade (TDEE).
    let dailyBurnKcal: Int
    let objective: Objective
    /// O que o objetivo soma ou tira do gasto, pela velocidade escolhida. 0 pra manter.
    let goalAdjustment: Int
    let kcal: Int
    let proteinPerKg: Double
    let fatShare: Double
    let weightKg: Double
    let goalWeightKg: Double

    static let minimumKcal = 1200
    /// Calorias de 1 kg de gordura corporal, pra traduzir o déficit em kg por semana.
    static let kcalPerKg = 7700.0

    /// Quanto o peso muda por semana comendo a meta: negativo perde, positivo ganha.
    var weeklyChangeKg: Double { Double(kcal - dailyBurnKcal) * 7 / Self.kcalPerKg }

    var proteinGrams: Int { Int((weightKg * proteinPerKg).rounded()) }
    var fatGrams: Int { Int((Double(kcal) * fatShare / 9).rounded()) }
    var carbsGrams: Int { max(0, (kcal - proteinGrams * 4 - fatGrams * 9) / 4) }

    /// Fatias das calorias, guardadas no app pra os macros acompanharem quando a meta mudar nos Ajustes.
    var proteinShare: Double { Double(proteinGrams * 4) / Double(kcal) }
    var carbsShare: Double { Double(carbsGrams * 4) / Double(kcal) }

    init?(answers: OnboardingAnswers, now: Date = .now) {
        guard let sex = answers.sex, let birthday = answers.birthday, let height = answers.heightCm,
              let objective = answers.objective, let weight = answers.weightKg, let activity = answers.activity,
              let age = Calendar.current.dateComponents([.year], from: birthday, to: now).year else { return nil }

        let sexConstant: Double = switch sex {
        case .male: 5
        case .female: -161
        case .undisclosed: -78 // média das duas fórmulas
        }
        let resting = 10 * weight + 6.25 * Double(height) - 5 * Double(age) + sexConstant
        let burn = resting * activity.factor

        let rate = Self.weeklyRate(objective: objective, pace: answers.pace ?? .recommended, weightKg: weight,
                                   goalKg: answers.goalWeightKg, targetDate: answers.targetDate, now: now)
        let adjustment = (objective == .lose ? -1 : 1) * Int((rate * Self.kcalPerKg / 7).rounded())

        restingKcal = Int(resting.rounded())
        dailyBurnKcal = Int(burn.rounded())
        self.objective = objective
        goalAdjustment = adjustment
        kcal = max(Self.minimumKcal, Self.roundToTen(burn + Double(adjustment)))
        weightKg = weight
        goalWeightKg = objective == .maintain ? weight : (answers.goalWeightKg ?? weight)
        // Ganhar massa pede mais proteína: 2,0 g por kg. Perder ou manter: 1,6.
        proteinPerKg = objective == .gain ? 2.0 : 1.6
        fatShare = 0.25
    }

    private init(copying plan: NutritionPlan, kcal: Int) {
        restingKcal = plan.restingKcal
        dailyBurnKcal = plan.dailyBurnKcal
        objective = plan.objective
        goalAdjustment = plan.goalAdjustment
        self.kcal = kcal
        proteinPerKg = plan.proteinPerKg
        fatShare = plan.fatShare
        weightKg = plan.weightKg
        goalWeightKg = plan.goalWeightKg
    }

    /// Mesmo plano com outra meta de calorias (a pessoa ajustou na mão).
    func adjusted(kcal: Int) -> NutritionPlan {
        NutritionPlan(copying: self, kcal: max(Self.minimumKcal, kcal))
    }

    /// Salva no app: a meta de calorias e as fatias de cada macro.
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(kcal, forKey: "dailyGoal")
        defaults.set(proteinShare, forKey: "proteinShare")
        defaults.set(fatShare, forKey: "fatShare")
        defaults.set(carbsShare, forKey: "carbsShare")
    }

    /// Kg por semana de cada velocidade.
    /// Prontas: perder até 1% do peso por semana (preserva músculo); ganhar massa até 0,5 kg.
    /// Personalizado: sai da data escolhida, até o máximo possível (`maxWeeklyRate`).
    static func weeklyRate(objective: Objective, pace: Pace, weightKg: Double,
                           goalKg: Double? = nil, targetDate: Date? = nil, now: Date = .now) -> Double {
        if pace == .custom {
            guard objective != .maintain, let goalKg, let targetDate else {
                return weeklyRate(objective: objective, pace: .recommended, weightKg: weightKg)
            }
            let weeks = max(1, targetDate.timeIntervalSince(now) / (7 * 86_400))
            return min(abs(goalKg - weightKg) / weeks, maxWeeklyRate(objective: objective, weightKg: weightKg))
        }
        switch objective {
        case .maintain:
            return 0
        case .lose:
            let rate = switch pace { case .relaxed: 0.25; case .recommended: 0.5; default: 0.75 }
            return min(rate, weightKg * 0.01)
        case .gain:
            return switch pace { case .relaxed: 0.15; case .recommended: 0.25; default: 0.5 }
        }
    }

    /// O mais rápido que o Personalizado deixa: perder 1,5% do peso por semana, até 2 kg
    /// (acima de 1,5 kg cresce o risco de pedra na vesícula); ganhar massa, 0,5 kg.
    static func maxWeeklyRate(objective: Objective, weightKg: Double) -> Double {
        switch objective {
        case .maintain: 0
        case .lose: min(weightKg * 0.015, 2)
        case .gain: 0.5
        }
    }

    private static func roundToTen(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}

/// Ritmo possível, mas que não indicamos.
enum PaceWarning: Equatable {
    /// Perder mais de 1% do peso por semana.
    case muscle
    /// Perder mais de 1,5 kg por semana.
    case medical
    /// Ganhar mais de 0,55% do peso por semana.
    case fat

    init?(objective: Objective, rate: Double, weightKg: Double) {
        switch objective {
        case .lose where rate > 1.5 + 0.001: self = .medical
        case .lose where rate > weightKg * 0.01 + 0.001: self = .muscle
        case .gain where rate > weightKg * 0.0055 + 0.001: self = .fat
        default: return nil
        }
    }

    var text: String {
        switch self {
        case .muscle: "Nesse ritmo você pode perder músculo junto"
        case .medical: "Nesse ritmo, o ideal é ter acompanhamento médico"
        case .fat: "Nesse ritmo, boa parte do ganho vira gordura"
        }
    }

    var isSevere: Bool { self == .medical }
}

extension OnboardingAnswers {
    /// Kg por semana com as respostas atuais.
    var weeklyRate: Double? {
        guard let objective, let weightKg else { return nil }
        return NutritionPlan.weeklyRate(objective: objective, pace: pace ?? .recommended, weightKg: weightKg,
                                        goalKg: goalWeightKg, targetDate: targetDate)
    }

    var paceWarning: PaceWarning? {
        guard let objective, let weightKg, let weeklyRate else { return nil }
        return PaceWarning(objective: objective, rate: weeklyRate, weightKg: weightKg)
    }

    /// Datas que o Personalizado aceita: do ritmo máximo até 3 anos.
    /// Conta a partir do começo do dia, pra o intervalo não mudar a cada redesenho (a roleta travava).
    var targetDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let earliest = date(atRate: objective.map { NutritionPlan.maxWeeklyRate(objective: $0, weightKg: weightKg ?? 70) })
            ?? calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let latest = calendar.date(byAdding: .year, value: 3, to: today) ?? .distantFuture
        return earliest...max(earliest, latest)
    }

    /// Quando a pessoa chega na meta no ritmo Recomendado: onde o calendário do Personalizado abre.
    var recommendedTargetDate: Date? {
        date(atRate: objective.map { NutritionPlan.weeklyRate(objective: $0, pace: .recommended, weightKg: weightKg ?? 70) })
    }

    private func date(atRate rate: Double?) -> Date? {
        guard let rate, rate > 0, let weightKg, let goalWeightKg else { return nil }
        let days = max(7, Int((abs(goalWeightKg - weightKg) / rate * 7).rounded(.up)))
        return Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now))
    }
}
