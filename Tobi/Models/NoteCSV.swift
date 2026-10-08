import Foundation

/// Só valores: o exportador não leva modelos SwiftData para outra thread.
enum NoteCSV {
    struct Row: Sendable {
        let day: Date
        let text: String
    }

    static func data(_ notes: [Row], parser: FoodParser = .shared) throws -> Data {
        var rows = ["data,linha,kcal,carboidratos_g,proteina_g,gordura_g"]
        var estimates: [String: Nutrition] = [:]
        for note in notes {
            try Task.checkCancellation()
            let day = note.day.formatted(.iso8601.year().month().day())
            for line in note.text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                try Task.checkCancellation()
                let source = String(line)
                let nutrition: Nutrition
                if let cached = estimates[source] {
                    nutrition = cached
                } else {
                    nutrition = parser.estimate(source).total
                    if estimates.count < 500 { estimates[source] = nutrition }
                }
                let text = "\"" + line.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                let numbers = [nutrition.kcal, nutrition.carbs, nutrition.protein, nutrition.fat]
                    .map { String(Int($0.rounded())) }
                rows.append(([day, text] + numbers).joined(separator: ","))
            }
        }
        return Data(rows.joined(separator: "\n").utf8)
    }
}
