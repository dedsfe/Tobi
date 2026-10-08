import Foundation

/// Calorias, macros e micros de uma quantidade de comida. Gramas, exceto sódio (mg).
struct Nutrition: Equatable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var sugar: Double = 0
    var fiber: Double = 0
    var sodium: Double = 0

    static let zero = Nutrition()

    static func + (lhs: Nutrition, rhs: Nutrition) -> Nutrition {
        Nutrition(
            kcal: lhs.kcal + rhs.kcal,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            sugar: lhs.sugar + rhs.sugar,
            fiber: lhs.fiber + rhs.fiber,
            sodium: lhs.sodium + rhs.sodium
        )
    }

    func scaled(by factor: Double) -> Nutrition {
        Nutrition(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor,
                  sugar: sugar * factor, fiber: fiber * factor, sodium: sodium * factor)
    }
}

extension Sequence where Element == Nutrition {
    var total: Nutrition { reduce(.zero, +) }
}

/// Um alimento da base local. Valores por 100 g (ou 100 ml).
struct Food: Sendable {
    let name: String
    let aliases: [String]
    let per100: Nutrition
    let source: FoodSource
    /// Gramas de uma porção/unidade típica — usada quando a pessoa não diz quantidade.
    let portion: Double
    /// Medidas caseiras específicas desse alimento (ex: fatia de pizza = 110 g).
    let measures: [String: Double]
    /// Apelidos que chutam um sabor ou tamanho ("batata do mc" → média). Quem escreve assim
    /// recebe o número como estimativa.
    var guesses: Set<String> = []

    /// O número em si é estimativa: prato que nenhuma tabela tem, ou tabela de fora do Brasil.
    var isEstimate: Bool {
        switch source {
        case .estimate: true
        case .chain(_, let estimated): estimated
        case .taco, .ibge, .usda, .brand: false
        }
    }

    /// Item de cardápio ou embalagem: "whopper" já é um whopper inteiro, não precisa de quantidade.
    var countsByUnit: Bool {
        switch source {
        case .chain, .brand: true
        case .taco, .ibge, .usda, .estimate: false
        }
    }

    /// Estimativa nossa (prato que nenhuma tabela oficial tem).
    init(_ name: String, _ aliases: [String], kcal: Double, p: Double, c: Double, f: Double,
         portion: Double, measures: [String: Double] = [:]) {
        self.name = name
        self.aliases = aliases
        self.per100 = Nutrition(kcal: kcal, protein: p, carbs: c, fat: f)
        self.source = .estimate
        self.portion = portion
        self.measures = measures
    }

    /// Números oficiais da TACO; aqui só entram apelidos e porções do dia a dia.
    init(_ name: String, _ aliases: [String], taco id: Int, portion: Double, measures: [String: Double] = [:], guesses: Set<String> = []) {
        guard let taco = FoodTables.tacoByID[String(id)] else { preconditionFailure("TACO \(id) não existe") }
        self.name = name
        self.aliases = aliases
        self.per100 = taco.per100
        self.source = .taco(taco.id)
        self.portion = portion
        self.measures = measures
        self.guesses = guesses
    }

    /// Números oficiais do USDA (id do FoodData Central), pra sal e temperos que faltam na TACO.
    init(_ name: String, _ aliases: [String], usda id: Int, kcal: Double, p: Double, c: Double, f: Double,
         fiber: Double = 0, sodium: Double = 0, portion: Double, measures: [String: Double] = [:]) {
        self.name = name
        self.aliases = aliases
        self.per100 = Nutrition(kcal: kcal, protein: p, carbs: c, fat: f, fiber: fiber, sodium: sodium)
        self.source = .usda(String(id))
        self.portion = portion
        self.measures = measures
    }

    /// Produto de marca salvo no aparelho (ver `BrandProduct`).
    init(brand name: String, aliases: [String], per100: Nutrition, barcode: String, portion: Double,
         measures: [String: Double] = [:]) {
        self.name = name
        self.aliases = aliases
        self.per100 = per100
        self.source = .brand(barcode)
        self.portion = portion
        self.measures = measures
    }

    init(table food: TableFood, source: FoodSource, additionalAliases: [String] = [],
         guessedAliases: Set<String> = [], measures: [String: Double]? = nil) {
        self.name = food.name
        self.aliases = food.aliases + additionalAliases
        self.per100 = food.per100
        self.source = source
        self.portion = food.portion
        self.measures = measures ?? food.measures
        self.guesses = Set(food.guesses ?? []).union(guessedAliases)
    }

    func nutrition(grams: Double) -> Nutrition {
        per100.scaled(by: grams / 100)
    }
}
