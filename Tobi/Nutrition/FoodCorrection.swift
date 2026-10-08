import Foundation

/// Melhora só o nome escolhido: quantidades, medidas e o resto da nota ficam intactos.
enum FoodCorrection {
    static func replacing(_ foodText: String, in line: String, with food: Food, parser: FoodParser) -> String? {
        guard !foodText.isEmpty, let name = parser.writtenName(for: food) else { return nil }
        var remaining = line.startIndex..<line.endIndex
        var found: Range<String.Index>?
        while let range = line.range(of: foodText, options: [.caseInsensitive, .diacriticInsensitive], range: remaining) {
            let startsWord = range.lowerBound == line.startIndex || !line[line.index(before: range.lowerBound)].isLetter
                && !line[line.index(before: range.lowerBound)].isNumber
            let endsWord = range.upperBound == line.endIndex || !line[range.upperBound].isLetter && !line[range.upperBound].isNumber
            if startsWord && endsWord {
                // Trecho repetido é ambíguo: não adivinha qual refeição trocar.
                guard found == nil else { return nil }
                found = range
            }
            remaining = range.upperBound..<line.endIndex
        }
        guard let found else { return nil }
        var rewritten = line
        rewritten.replaceSubrange(found, with: name)
        return rewritten
    }
}
