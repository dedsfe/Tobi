import Foundation

/// Um pedaço reconhecido (ou não) de uma linha. "2 ovos" vira um item; "arroz e feijão" vira dois.
struct ItemEstimate: Equatable, Sendable {
    let text: String
    let foodName: String?
    let grams: Double
    let nutrition: Nutrition

    var isRecognized: Bool { foodName != nil }
}

struct LineEstimate: Equatable, Sendable {
    let items: [ItemEstimate]
    /// Linha que é só título ("Almoço", "Café da manhã").
    let isLabel: Bool

    static let empty = LineEstimate(items: [], isLabel: false)
    static let label = LineEstimate(items: [], isLabel: true)

    var total: Nutrition { items.map(\.nutrition).total }
    var hasUnknown: Bool { items.contains { !$0.isRecognized } }
}

/// Lê texto livre em português ("2 ovos, 200g de frango e meio pão") e estima calorias
/// usando a base local. Determinístico e offline.
struct FoodParser: Sendable {
    private struct Entry: Sendable {
        let tokens: [String]
        let food: Food
        let rank: Int
    }

    /// Apelidos agrupados pela primeira palavra; dentro de cada grupo, o mais longo primeiro
    /// e, empatando, quem veio antes em `foods` (a lista curada ganha da TACO automática).
    private var entries: [String: [Entry]]
    private let labels: Set<String>
    /// Apelidos que têm um separador dentro ("café com leite", "alho e óleo"), pela primeira palavra.
    /// Na hora de dividir a linha em itens, esses ficam inteiros.
    private let compounds: [String: [[String]]]

    static let shared = FoodParser(foods: FoodDatabase.foods)

    /// A mesma base com produtos de marca salvos no aparelho por cima: eles ganham no empate.
    func adding(_ foods: [Food]) -> FoodParser {
        var copy = self
        for (offset, food) in foods.enumerated() {
            for alias in food.aliases {
                let tokens = Self.tokenize(alias)
                guard let first = tokens.first else { continue }
                var group = copy.entries[first, default: []]
                let entry = Entry(tokens: tokens, food: food, rank: offset - foods.count)
                let position = group.firstIndex { other in
                    other.tokens.count < tokens.count || (other.tokens.count == tokens.count && other.rank > entry.rank)
                } ?? group.endIndex
                group.insert(entry, at: position)
                copy.entries[first] = group
            }
        }
        return copy
    }

    init(foods: [Food]) {
        var all: [Entry] = []
        for (rank, food) in foods.enumerated() {
            for alias in food.aliases {
                let tokens = Self.tokenize(alias)
                if !tokens.isEmpty { all.append(Entry(tokens: tokens, food: food, rank: rank)) }
            }
        }
        all.sort { a, b in
            a.tokens.count != b.tokens.count ? a.tokens.count > b.tokens.count : a.rank < b.rank
        }
        entries = Dictionary(grouping: all) { (entry: Entry) in entry.tokens[0] }
        let joined = all.map(\.tokens).filter { $0.contains(where: Self.separatorWords.contains) }
        compounds = Dictionary(grouping: joined) { (tokens: [String]) in tokens[0] }
        labels = Set(FoodDatabase.labels.map { Self.tokenize($0).joined(separator: " ") })
    }

