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
    private let labels: Set<String>
    /// Apelidos que têm um separador dentro ("café com leite", "alho e óleo"), pela primeira palavra.
    /// Na hora de dividir a linha em itens, esses ficam inteiros.
    private var compounds: [String: [[String]]]
    /// Toda palavra que aparece em algum apelido, pelo tamanho. Serve pra consertar erro de digitação.
    private var vocabulary: [Int: [String]]
    private var knownWords: Set<String>

    static let shared = FoodParser(foods: FoodDatabase.foods)

    /// A mesma base com produtos de marca salvos no aparelho por cima: eles ganham no empate.
    func adding(_ foods: [Food]) -> FoodParser {
        var copy = self
        for (offset, food) in foods.enumerated() {
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
        var all: [Entry] = []
        for (rank, food) in foods.enumerated() {
            for alias in food.aliases {
                let tokens = Self.tokenize(alias)
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
        let (quantity, tokens, trailing) = Self.parseQuantity(piece)
        if trailing {
            let whole = Self.parseQuantity(piece, allowTrailing: false)
            let match = matchFoods(in: whole.1)
            if !match.matches.isEmpty, match.complete { return Parse(quantity: whole.0, tokens: whole.1) }
        }
        return Parse(quantity: quantity, tokens: tokens)
    }

    /// Separa a quantidade do resto, onde quer que ela esteja: "2 colheres de leite condensado",
    /// "leite condensado 2 colheres de sopa", "uma colher e meia de açúcar", "meia dúzia de ovos".
    /// Devolve os tokens que sobram (a comida) e se a quantidade veio depois da comida.
    private static func parseQuantity(_ item: String, allowTrailing: Bool = true) -> (Quantity, [String], Bool) {
        var quantity = Quantity()
        // Ditado: não deixar "eu comi" esconder a contagem de "eu comi 2 ovos".
        // Só remove uma lista fechada de palavras introdutórias, nunca nomes de comida.
        var text = item.replacing(/^(?:(?:eu|hoje|comi|tomei|bebi|almocei|jantei|quero|registrar)\s+)+/, with: "")

        // Quantidade absoluta em qualquer lugar: "200g", "350 ml", "1.5 kg".
        if let match = text.firstMatch(of: /(\d+(?:\.\d+)?)\s*(kg|gramas?|gr|g|ml|litros?|l)\b/) {
            let value = Double(match.1) ?? 0
            let unit = String(match.2)
            quantity.grams = value * (["kg", "l", "litro", "litros"].contains(unit) ? 1000 : 1)
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

        var tokens = words.map(singularize)
        while let first = tokens.first, stopWords.contains(first) { tokens.removeFirst() }
        while let last = tokens.last, stopWords.contains(last) { tokens.removeLast() }
        return (quantity, tokens, trailing)
    }

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
            && Array(tokens.prefix(phrase.tokens.count)) == phrase.tokens {
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
                                confidence: sure ? .exact : .estimated)
        }
    }

    private func grams(of food: Food, measure: String?) -> Double {
        guard let measure else { return food.portion }
        if let grams = food.measures[measure] { return grams }
        if FoodDatabase.portionWords.contains(measure) { return food.portion }
        if measure == "colher de sopa", let grams = food.measures["colher"] { return grams }
        return FoodDatabase.measures[measure] ?? food.portion
    }

    /// Medida genérica (ex: colher de açúcar sem peso específico) continua sendo um chute.
    private func hasKnownMeasure(_ food: Food, measure: String?) -> Bool {
        guard let measure else { return true }
        return food.measures[measure] != nil || FoodDatabase.portionWords.contains(measure)
            || FoodDatabase.absoluteMeasures.contains(measure)
            || (measure == "colher de sopa" && food.measures["colher"] != nil)
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
                i + entry.tokens.count <= tokens.count && Array(tokens[i..<i + entry.tokens.count]) == entry.tokens
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
    static func editDistance(_ a: [UInt8], _ b: [UInt8], limit: Int) -> Int {
        guard abs(a.count - b.count) <= limit else { return limit + 1 }
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            var rowMin = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMin = min(rowMin, current[j])
            }
            if rowMin > limit { return limit + 1 }
            previous = current
        }
        return previous[b.count]
    }

    // MARK: - Texto

    private static let stopWords: Set<String> = ["de", "da", "do", "dos", "das", "o", "a", "os", "as"]
    /// Palavras que podem sobrar sem mudar o que a pessoa comeu.
    private static let fillerWords: Set<String> = stopWords.union(["no", "na", "nos", "nas", "em", "um", "uma", "pra", "para", "e", "com", "mais"])

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

    private static let separatorWords: Set<String> = ["e", "com", "mais"]

    /// "arroz, feijão e bife com salada" → ["arroz", "feijão", "bife", "salada"] ("e meia" não separa), mas
    /// "pão com manteiga e café com leite" → ["pão com manteiga", "café com leite"]: o que é
    /// um prato só na base fica junto. Devolve pedaços do próprio texto (mantém acento e maiúscula).
    func items(in text: String) -> [String] {
        var pieces: [String] = []
        var separators: [String] = []
        var start = text.startIndex
        for match in text.matches(of: /(?i)\s+(?:e(?!\s+mei[ao]\b)|com|mais)\s+|\s*[+;,]\s*/) {
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
