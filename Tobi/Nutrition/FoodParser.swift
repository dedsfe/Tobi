import Foundation

/// Quão certo é o número de um item.
enum Confidence: Int, Comparable, Sendable {
    /// Não reconheceu: não soma no total e a linha mostra "?".
    case unknown
    /// Porção chutada, prato genérico, sabor escolhido por padrão ou nome entendido pela metade:
    /// o número aparece com "~".
    case estimated
    /// Tabela oficial com quantidade clara.
    case exact

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Um pedaço reconhecido (ou não) de uma linha. "2 ovos" vira um item; "arroz e feijão" vira dois.
struct ItemEstimate: Equatable, Sendable {
    let text: String
    let foodName: String?
    let grams: Double
    let nutrition: Nutrition
    let confidence: Confidence
    /// Achou um alimento, mas sobrou palavra que o Tobi não conhece ("xis salada" → só a salada).
    var isPartial = false

    var isRecognized: Bool { foodName != nil }
    /// Sem alimento ou com palavra sobrando: o trecho fica sublinhado de vermelho.
    var isUnclear: Bool { !isRecognized || isPartial }
}

struct LineEstimate: Equatable, Sendable {
    let items: [ItemEstimate]
    /// Linha que é só título ("Almoço", "Café da manhã").
    let isLabel: Bool

    static let empty = LineEstimate(items: [], isLabel: false)
    static let label = LineEstimate(items: [], isLabel: true)

    var total: Nutrition { items.map(\.nutrition).total }
    var hasUnknown: Bool { items.contains { !$0.isRecognized } }
    /// Trechos com algo que o Tobi não entendeu, sem repetir (um trecho pode virar dois itens).
    var unclearPieces: [String] {
        var seen = Set<String>()
        return items.filter(\.isUnclear).map(\.text).filter { seen.insert($0).inserted }
    }
    /// O menos certo dos itens reconhecidos. O que não reconheceu já aparece à parte ("?", "+").
    var confidence: Confidence { items.filter(\.isRecognized).map(\.confidence).min() ?? .unknown }
}

/// Lê texto livre em português ("2 ovos, 200g de frango e meio pão") e estima calorias
/// usando a base local. Determinístico e offline.
struct FoodParser: Sendable {
    private struct Entry: Sendable {
        let tokens: [String]
        let food: Food
        let rank: Int
        /// Apelido que escolhe sabor ou tamanho por padrão ("mcflurry").
        let isGuess: Bool
    }

    /// Apelidos agrupados pela primeira palavra; dentro de cada grupo, o mais longo primeiro
    /// e, empatando, quem veio antes em `foods` (a lista curada ganha da TACO automática).
    private var entries: [String: [Entry]]
    /// Produtos salvos no aparelho pelo conjunto de palavras de todos os nomes, pra achar o
    /// produto mesmo escrito em outra ordem ou com palavra a menos.
    private var products: [(words: Set<String>, food: Food)] = []
    /// Todos os alimentos, na ordem de prioridade (produtos salvos primeiro). Pra sugestões.
    private var foods: [Food]
    private struct SuggestionEntry: Sendable {
        let food: Food
        let name: String
        let stems: Set<String>
        let aliases: [Set<String>]
    }
    private var suggestionEntries: [SuggestionEntry]
    private let labels: Set<String>
    /// Apelidos que têm um separador dentro ("café com leite", "alho e óleo"), pela primeira palavra.
    /// Na hora de dividir a linha em itens, esses ficam inteiros.
    private var compounds: [String: [[String]]]
    /// Toda palavra que aparece em algum apelido, pelo tamanho. Serve pra consertar erro de digitação.
    private var vocabulary: [Int: [String]]
    private var knownWords: Set<String>

    static let shared = FoodParser(foods: FoodDatabase.foods)
    private static let preparation = Task.detached(priority: .userInitiated) { shared }

    /// A primeira leitura e a construção dos índices nunca precisam bloquear a interface.
    static func prepared() async -> FoodParser { await preparation.value }

    private static func suggestionEntry(_ food: Food, tokenized: [[String]]? = nil) -> SuggestionEntry {
        let aliases = tokenized ?? food.aliases.map(tokenize)
        let name = tokenize(food.name)
        let words = Set(aliases.flatMap { $0 } + name).subtracting(fillerWords)
        let chainAliases: [Set<String>]
        if case .chain = food.source { chainAliases = aliases.map(Set.init) } else { chainAliases = [] }
        return SuggestionEntry(food: food, name: name.joined(separator: " "),
                               stems: Set(words.map(stem)), aliases: chainAliases)
    }