    func estimate(_ line: String) -> LineEstimate {
        var text = Self.normalize(line)
        // "Almoço: arroz e feijão" — o que vem antes dos dois pontos é título.
        var hasTitle = false
        if let colon = text.lastIndex(of: ":") {
            text = String(text[text.index(after: colon)...])
            hasTitle = true
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return hasTitle ? .label : .empty }
        if labels.contains(Self.tokenize(trimmed).joined(separator: " ")) { return .label }

        var pieces = items(in: trimmed).map(Self.clean).filter { !$0.isEmpty }

        // "10 g de cada" / "2 colheres cada": a quantidade vale pra todos os itens da linha.
        // Sem o "cada", vale só pro item onde foi escrita, como na fala.
        let each = pieces.contains { $0.contains(/\bcada\b/) }
        if each {
            pieces = pieces.map { Self.clean($0.replacing(/\b(?:de\s+)?cada\b/, with: " ")) }.filter { !$0.isEmpty }
        }

        var shared: Quantity?
        let estimates = pieces.flatMap { piece -> [ItemEstimate] in
            var (quantity, tokens) = Self.parseQuantity(piece)
            if each {
                if quantity.isWritten {
                    shared = shared ?? quantity
                } else if let shared {
                    quantity = shared
                }
            }
            return estimateItem(piece, quantity: quantity, tokens: tokens)
        }
        return LineEstimate(items: estimates, isLabel: false)
    }

    // MARK: - Item

    /// O quanto a pessoa escreveu: "200g", "2", "meia", "3 colheres de sopa".
    private struct Quantity {
        var grams: Double?
        var count: Double = 1
        var measure: String?
        var isWritten = false
    }

    /// Separa a quantidade do resto. Devolve os tokens que sobram (a comida).
    private static func parseQuantity(_ item: String) -> (Quantity, [String]) {
        var quantity = Quantity()
        var text = item

        // Quantidade absoluta em qualquer lugar: "200g", "350 ml", "1.5 kg".
        if let match = text.firstMatch(of: /(\d+(?:\.\d+)?)\s*(kg|gramas?|gr|g|ml|litros?|l)\b/) {
            let value = Double(match.1) ?? 0
            let unit = String(match.2)
            quantity.grams = value * (["kg", "l", "litro", "litros"].contains(unit) ? 1000 : 1)
            quantity.isWritten = true
            text.removeSubrange(match.range)
        }

        var raw = text.split(separator: " ").map(String.init)

        // Contagem no começo: "2", "meio", "1/2", "duas", "3x".
        if let first = raw.first, let number = parseNumber(first) {
            quantity.count = number
            quantity.isWritten = true
            raw.removeFirst()
        }

        var tokens = raw.map(singularize)

        // Medida caseira: "colher", "fatia", "copo de"...
        // Só é medida se vier comida depois: "2 posta" não, "2 postas de peixe" sim.
        if tokens.count > 1, let first = tokens.first,
           FoodDatabase.measures[first] != nil || FoodDatabase.portionWords.contains(first) {
            quantity.measure = first
            quantity.isWritten = true
            tokens.removeFirst()
            if first == "colher", tokens.count >= 2, tokens[0] == "de",
               ["cha", "sopa", "sobremesa"].contains(tokens[1]) {
                quantity.measure = "colher de \(tokens[1])"
                tokens.removeFirst(2)
            }
        }
        while let first = tokens.first, stopWords.contains(first) {
            tokens.removeFirst()
        }
        return (quantity, tokens)
    }

    private func estimateItem(_ item: String, quantity: Quantity, tokens: [String]) -> [ItemEstimate] {
        guard !tokens.isEmpty else { return [] }

        let foods = matchFoods(in: tokens)
        guard !foods.isEmpty else {
            return [ItemEstimate(text: item, foodName: nil, grams: 0, nutrition: .zero)]
        }

        return foods.enumerated().map { index, food in
            // A quantidade escrita vale para o primeiro alimento do item.
            let grams: Double
            if index == 0 {
                grams = quantity.grams ?? quantity.count * self.grams(of: food, measure: quantity.measure)
            } else {
                grams = food.portion
            }
            return ItemEstimate(text: item, foodName: food.name, grams: grams, nutrition: food.nutrition(grams: grams))
        }
    }

    private func grams(of food: Food, measure: String?) -> Double {
        guard let measure else { return food.portion }
        if let grams = food.measures[measure] { return grams }
        if FoodDatabase.portionWords.contains(measure) { return food.portion }
        if measure == "colher de sopa", let grams = food.measures["colher"] { return grams }
        return FoodDatabase.measures[measure] ?? food.portion
    }

