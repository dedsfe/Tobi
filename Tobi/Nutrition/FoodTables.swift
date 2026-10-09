import Foundation

/// De onde vêm os números de um alimento.
enum FoodSource: Equatable, Sendable {
    /// TACO 4ª ed. (NEPA/Unicamp): ingredientes, crus e preparados.
    case taco(String)
    /// POF 2008-2009 (IBGE): comida como o brasileiro come, com açúcar e medidas caseiras.
    case ibge(String)
    /// Tabela nutricional oficial de rede de fast food (McDonald's, Burger King...). `estimated` quando
    /// a rede não publica tabela no Brasil e o número vem da tabela oficial de fora (Outback).
    case chain(String, estimated: Bool)
    /// USDA FoodData Central (SR Legacy, domínio público): só o que a TACO e o IBGE não têm,
    /// como sal e temperos secos.
    case usda(String)
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
    /// Só nas redes: número que não é da porção brasileira, e apelidos que escolhem um sabor ou
    /// tamanho por padrão ("mcflurry" → Ovomaltine).
    let estimated: Bool?
    let guesses: [String]?

    var per100: Nutrition {
        Nutrition(kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                  sugar: sugar ?? 0, fiber: fiber, sodium: sodium)
    }
}

/// As tabelas oficiais embutidas no app, lidas uma vez.
enum FoodTables {
    static let taco = load("taco")
    static let ibge = load("ibge")
    static let fastfood = load("fastfood")
    /// Whey e hipercalórico das marcas de academia (Growth, Max Titanium...), pelo rótulo.
    static let suplementos = load("suplementos")
    static let tacoByID = Dictionary(uniqueKeysWithValues: taco.map { ($0.id, $0) })

    private static func load(_ name: String) -> [TableFood] {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? Bundle.main.url(forResource: name, withExtension: "json")
            ?? (["Tobi/Resources", "../Tobi/Resources", "../../Tobi/Resources", "Resources", "/Users/andrefelipe/Programação/Tobi/Tobi/Resources"]
                .map { URL(fileURLWithPath: "\($0)/\(name).json") }
                .first { FileManager.default.fileExists(atPath: $0.path) })

        guard let url,
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([TableFood].self, from: data) else {
            assertionFailure("\(name).json ausente ou inválido")
            return []
        }
        return foods
    }

    private final class BundleToken {}
}
