import Foundation
import WidgetKit

/// Leva o total de hoje pro widget. Só redesenha quando algo mudou de verdade.
enum WidgetBridge {
    static func publish(_ total: Nutrition, goal: Int) {
        let defaults = UserDefaults.standard
        let snapshot = WidgetSnapshot(
            day: Calendar.current.startOfDay(for: .now),
            kcal: total.kcal.rounded(),
            carbs: total.carbs.rounded(),
            protein: total.protein.rounded(),
            fat: total.fat.rounded(),
            goal: goal,
            carbsShare: defaults.object(forKey: "carbsShare") as? Double ?? 0.5,
            proteinShare: defaults.object(forKey: "proteinShare") as? Double ?? 0.2,
            fatShare: defaults.object(forKey: "fatShare") as? Double ?? 0.3
        )
        guard snapshot != WidgetSnapshot.load() else { return }
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.kind)
    }
}
