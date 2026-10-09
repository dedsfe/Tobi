import Foundation

/// O resumo do dia que o app deixa pro widget: o que foi comido e as metas.
/// O app escreve sempre que o total de hoje muda; o widget só lê.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Começo do dia a que o resumo se refere.
    var day: Date
    var kcal: Double
    var carbs: Double
    var protein: Double
    var fat: Double
    var goal: Int
    var carbsShare: Double
    var proteinShare: Double
    var fatShare: Double

    static let appGroup = "group.com.andrefelipe.tobi"
    /// Nome do widget no WidgetKit: o app pede pra redesenhar só ele.
    static let kind = "TobiDay"
    private static let key = "widgetSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.key)
    }

    /// O resumo visto em outra data: se virou o dia, o comido zera e as metas continuam.
    func on(_ date: Date) -> WidgetSnapshot {
        let calendar = Calendar.current
        guard !calendar.isDate(day, inSameDayAs: date) else { return self }
        var fresh = self
        fresh.day = calendar.startOfDay(for: date)
        fresh.kcal = 0
        fresh.carbs = 0
        fresh.protein = 0
        fresh.fat = 0
        return fresh
    }

    // Metas em gramas, do mesmo jeito que o cartão de Metas do app calcula.
    var carbsGoal: Double { Double(goal) * carbsShare / 4 }
    var proteinGoal: Double { Double(goal) * proteinShare / 4 }
    var fatGoal: Double { Double(goal) * fatShare / 9 }

    var eaten: Int { Int(kcal.rounded()) }
    /// Quanto falta pra meta. Negativo quando passou.
    var remaining: Int { goal - eaten }
    var isOver: Bool { remaining < 0 }
    var progress: Double { goal > 0 ? min(kcal / Double(goal), 1) : 0 }

    /// O que a galeria de widgets mostra antes de a pessoa abrir o app.
    static let sample = WidgetSnapshot(day: .now, kcal: 1180, carbs: 140, protein: 62, fat: 38,
                                       goal: 2000, carbsShare: 0.5, proteinShare: 0.2, fatShare: 0.3)
}
