import Foundation

/// De onde vêm os números de um alimento.
enum FoodSource: Equatable, Sendable {
    /// TACO 4ª ed. (NEPA/Unicamp): ingredientes, crus e preparados.
    case taco(String)
    /// POF 2008-2009 (IBGE): comida como o brasileiro come, com açúcar e medidas caseiras.
    case ibge(String)
    /// Rótulo do produto, via Open Food Facts (código de barras).
    case brand(String)
    /// Estimativa nossa, pra prato pronto que nenhuma tabela tem.
    case estimate
}

/// Uma linha de tabela oficial, como sai dos geradores em scripts/. Valores por 100 g.
struct TableFood: Decodable, Sendable {
    let id: String
    let name: String
    let category: String
    let aliases: [String]
    let portion: Double
    let measures: [String: Double]
    let kcal, protein, fat, carbs, fiber, sodium: Double
    let sugar: Double?

    var per100: Nutrition {
        Nutrition(kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                  sugar: sugar ?? 0, fiber: fiber, sodium: sodium)
    }
}

/// As tabelas oficiais embutidas no app, lidas uma vez.
enum FoodTables {
    static let taco = load("taco")
    static let ibge = load("ibge")
    static let tacoByID = Dictionary(uniqueKeysWithValues: taco.map { ($0.id, $0) })

    private static func load(_ name: String) -> [TableFood] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([TableFood].self, from: data) else {
            assertionFailure("\(name).json ausente ou inválido")
            return []
        }
        return foods
    }

    private final class BundleToken {}
}
