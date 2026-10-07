import Foundation

/// Enxuga uma linha quando a pessoa termina de escrever, sem IA e sem perder comida:
/// "hoje no almoço eu comi um prato de arroz com feijão e duas coxas"
///   → "1 prato de arroz, feijão, 2 coxas".
/// Só sai palavra de enchimento; o que o Tobi não entende fica do jeito que estava.
enum LineRewriter {
    static func compact(_ line: String) -> String {
        // "Almoço: ..." — o título fica intocado.
        var title = ""
        var body = line
        if let colon = line.lastIndex(of: ":") {
            title = String(line[...colon]) + " "
            body = String(line[line.index(after: colon)...])
        }

        // Espaço nas pontas pra todo padrão poder exigir palavra inteira dos dois lados.
        var text = " " + body.replacingOccurrences(of: "\n", with: " ") + " "
        for filler in fillers {
            while text.contains(filler) { text.replace(filler, with: " ") }
        }
        // Divide como o parser divide, então "café com leite" continua junto.
        let items = FoodParser.shared.items(in: text)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .map(digitizeCount)

        guard !items.isEmpty else { return line }
        return title + items.joined(separator: ", ")
    }

    // MARK: - Regras

    private static var fillers: [Regex<Substring>] { [
        // Quando: "no almoço", "de manhã", "à noite", "no café da manhã".
        /(?i)\s(?:no|na|de|pela|pelo|a|à|ao)\s(?:almo[cç]o|janta|jantar|caf[eé] da manh[aã]|manh[aã]|tarde|noite)(?=\s)/,
        // Quem e o verbo: "eu comi", "acabei de comer", "tomei".
        /(?i)\s(?:acabei de (?:comer|tomar|beber)|eu|comi|tomei|bebi|almocei|jantei|lanchei|belisquei)(?=\s)/,
        // Muleta: "hoje", "agora", "tipo", "aí".
        /(?i)\s(?:hoje|hj|ontem|agora|tipo|a[ií]|da[ií]|ent[aã]o|s[oó])(?=\s)/,
    ] }

    private static let counts: [String: String] = [
        "um": "1", "uma": "1", "dois": "2", "duas": "2", "tres": "3", "três": "3", "quatro": "4",
        "cinco": "5", "seis": "6", "sete": "7", "oito": "8", "nove": "9", "dez": "10",
    ]

    /// "duas coxas" → "2 coxas". "meio"/"meia" ficam, que ficam mais claros por extenso.
    private static func digitizeCount(_ item: String) -> String {
        guard let space = item.firstIndex(of: " "),
              let digit = counts[item[..<space].lowercased()] else { return item }
        return digit + item[space...]
    }
}