    /// A mesma base com produtos de marca salvos no aparelho por cima: eles ganham no empate.
    func adding(_ foods: [Food]) -> FoodParser {
        var copy = self
        for (offset, food) in foods.enumerated() {
            let words = Set(food.aliases.flatMap(Self.tokenize)).subtracting(Self.fillerWords)
            if !words.isEmpty { copy.products.append((words, food)) }
            copy.foods.insert(food, at: offset)
            copy.suggestionEntries.insert(Self.suggestionEntry(food), at: offset)
            for alias in food.aliases {
                let tokens = Self.tokenize(alias)
                guard let first = tokens.first else { continue }
                var group = copy.entries[first, default: []]
                let entry = Entry(tokens: tokens, food: food, rank: offset - foods.count, isGuess: false)
                for word in tokens where copy.knownWords.insert(word).inserted {
                    copy.vocabulary[word.count, default: []].append(word)
                }
                // Nome de produto com "com"/"e" no meio ("Páprica Picante Com Tampa") não pode ser
                // partido em dois itens.
                if tokens.contains(where: Self.separatorWords.contains) {
                    copy.compounds[first, default: []].append(tokens)
                }
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
        self.foods = foods
        suggestionEntries = []
        suggestionEntries.reserveCapacity(foods.count)
        var all: [Entry] = []
        for (rank, food) in foods.enumerated() {
            let tokenized = food.aliases.map(Self.tokenize)
            suggestionEntries.append(Self.suggestionEntry(food, tokenized: tokenized))
            for (alias, tokens) in zip(food.aliases, tokenized) {
                if !tokens.isEmpty {
                    all.append(Entry(tokens: tokens, food: food, rank: rank, isGuess: food.guesses.contains(alias)))
                }
            }
        }
        all.sort { a, b in
            a.tokens.count != b.tokens.count ? a.tokens.count > b.tokens.count : a.rank < b.rank
        }
        entries = Dictionary(grouping: all) { (entry: Entry) in entry.tokens[0] }
        let joined = all.map(\.tokens).filter { $0.contains(where: Self.separatorWords.contains) }
        compounds = Dictionary(grouping: joined) { (tokens: [String]) in tokens[0] }
        labels = Set(FoodDatabase.labels.map { Self.tokenize($0).joined(separator: " ") })
        knownWords = Set(all.flatMap(\.tokens))
        vocabulary = Dictionary(grouping: knownWords.sorted(), by: \.count)
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

        var parsed = pieces.map { piece in (piece: piece, parse: resolve(piece)) }

        // "leite condensado, 2 colheres": a vírgula separou a quantidade da comida. Pedaço que é
        // só quantidade vale pro item de antes (se ele não disse a dele).
        var index = 1
        while index < parsed.count {
            let current = parsed[index].parse
            if current.tokens.isEmpty, current.quantity.isWritten, !each,
               !parsed[index - 1].parse.quantity.isWritten, !parsed[index - 1].parse.tokens.isEmpty {
                parsed[index - 1].parse.quantity = current.quantity
                parsed.remove(at: index)
            } else {
                index += 1
            }
        }

        // Sobrou medida sem comida e sem item antes: "2 postas" é o nome do prato, não a medida.
        for index in parsed.indices where parsed[index].parse.tokens.isEmpty {
            if let measure = parsed[index].parse.quantity.measure {
                parsed[index].parse.tokens = Self.tokenize(measure)
                parsed[index].parse.quantity.measure = nil
            }
        }

        // A quantidade de "cada" pode estar depois das comidas: "arroz e feijão, 10g de cada".
        let shared = each ? parsed.map(\.parse.quantity).first(where: \.isWritten) : nil
        let estimates = parsed.flatMap { piece, parse -> [ItemEstimate] in
            var quantity = parse.quantity
            if each, !quantity.isWritten, let shared {
                quantity = shared
            }
            return estimateItem(piece, quantity: quantity, tokens: parse.tokens)
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
        /// "colher cheia", "pedacinho": a medida é aproximada, o número vira "~".
        var isRough = false
    }

    private struct Parse {
        var quantity: Quantity
        var tokens: [String]
    }

    /// Quantidade + comida de um pedaço. Número no fim ("arroz 3") só vale como quantidade se
    /// não fizer parte do nome: "nescau 2.0" é um produto, não dois Nescau.
    private func resolve(_ piece: String) -> Parse {
        // "YoPRO 25g", "BOLD 14g" e "3 Whey": o número pertence ao produto.
        // Só separa a quantidade fora de um apelido completo, nunca dentro dele.
        if let product = numberedProduct(in: piece) { return product }
        var (quantity, tokens, trailing) = Self.parseQuantity(piece)
        // Medida que também é começo de nome: "prato feito", "2 pratos feitos", "barra de cereal", "barra de proteína".
        // Uma marca sozinha também pode nomear outro produto: "dr peanut" é pasta,
        // mas "barra dr peanut" deve escolher a barra antes de consumir a medida.
        if let measure = quantity.measure {
            let whole = Self.tokenize(measure) + tokens
            let wholeWithDe = Self.tokenize(measure) + ["de"] + tokens
            let match = matchFoods(in: whole)
            let namedSupplement = match.matches.count == 1
                && match.matches.first.map { isSupplementPortion($0.food, measure: measure) } == true
            if match.complete && (!matchFoods(in: tokens).complete || namedSupplement) {
                quantity.measure = nil
                tokens = whole
            } else if !matchFoods(in: tokens).complete, matchFoods(in: wholeWithDe).complete {
                quantity.measure = nil
                tokens = wholeWithDe
            }
        }
        // Medida cujo fim é uma comida quando nada veio depois: "1 xícara de café".
        // A medida vira a medida base ("xícara") e o fim vira a comida ("café").
        if let measure = quantity.measure, tokens.isEmpty {
            let mTokens = Self.tokenize(measure)
            let match = matchFoods(in: mTokens)
            if let first = match.matches.first, first.food.name != "Sopa" {
                let foodTokens = Self.tokenize(first.food.name)
                if let foodStart = mTokens.firstIndex(where: { foodTokens.contains($0) }) {
                    let measurePart = Array(mTokens[..<foodStart])
                    quantity.measure = measurePart.isEmpty ? nil : Self.measure(in: measurePart, at: 0)?.key ?? measurePart.joined(separator: " ")
                    tokens = Array(mTokens[foodStart...])
                }
            }
        }
        if trailing {
            let whole = Self.parseQuantity(piece, allowTrailing: false)
            let match = matchFoods(in: whole.1)
            if !match.matches.isEmpty, match.complete { return Parse(quantity: whole.0, tokens: whole.1) }
        }
        return Parse(quantity: quantity, tokens: tokens)
    }

    private func numberedProduct(in piece: String) -> Parse? {
        let words = piece.split(separator: " ").map(String.init)
        let tokens = words.map(Self.singularize)
        for start in tokens.indices {
            for entry in entries[tokens[start], default: []]
            where entry.tokens.contains(where: { $0.first?.isNumber == true }) {
                let end = start + entry.tokens.count
                guard end <= tokens.count,
                      tokens[start..<end].elementsEqual(entry.tokens) else { continue }
                let outside = (Array(words[..<start]) + Array(words[end...])).joined(separator: " ")
                let (quantity, rest, _) = Self.parseQuantity(outside)
                guard rest.isEmpty else { continue }
                return Parse(quantity: quantity, tokens: entry.tokens)
            }
        }
        return nil
    }

    /// Separa a quantidade do resto, onde quer que ela esteja: "2 colheres de leite condensado",
    /// "leite condensado 2 colheres de sopa", "uma colher e meia de açúcar", "meia dúzia de ovos".
    /// Devolve os tokens que sobram (a comida) e se a quantidade veio depois da comida.
    private static func parseQuantity(_ item: String, allowTrailing: Bool = true) -> (Quantity, [String], Bool) {
        var quantity = Quantity()
        // Ditado: não deixar "eu comi" esconder a contagem de "eu comi 2 ovos".
        // Só remove uma lista fechada de palavras introdutórias, nunca nomes de comida.
        var text = item.replacing(/^(?:(?:eu|hoje|comi|tomei|bebi|almocei|jantei|quero|registrar)\s+)+/, with: "")

        // Quantidade absoluta em qualquer lugar: "200g", "350 ml", "1.5 kg", "500mg", "1.000 g", "8 oz".
        // Abreviada ou por extenso, do mercado ou de receita gringa.
        if let match = text.firstMatch(of: /(\d+(?:\.\d+)?)\s*(miligramas?|mg|quilogramas?|kilogramas?|quilos?|kilos?|kgs?|gramas?|grs?|g|mililitros?|ml|centilitros?|cl|decilitros?|dl|cc|litros?|lts?|l|oz|oncas?|lbs?|libras?)\b/) {
            let unit = singularize(String(match.2))
            let factor = absoluteFactors[unit] ?? 1
            // "1.000 g" é mil gramas: ponto seguido de três dígitos é milhar, não decimal.
            let number = factor <= 1 && match.1.wholeMatch(of: /\d{1,3}(?:\.\d{3})+/) != nil
                ? String(match.1).replacing(".", with: "") : String(match.1)
            quantity.grams = (Double(number) ?? 0) * factor
            quantity.isWritten = true
            text.removeSubrange(match.range)
        }

        var words = text.split(separator: " ").map(String.init)
        var trailing = false

        // Quantidade falada sem número: "um pouco de arroz", "bastante feijão". Vira uma fração
        // da porção de sempre, com "~".
        for (phrase, factor) in vagueAmounts where words.starts(with: phrase) {
            quantity.count = factor
            quantity.isRough = true
            quantity.isWritten = true
            words.removeFirst(phrase.count)
            break
        }

        // Número seguido de medida em qualquer lugar; número sozinho só no começo ou no fim.
        for start in words.indices where !quantity.isRough || start > 0 {
            guard let found = number(in: words, at: start) else { continue }
            var (count, end) = found
            let measure = Self.measure(in: words, at: end)
            let atEnd = end + (measure?.length ?? 0) == words.count
            guard start == 0 || (allowTrailing && (measure != nil || atEnd)) else { continue }
            if let measure {
                let rough = Self.roughMeasures.contains(singularize(words[end + measure.length - 1]))
                end += measure.length
                // "uma colher e meia"
                if end + 1 < words.count, words[end] == "e", ["meia", "meio"].contains(words[end + 1]) {
                    count += 0.5
                    end += 2
                }
                if let multiplier = multipliers[measure.key] {
                    count *= multiplier
                } else {
                    quantity.measure = measure.key
                    quantity.isRough = rough
                }
            }
            end += roughWords(in: words, at: end, quantity: &quantity)
            quantity.count = count
            quantity.isWritten = true
            trailing = start > 0
            words.removeSubrange(start..<end)
            break
        }

        // "1 pão e meio", "2 bananas e meia", "dois bifes e meio"
        if words.count >= 2, words[words.count - 2] == "e", ["meia", "meio"].contains(words[words.count - 1]) {
            quantity.count += 0.5
            quantity.isWritten = true
            words.removeLast(2)
        }

        // Medida sem número no começo: "colher de leite condensado" = uma colher. Só se vier comida depois.
        if !quantity.isWritten || quantity.isRough && quantity.measure == nil,
           let measure = Self.measure(in: words, at: 0), multipliers[measure.key] == nil,
           words.dropFirst(measure.length).contains(where: { !stopWords.contains(singularize($0)) }) {
            var end = measure.length
            quantity.measure = measure.key
            quantity.isRough = Self.roughMeasures.contains(singularize(words[end - 1]))
            end += roughWords(in: words, at: end, quantity: &quantity)
            quantity.isWritten = true
            words.removeSubrange(0..<end)
        }

        // Medida no fim da comida: "coca lata", "coca em lata", "cerveja de lata", "heineken long neck".
        if quantity.measure == nil, words.count >= 2 {
            for start in (1..<words.count).reversed() {
                var mStart = start
                if ["em", "de", "na"].contains(words[mStart]), mStart + 1 < words.count {
                    mStart += 1
                }
                if let measure = Self.measure(in: words, at: mStart),
                   mStart + measure.length == words.count,
                   multipliers[measure.key] == nil {
                    quantity.measure = measure.key
                    quantity.isRough = Self.roughMeasures.contains(singularize(words[words.count - 1]))
                    words.removeSubrange(start..<words.count)
                    break
                }
            }
        }

        var tokens = words.map(singularize)
        while let first = tokens.first, stopWords.contains(first) { tokens.removeFirst() }
        while let last = tokens.last, stopWords.contains(last) { tokens.removeLast() }
        return (quantity, tokens, trailing)
    }

    /// Quanto vale cada unidade de `absoluteUnit` em gramas (ou ml), já no singular.
    private static let absoluteFactors: [String: Double] = [
        "miligrama": 0.001, "mg": 0.001,
        "quilograma": 1000, "kilograma": 1000, "quilo": 1000, "kilo": 1000, "kg": 1000,
        "grama": 1, "gr": 1, "g": 1, "mililitro": 1, "ml": 1, "cc": 1,
        "centilitro": 10, "cl": 10, "decilitro": 100, "dl": 100,
        "litro": 1000, "lt": 1000, "lts": 1000, "l": 1000, "kgs": 1000, "grs": 1, "lbs": 453.6,
        "oz": 28.35, "onca": 28.35, "lb": 453.6, "libra": 453.6,
    ]

    /// Número que começa em `index`: "2", "duas", "1/2", "3x", "x2", "meia dúzia", "1 e meio".
    private static func number(in words: [String], at index: Int) -> (Double, Int)? {
        let word = words[index]
        var value: Double
        if let parsed = parseNumber(word) {
            value = parsed
        } else if let match = word.wholeMatch(of: /x(\d+)/), let parsed = Double(match.1) {
            value = parsed
        } else {
            return nil
        }
        var end = index + 1
        // "um terço", "três quartos"
        if end < words.count, let part = ["terco": 3.0, "quarto": 4.0][singularize(words[end])] {
            value /= part
            end += 1
        }
        // "1 e meio", "dois e meio" (sem medida no meio)
        if end + 1 < words.count, words[end] == "e", ["meia", "meio"].contains(words[end + 1]) {
            value += 0.5
            end += 2
        }
        return (value, end)
    }

    /// Medida caseira que começa em `index`, a mais longa que encaixa ("colher de sopa" antes de
    /// "colher"). Aceita plural e diminutivo: "colheres", "colherzinha", "copinho".
    private static func measure(in words: [String], at index: Int) -> (key: String, length: Int)? {
        guard index < words.count else { return nil }
        let tokens = words[index...].prefix(4).map(singularize)
        for phrase in measurePhrases where phrase.tokens.count <= tokens.count
            && tokens.prefix(phrase.tokens.count).elementsEqual(phrase.tokens) {
            return (phrase.key, phrase.tokens.count)
        }
        return nil
    }

    /// Contagens em grupo: "meia dúzia de ovos", "um par de pães".
    private static let multipliers: [String: Double] = ["duzia": 12, "par": 2, "dezena": 10]

    /// Jeitos de falar quantidade sem número, como fração da porção de sempre.
    private static let vagueAmounts: [([String], Double)] = [
        (["um", "pouquinho"], 0.5), (["um", "pouco"], 0.5), (["um", "tiquinho"], 0.5), (["um", "bocadinho"], 0.5),
        (["pouquinho"], 0.5), (["pouco"], 0.5), (["um", "montao"], 1.5), (["um", "monte"], 1.5),
        (["bastante"], 1.5), (["muito"], 1.5),
    ]

    /// "cheia", "rasa", "bem servido": tira da frase e marca a medida como aproximada.
    private static func roughWords(in words: [String], at index: Int, quantity: inout Quantity) -> Int {
        var length = 0
        while index + length < words.count, roughAdjectives.contains(singularize(words[index + length])) {
            quantity.isRough = true
            length += 1
        }
        return length
    }

    private static let roughAdjectives: Set<String> = ["cheia", "cheio", "cheinha", "rasa", "raso", "bem", "servido", "servida", "generosa", "generoso"]
    /// Diminutivos sem tabela própria: viram a medida de base, mas o número fica "~".
    private static let roughMeasures: Set<String> = [
        "pedacinho", "fatiazinha", "fatinha", "conchinha", "potinho", "garrafinha", "pacotinho", "pratinho", "pratao",
        "pitada", "pitadinha", "fio", "fiozinho", "gota", "gotinha", "dedo", "dedinho", "gole", "golinho", "golada",
        "sache", "sachezinho", "caixinha", "tablete", "quadradinho",
        "dente", "cubo", "cubinho", "lasca", "lasquinha", "naco",
        "calice", "tulipa", "mordida", "mordidinha", "bocado", "borrifada", "envelope", "punhadinho",
        "mancheia", "maozada", "quilinho", "colherona", "conchona", "pedacao", "fationa",
    ]

    /// Todas as medidas que o parser entende, já em tokens, das mais longas pras mais curtas.
    private static let measurePhrases: [(tokens: [String], key: String)] = {
        var phrases = FoodDatabase.measures.keys.map { (tokenize($0), $0) }
        phrases += FoodDatabase.portionWords.map { (tokenize($0), $0) }
        phrases += FoodDatabase.measureSynonyms.map { (tokenize($0.key), $0.value) }
        phrases += multipliers.keys.map { ([$0], $0) }
        return phrases.sorted { $0.0.count > $1.0.count }
    }()

    private func estimateItem(_ item: String, quantity: Quantity, tokens: [String]) -> [ItemEstimate] {
        guard !tokens.isEmpty else { return [] }

        var (matches, complete) = matchFoods(in: tokens)
        // Produto salvo escrito do jeito da pessoa: "páprica picante br spice" acha
        // "Páprica Picante Essencial Br Spices". Toda palavra escrita tem que estar no produto.
        if !complete, let product = savedProduct(for: tokens) {
            matches = [Match(food: product, isGuess: false)]
            complete = true
        }
        // Nada bateu: pode ser erro de digitação ("whoper", "picanah"). Só vale se a correção
        // explicar a frase inteira; senão "eu gostaria muito" vira "mostarda".
        var typo = false
        if matches.isEmpty, let fixed = corrected(tokens) {
            let retry = matchFoods(in: fixed)
            if retry.complete {
                (matches, complete) = retry
                typo = true
            }
        }
        guard !matches.isEmpty else {
            return [ItemEstimate(text: item, foodName: nil, grams: 0, nutrition: .zero, confidence: .unknown)]
        }

        return matches.enumerated().map { index, match in
            let food = match.food
            // A quantidade escrita vale para o primeiro alimento do item.
            let grams: Double
            if index == 0 {
                grams = quantity.grams ?? quantity.count * self.grams(of: food, measure: quantity.measure)
            } else {
                grams = food.portion
            }
            // Certo = tabela oficial, nome entendido inteiro e quantidade dita (ou item de cardápio,
            // que já é uma unidade). Qualquer chute no caminho vira "~".
            let sure = complete && !typo && !match.isGuess && !food.isEstimate && index == 0
                && (quantity.isWritten || food.countsByUnit)
                && hasKnownMeasure(food, measure: quantity.measure) && !quantity.isRough
            return ItemEstimate(text: item, foodName: food.name, grams: grams, nutrition: food.nutrition(grams: grams),
                                confidence: sure ? .exact : .estimated, isPartial: !complete)
        }
    }

    // MARK: - Linha que não entendeu

    /// Por que um pedaço ficou sem número e o que a pessoa pode ter querido dizer.
    struct Help: Sendable {
        /// Só as palavras da comida, sem a quantidade ("2 colheres de xis salada" → "xis salada").
        let foodText: String
        /// Palavras que aparecem em algum alimento da base e as que não aparecem.
        let knownWords: [String]
        let unknownWords: [String]
        /// A frase inteira vira um alimento se consertar uma letra ou outra.
        let typoFix: Food?
        /// Da mais provável pra menos, sem repetir nome.
        let suggestions: [Food]

        var reasons: [String] {
            var reasons: [String] = []
            if let fix = typoFix {
                reasons.append("Parece erro de digitação de “\(fix.name)”.")
            }
            if !knownWords.isEmpty, !unknownWords.isEmpty {
                reasons.append("Conheço “\(knownWords.joined(separator: " "))”, mas não “\(unknownWords.joined(separator: " "))”.")
            } else if typoFix == nil {
                reasons.append("Nenhum alimento da base tem esse nome.")
            }
            if typoFix == nil {
                reasons.append("Pode ser marca, prato regional ou apelido que eu ainda não conheço.")
                reasons.append("Se for produto de mercado, escaneie o código de barras.")
            }
            return reasons
        }
    }

    /// Só as palavras da comida, sem a quantidade: da primeira à última palavra que sobra depois
    /// de tirar a quantidade ("2 colheres de xis salada" → "xis salada").
    func foodText(in piece: String) -> String {
        let normalized = Self.clean(Self.normalize(piece))
        let tokens = Self.parseQuantity(normalized).1
        let words = normalized.split(separator: " ").map(String.init)
        guard let first = words.firstIndex(where: { tokens.first == Self.singularize($0) }),
              let last = words.lastIndex(where: { tokens.last == Self.singularize($0) }), first <= last else { return "" }
        return words[first...last].joined(separator: " ")
    }

    func help(for piece: String) -> Help {
        let normalized = Self.clean(Self.normalize(piece))
        let tokens = Self.parseQuantity(normalized).1
        let foodWords = foodText(in: piece).split(separator: " ").map(String.init)
        let content = foodWords.filter { !Self.fillerWords.contains(Self.singularize($0)) }

        var typoFix: Food?
        if let fixed = corrected(tokens) {
            let retry = matchFoods(in: fixed)
            if retry.complete, retry.matches.count == 1 { typoFix = retry.matches[0].food }
        }
        // Sugestão tem que ter as palavras que o Tobi conhece: "xis salada" sugere salada, nunca
        // salame. Se nenhuma palavra é conhecida ("tapioquinha"), vale o parecido pela raiz.
        let required = Set(content.map(Self.singularize)).intersection(knownWords)
        let similar = candidates(for: normalized, limit: 30).filter { food in
            required.isSubset(of: Set((food.aliases + [food.name]).flatMap(Self.tokenize)))
        }
        var seen = Set<String>()
        let suggestions = ([typoFix].compactMap { $0 } + similar).filter { seen.insert($0.name).inserted }
        return Help(foodText: foodWords.joined(separator: " "),
                    knownWords: content.filter { knownWords.contains(Self.singularize($0)) },
                    unknownWords: content.filter { !knownWords.contains(Self.singularize($0)) },
                    typoFix: typoFix,
                    suggestions: Array(suggestions.prefix(4)))
    }

    /// Alimentos com mais palavras em comum com o pedaço, pra IA escolher entre eles. Mesmo nome
    /// em tabelas diferentes entra uma vez só (a de maior prioridade), e item de rede só entra
    /// se a linha citar a rede ou o nome do item.
    func candidates(for piece: String, limit: Int = 30) -> [Food] {
        let words = Set(Self.tokenize(piece)).subtracting(Self.fillerWords).filter { Self.parseNumber($0) == nil }
        let stems = Set(words.map(Self.stem))
        guard !stems.isEmpty else { return [] }
        var seen = Set<String>()
        var scored: [(score: Double, food: Food)] = []
        for entry in suggestionEntries {
            let hits = stems.intersection(entry.stems).count
            guard hits > 0, seen.insert(entry.name).inserted else { continue }
            if case .chain = entry.food.source, words.isDisjoint(with: Self.chainWords),
               !entry.aliases.contains(where: { $0.isSubset(of: words) }) { continue }
            scored.append((Double(hits) / (Double(stems.count) * Double(entry.stems.count)).squareRoot(), entry.food))
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.food)
    }

    /// O texto que, escrito na linha, volta a ser este alimento: o nome, se ele se lê sozinho
    /// ("Pão com manteiga"), senão o primeiro apelido que funciona.
    func writtenName(for food: Food) -> String? {
        ([food.name] + food.aliases).first { text in
            let items = estimate(text).items
            return items.count == 1 && items[0].foodName == food.name
        }
    }

    private static func stem(_ word: String) -> String { String(word.prefix(4)) }
    private static let chainWords: Set<String> = [
        "mc", "mcdonald", "mequi", "bk", "burger", "king", "kfc", "subway", "bob", "habib", "outback",
        // Marcas de suplemento.
        "growth", "max", "titanium", "integralmedica", "probiotica", "dux", "skull", "optimum", "essential",
        "atlhetica", "athletica", "atletica", "vitafor", "soldier", "nutrata", "bold", "peanut",
        "drpeanut", "maismu", "mu", "yopro", "piracanjuba", "proforce", "darkness", "naturovo",
    ]

    /// O produto salvo que contém todas as palavras escritas; empatando, o de nome mais curto.
    private func savedProduct(for tokens: [String]) -> Food? {
        let words = Set(tokens).subtracting(Self.fillerWords)
        guard !words.isEmpty else { return nil }
        return products.filter { words.isSubset(of: $0.words) }.min { $0.words.count < $1.words.count }?.food
    }

    private func grams(of food: Food, measure: String?) -> Double {
        guard let measure else { return food.portion }
        if let grams = food.measures[measure] { return grams }
        if FoodDatabase.portionWords.contains(measure) { return food.portion }
        if isSupplementPortion(food, measure: measure) { return food.portion }
        if measure == "colher de sopa", let grams = food.measures["colher"] { return grams }
        return FoodDatabase.measures[measure] ?? food.portion
    }

    /// Medida genérica (ex: colher de açúcar sem peso específico) continua sendo um chute.
    private func hasKnownMeasure(_ food: Food, measure: String?) -> Bool {
        guard let measure else { return true }
        return food.measures[measure] != nil || FoodDatabase.portionWords.contains(measure)
            || isSupplementPortion(food, measure: measure)
            || FoodDatabase.absoluteMeasures.contains(measure)
            || (measure == "colher de sopa" && food.measures["colher"] != nil)
    }

    // A embalagem de um snack não tem o peso da medida caseira genérica. Os JSONs
    // mantêm só a porção, sem transformar barra/garrafa em um scoop fictício.
    private static let supplementPortionMeasures: [String: Set<String>] = Dictionary(
        uniqueKeysWithValues: FoodTables.suplementos.compactMap { product in
            guard product.measures.isEmpty else { return nil }
            let name = product.name
            let measures: Set<String>
            if name.hasPrefix("Barra ") || name.hasPrefix("Doctor Bar ") || name.hasPrefix("Crunch ") {
                measures = ["barra"]
            } else if name.hasPrefix("Bebida Láctea ") {
                measures = ["garrafa", "caixinha"]
            } else if name.hasPrefix("Iogurte Líquido ") {
                measures = ["garrafa"]
            } else if name.hasPrefix("Iogurte ") {
                measures = ["pote"]
            } else if name.contains("Energy Gel") {
                measures = ["sache"]
            } else if name.hasPrefix("Pasta de Amendoim ") {
                measures = ["colher", "colher de sopa"]
            } else { return nil }
            return (product.id, measures)
        }
    )

    private func isSupplementPortion(_ food: Food, measure: String) -> Bool {
        guard case .chain(let id, _) = food.source else { return false }
        return Self.supplementPortionMeasures[id]?.contains(measure) == true
    }

    private struct Match {
        let food: Food
        let isGuess: Bool
    }

    /// Da esquerda pra direita, sempre pegando o nome mais longo que encaixa. `complete` diz se
    /// toda palavra que importa entrou em algum nome: "costela do madero" acha a costela, mas
    /// sobra "madero", então o número é estimativa.
    private func matchFoods(in tokens: [String]) -> (matches: [Match], complete: Bool) {
        var found: [Match] = []
        var complete = true
        var i = 0
        while i < tokens.count {
            if let entry = entries[tokens[i], default: []].first(where: { entry in
                i + entry.tokens.count <= tokens.count && tokens[i..<i + entry.tokens.count].elementsEqual(entry.tokens)
            }) {
                found.append(Match(food: entry.food, isGuess: entry.isGuess))
                i += entry.tokens.count
            } else {
                if !Self.fillerWords.contains(tokens[i]) { complete = false }
                i += 1
            }
        }
        return (found, complete)
    }

    /// Medidas caseiras do alimento genérico mais parecido com um nome de produto: "Leite
    /// Condensado Integral Moça" herda a colher de sopa do leite condensado do IBGE.
    func householdMeasures(for name: String) -> [String: Double] {
        matchFoods(in: Self.tokenize(name)).matches.lazy.map(\.food.measures).first { !$0.isEmpty } ?? [:]
    }

    /// Troca cada palavra que a base não conhece pela mais parecida: até 1 letra de diferença,
    /// 2 em palavra longa. Nil se não mudou nada.
    private func corrected(_ tokens: [String]) -> [String]? {
        var changed = false
        let fixed = tokens.map { token -> String in
            // Letra repetida no plural: "ovoss" → "ovos" → "ovo". Só aceita se a base conhece.
            if token.hasSuffix("ss") {
                let singular = Self.singularize(String(token.dropLast()))
                if knownWords.contains(singular) {
                    changed = true
                    return singular
                }
            }
            guard token.count >= 4, !knownWords.contains(token), Self.parseNumber(token) == nil,
                  let closest = closestWord(to: token) else { return token }
            changed = true
            return closest
        }
        return changed ? fixed : nil
    }

    private func closestWord(to token: String) -> String? {
        let limit = token.count >= 8 ? 2 : 1
        let word = Array(token.utf8)
        var best: (word: String, distance: Int)?
        for length in (token.count - limit)...(token.count + limit) {
            for candidate in vocabulary[length, default: []] {
                let distance = Self.editDistance(word, Array(candidate.utf8), limit: best?.distance ?? limit)
                if distance <= limit, distance < (best?.distance ?? .max) { best = (candidate, distance) }
            }
        }
        return best?.word
    }

    /// Levenshtein com saída antecipada: passou do limite, devolve limit + 1.
    /// Distância de edição em que trocar duas letras vizinhas conta como um erro só
    /// ("picanah" → "picanha"), o erro de digitação mais comum no celular.
    static func editDistance(_ a: [UInt8], _ b: [UInt8], limit: Int) -> Int {
        guard abs(a.count - b.count) <= limit else { return limit + 1 }
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var beforePrevious = Array(repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        var previousMin = 0
        for i in 1...a.count {
            current[0] = i
            var rowMin = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    current[j] = min(current[j], beforePrevious[j - 2] + 1)
                }
                rowMin = min(rowMin, current[j])
            }
            // Duas linhas seguidas acima do limite: nem a troca de vizinhas traz de volta.
            if rowMin > limit, previousMin > limit { return limit + 1 }
            swap(&beforePrevious, &previous)
            swap(&previous, &current)
            previousMin = rowMin
        }
        return previous[b.count]
    }


    // MARK: - Texto

    private static let stopWords: Set<String> = ["de", "da", "do", "dos", "das", "o", "a", "os", "as"]
    /// Palavras que podem sobrar sem mudar o que a pessoa comeu.
    private static let fillerWords: Set<String> = stopWords.union([
        "no", "na", "nos", "nas", "em", "um", "uma", "pra", "para", "e", "com", "mais",
        "completo", "completa", "completos", "completas",
    ])

    private static let numberWords: [String: Double] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5,
        "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10, "onze": 11, "doze": 12,
        "treze": 13, "quatorze": 14, "catorze": 14, "quinze": 15, "dezesseis": 16, "dezessete": 17,
        "dezoito": 18, "dezenove": 19, "vinte": 20, "trinta": 30, "quarenta": 40, "cinquenta": 50,
        "sessenta": 60, "setenta": 70, "oitenta": 80, "noventa": 90, "cem": 100, "duzentos": 200, "duzentas": 200,
        "trezentos": 300, "trezentas": 300, "quatrocentos": 400, "quinhentos": 500, "quinhentas": 500,
        "meio": 0.5, "meia": 0.5, "metade": 0.5,
    ]

    /// Minúsculas, sem acento, vírgula decimal virando ponto.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .replacing(/(\d),(\d)/) { "\($0.1).\($0.2)" }
    }