    /// Da esquerda pra direita, sempre pegando o nome mais longo que encaixa.
    private func matchFoods(in tokens: [String]) -> [Food] {
        var found: [Food] = []
        var i = 0
        while i < tokens.count {
            if let entry = entries[tokens[i], default: []].first(where: { entry in
                i + entry.tokens.count <= tokens.count && Array(tokens[i..<i + entry.tokens.count]) == entry.tokens
            }) {
                found.append(entry.food)
                i += entry.tokens.count
            } else {
                i += 1
            }
        }
        return found
    }

    // MARK: - Texto

    private static let stopWords: Set<String> = ["de", "da", "do", "dos", "das", "o", "a", "os", "as"]

    private static let numberWords: [String: Double] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5,
        "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10,
        "meio": 0.5, "meia": 0.5, "metade": 0.5,
    ]

    /// Minúsculas, sem acento, vírgula decimal virando ponto.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .replacing(/(\d),(\d)/) { "\($0.1).\($0.2)" }
    }

    private static let separatorWords: Set<String> = ["e", "com", "mais"]

    /// "arroz, feijão e bife com salada" → ["arroz", "feijão", "bife", "salada"], mas
    /// "pão com manteiga e café com leite" → ["pão com manteiga", "café com leite"]: o que é
    /// um prato só na base fica junto. Devolve pedaços do próprio texto (mantém acento e maiúscula).
    func items(in text: String) -> [String] {
        var pieces: [String] = []
        var separators: [String] = []
        var start = text.startIndex
        for match in text.matches(of: /(?i)\s+(?:e|com|mais)\s+|\s*[+;,]\s*/) {
            pieces.append(String(text[start..<match.range.lowerBound]))
            separators.append(String(text[match.range]))
            start = match.range.upperBound
        }
        pieces.append(String(text[start...]))

        var items = [pieces[0]]
        for (separator, piece) in zip(separators, pieces.dropFirst()) {
            let left = items[items.count - 1]
            let joined = left + separator + piece
            if separator.contains(where: \.isLetter), spansCompound(joined, left: left, right: piece) {
                items[items.count - 1] = joined
            } else {
                items.append(piece)
            }
        }
        return items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Algum apelido composto aparece em `joined` atravessando a emenda (e não só num dos lados)?
    private func spansCompound(_ joined: String, left: String, right: String) -> Bool {
        let tokens = Self.tokenize(joined)
        let leftCount = Self.tokenize(left).count
        for start in tokens.indices where start < leftCount {
            for compound in compounds[tokens[start], default: []]
            where start + compound.count > leftCount && start + compound.count <= tokens.count
                && Array(tokens[start..<start + compound.count]) == compound {
                return true
            }
        }
        return false
    }

    static func tokenize(_ text: String) -> [String] {
        clean(normalize(text)).split(separator: " ").map { singularize(String($0)) }
    }

    /// Mantém só letras, números, ponto e barra; colapsa espaços.
    static func clean(_ text: String) -> String {
        text.replacing(/[^a-z0-9.\/]+/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    static func singularize(_ word: String) -> String {
        guard word.count > 3 else { return word }
        let rules: [(String, String)] = [("oes", "ao"), ("aes", "ao"), ("eis", "el"), ("ais", "al"), ("res", "r"), ("ns", "m")]
        for (suffix, replacement) in rules where word.hasSuffix(suffix) {
            return String(word.dropLast(suffix.count)) + replacement
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }

    static func parseNumber(_ token: String) -> Double? {
        if let word = numberWords[token] { return word }
        if let match = token.wholeMatch(of: /(\d+)\/(\d+)/), let a = Double(match.1), let b = Double(match.2), b > 0 {
            return a / b
        }
        if let match = token.wholeMatch(of: /(\d+(?:\.\d+)?)x?/) { return Double(match.1) }
        return nil
    }
}
