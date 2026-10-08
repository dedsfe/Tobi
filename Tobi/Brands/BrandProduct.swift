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

/// Limpeza única dos produtos salvos antes da IA conferir a busca por nome, quando "prato" virava
/// "Arroz Prato Fino". Fica só o produto que alguma nota usa e que a IA confirma em todo trecho.
enum BrandCleanup {
    static let doneKey = "brandCleanup.v1"

    /// Códigos de barras pra apagar. `confirm` diz se o trecho escrito é mesmo o produto.
    static func rejected(products: [(barcode: String, name: String)], notes: [String], parser: FoodParser,
                         confirm: @Sendable (String, String) async throws -> Bool) async throws -> Set<String> {
        let names = Set(products.map(\.name))
        var pieces: [String: Set<String>] = [:]
        for line in notes.flatMap({ $0.split(separator: "\n") }) {
            for item in parser.estimate(String(line)).items {
                if let name = item.foodName, names.contains(name) { pieces[name, default: []].insert(item.text) }
            }
        }
        var rejected = Set<String>()
        for product in products {
            let used = pieces[product.name, default: []].sorted()
            if used.isEmpty { rejected.insert(product.barcode) }
            for piece in used {
                try Task.checkCancellation()
                if try await !confirm(piece, product.name) {
                    rejected.insert(product.barcode)
                    break
                }
            }
        }
        return rejected
    }
}