    private static let separatorWords = Set(["e", "com", "mais"].map(singularize))

    /// "arroz, feijão e bife com salada" → ["arroz", "feijão", "bife", "salada"] ("e meia" não separa), mas
    /// "pão com manteiga e café com leite" → ["pão com manteiga", "café com leite"]: o que é
    /// um prato só na base fica junto. Devolve pedaços do próprio texto (mantém acento e maiúscula).
    func items(in text: String) -> [String] {
        var pieces: [String] = []
        var separators: [String] = []
        var start = text.startIndex
        for match in text.matches(of: /(?i)\s+(?:e(?!\s+mei[ao](?:\s+de\b|$))|com|mais)\s+|\s*[+;,]\s*/) {
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
        return items
            .flatMap { splitMeasureNumber($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Medida seguida de número sem pontuação: "Coca 2 copos 1 terço de lasanha" → ["Coca 2 copos", "1 terço de lasanha"].
    private func splitMeasureNumber(_ piece: String) -> [String] {
        let words = piece.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return [piece] }
        // Protege também a ordem marca-primeiro: "atlhetica barra 12g".
        if numberedProduct(in: Self.clean(Self.normalize(piece))) != nil { return [piece] }
        var pieces: [String] = []
        var start = 0
        // Iterativo: uma nota colada com muitas medidas não cresce a pilha de chamadas.
        for i in 1..<(words.count - 1) where i > start {
            let current = words[i].lowercased()
            let singular = Self.singularize(current)
            let isMeasure = FoodDatabase.measures[singular] != nil
                || FoodDatabase.measureSynonyms[singular] != nil
                || FoodDatabase.portionWords.contains(singular)
                || FoodDatabase.measures[current] != nil
            guard isMeasure else { continue }
            let next = words[i + 1].lowercased()
            if Self.parseNumber(next) != nil || next.range(of: #"^\d+"#, options: .regularExpression) != nil {
                // "1 dose 3 whey probiotica" é um produto, não dois itens colados.
                let remainder = words[(i + 1)...].joined(separator: " ")
                if numberedProduct(in: Self.clean(Self.normalize(remainder))) != nil { continue }
                pieces.append(words[start...i].joined(separator: " "))
                start = i + 1
            }
        }
        pieces.append(words[start...].joined(separator: " "))
        return pieces
    }

    /// Algum apelido composto aparece em `joined` atravessando a emenda (e não só num dos lados)?
    private func spansCompound(_ joined: String, left: String, right: String) -> Bool {
        let tokens = Self.tokenize(joined)
        let leftCount = Self.tokenize(left).count
        for start in tokens.indices where start < leftCount {
            for compound in compounds[tokens[start], default: []]
            where start + compound.count > leftCount && start + compound.count <= tokens.count
                && tokens[start..<start + compound.count].elementsEqual(compound) {
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
