import Foundation
import SwiftData

/// Produto de marca que a pessoa já usou (escaneado ou achado pelo nome). Fica salvo no aparelho
/// e entra na base do FoodParser: depois da primeira vez, o Tobi reconhece offline.
@Model
final class BrandProduct {
    #Unique<BrandProduct>([\.barcode])

    var barcode: String = ""
    var name: String = ""
    var brand: String?
    var quantity: String?
    var servingGrams: Double?
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var sugar: Double = 0
    var fiber: Double = 0
    var sodium: Double = 0
    var addedAt: Date = Date.now

    init(_ info: BrandProductInfo) {
        barcode = info.barcode
        name = info.name
        brand = info.brand
        quantity = info.quantity
        servingGrams = info.servingGrams
        kcal = info.per100.kcal
        protein = info.per100.protein
        carbs = info.per100.carbs
        fat = info.per100.fat
        sugar = info.per100.sugar
        fiber = info.per100.fiber
        sodium = info.per100.sodium
    }

    /// O texto que vai pra linha quando a pessoa escaneia: o nome que o parser reconhece de volta.
    var lineText: String { name }

    var food: Food {
        Food(
            brand: name,
            aliases: [name, [brand, name].compactMap { $0 }.joined(separator: " ")],
            per100: Nutrition(kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                              sugar: sugar, fiber: fiber, sodium: sodium),
            barcode: barcode,
            portion: servingGrams ?? 100,
            measures: FoodParser.shared.householdMeasures(for: name)
        )
    }
}
