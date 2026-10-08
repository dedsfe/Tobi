import Foundation

/// Nome de produto do Open Food Facts do jeito que vai pra linha: sem tamanho de embalagem
/// ("2Lt", "Pacote 90g"), que o parser leria como quantidade, e com a marca na frente quando o
/// nome não traz ("2.0" → "Nescau 2.0"), pra linha dizer de qual produto se trata.
enum ProductName {
    static func clean(_ name: String, brands: [String]) -> String {
        var text = name
            .replacing(/(?i)\b\d+(?:[.,]\d+)?\s*(?:kg|gr?|mg|ml|lts?|l|litros?|un|unid(?:ades?)?)\b/, with: " ")
            .replacing(/(?i)\b(?:caixa|pacote|lata|garrafa|pet|sach[eê]|pote|embalagem|uht|vidro|frasco|bandeja)\b/, with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–,.;/"))
        if text == text.uppercased(), text != text.lowercased() { text = text.capitalized }

        // Marca do produto: a que já aparece no nome, senão a mais específica (a última: "Nestlé, Nescau").
        let words = Set(FoodParser.tokenize(text))
        let brand = brands.first { brand in
            let tokens = FoodParser.tokenize(brand)
            return !tokens.isEmpty && tokens.allSatisfy(words.contains)
        }
        if brand == nil, let product = brands.last {
            text = text.isEmpty ? product : "\(product) \(text)"
        }
        return text.isEmpty ? name : text
    }
}
