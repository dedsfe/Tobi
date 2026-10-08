import Foundation

/// Nome de produto do Open Food Facts do jeito que vai pra linha: sem tamanho de embalagem
/// ("2Lt", "Pacote 90g"), que o parser leria como quantidade, e com a marca na frente quando o
/// nome não traz ("2.0" → "Nescau 2.0"), pra linha dizer de qual produto se trata. E curto, do jeito
/// que a pessoa escreveria: sem "com tampa dosadora", sem "tempero", com a marca no fim
/// ("BR Spice Páprica Picante Tempero" → "Páprica Picante BR Spice").
enum ProductName {
    static func clean(_ name: String, brands: [String]) -> String {
        var text = name
            .replacing(/(?i)\b\d+(?:[.,]\d+)?\s*(?:kg|gr?|mg|ml|lts?|l|litros?|un|unid(?:ades?)?)\b/, with: " ")
            .replacing(/(?i)\b(?:com\s+)?tampa(?:\s+dosadora)?\b|\bdosador[a]?\b|\brefil\b|\babre\s+f[aá]cil\b|\bleve\s+\d+\s+pague\s+\d+\b|\btamanho\s+fam[ií]lia\b|\bembalagem\s+econ[oô]mica\b/, with: " ")
            .replacing(/(?i)\b(?:caixa|pacote|lata|garrafa|pet|sach[eê]|pote|embalagem|uht|vidro|frasco|bandeja)\b/, with: " ")
            .replacing(/(?i)\b(?:tempero|condimento|produto)\b/, with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–,.;/"))
        if text == text.uppercased(), text != text.lowercased() { text = text.capitalized }
        text = withoutRepeatedWords(text)

        // Marca do produto: a que já aparece no nome, senão a mais específica (a última: "Nestlé, Nescau").
        let words = Set(FoodParser.tokenize(text))
        let brand = brands.first { brand in
            let tokens = FoodParser.tokenize(brand)
            return !tokens.isEmpty && tokens.allSatisfy(words.contains)
        }
        if brand == nil, let product = brands.last {
            text = text.isEmpty ? product : "\(product) \(text)"
        } else if let brand {
            text = brandAtTheEnd(text, brand: brand)
        }
        return text.isEmpty ? name : text
    }

    /// "Nescau Nescau 2.0" → "Nescau 2.0": o Open Food Facts às vezes repete a marca.
    private static func withoutRepeatedWords(_ text: String) -> String {
        var seen = Set<String>()
        return text.split(separator: " ").filter { word in
            word.count <= 3 || seen.insert(FoodParser.normalize(String(word))).inserted
        }.joined(separator: " ")
    }

    /// Marca no começo e pelo menos duas palavras depois: a marca vai pro fim, como se fala
    /// ("BR Spice Páprica Picante" → "Páprica Picante BR Spice"). "União Refinado" fica como está.
    private static func brandAtTheEnd(_ text: String, brand: String) -> String {
        let target = FoodParser.tokenize(brand)
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return text }
        for count in 1...min(words.count, max(target.count, 1) + 2) {
            let head = FoodParser.tokenize(words.prefix(count).joined(separator: " "))
            if head == target {
                let rest = words.dropFirst(count)
                return rest.count >= 2 ? (rest + words.prefix(count)).joined(separator: " ") : text
            }
            if head.count >= target.count { break }
        }
        return text
    }
}
