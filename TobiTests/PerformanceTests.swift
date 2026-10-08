import Foundation
import Testing
@testable import Tobi

struct PerformanceTests {
    @Test func suggestionsUseThePreparedIndex() async {
        let parser = await FoodParser.prepared()
        let start = ContinuousClock.now
        for _ in 0..<20 {
            #expect(!parser.candidates(for: "abobrinha gratinada diferente", limit: 3).isEmpty)
        }
        // Margem ampla: a versão que reanalisava a base levava mais de 11 s neste cenário.
        #expect(start.duration(to: .now) < .seconds(2))
    }

    @Test func savedProductStillWinsSuggestionTies() {
        let base = Food(brand: "Banana", aliases: ["banana"], per100: Nutrition(kcal: 90), barcode: "base", portion: 100)
        let saved = Food(brand: "Banana", aliases: ["banana"], per100: Nutrition(kcal: 110), barcode: "saved", portion: 100)
        let parser = FoodParser(foods: [base]).adding([saved])
        let result = parser.candidates(for: "banana")
        #expect(result.count == 1)
        #expect(result.first?.source == .brand("saved"))
    }

    @Test func quantitiesInLargePastedTextDoNotNeedRecursion() {
        let parser = FoodParser(foods: [])
        let line = Array(repeating: "1 arroz 2 copos", count: 2_000).joined(separator: " ")
        let pieces = parser.items(in: line)
        #expect(pieces.count == 2_000)
        #expect(pieces.first == "1 arroz 2 copos")
        #expect(pieces.last == "1 arroz 2 copos")
    }

    @Test func reusedDistanceRowsPreserveAdjacentLetterSwaps() {
        let pairs = [("picanah", "picanha", 1), ("banana", "banaba", 1), ("ovo", "ovo", 0), ("abc", "xyz", 3)]
        for (left, right, expected) in pairs {
            #expect(FoodParser.editDistance(Array(left.utf8), Array(right.utf8), limit: 3) == expected)
        }
    }

    @Test func csvPreservesEscapingNumbersAndSkipsBlankLines() throws {
        let parser = FoodParser(foods: [])
        let row = NoteCSV.Row(day: Date(timeIntervalSince1970: 0), text: "\"teste\", desconhecido\n\n   \n")
        let data = try NoteCSV.data([row], parser: parser)
        let csv = try #require(String(data: data, encoding: .utf8))
        #expect(csv.split(separator: "\n").count == 2)
        #expect(csv.contains("\"\"\"teste\"\", desconhecido\",0,0,0,0"))
    }

    @Test func canceledExportStopsBeforeCalculatingRows() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try NoteCSV.data([.init(day: .now, text: "2 ovos")])
        }
        do {
            _ = try await task.value
            Issue.record("Exportação cancelada continuou calculando")
        } catch is CancellationError {
        } catch {
            Issue.record("Erro inesperado: \(error)")
        }
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
struct EditorPerformanceTests {
    @Test func fullTextReplacementRestoresUnchangedTitleStyle() {
        let view = NoteTextView.make()
        let parser = FoodParser.shared
        view.setTextKeepingCaret("Almoço\n2 ovos")
        view.marks = ["Almoço", "2 ovos"].map { LineMark(estimate: parser.estimate($0)) }
        view.setTextKeepingCaret("Almoço\n3 ovos")
        let font = view.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(font == NoteTextView.titleFont)
    }

    @Test func estimateCacheIsBoundedWithoutDiscardingEveryRecentLine() {
        let cache = EstimateCache(capacity: 3, byteLimit: 100)
        let parser = FoodParser(foods: [])
        for source in ["a", "b", "c", "d"] { _ = cache.estimate(source, with: parser) }
        #expect(cache.count == 3)
        cache.removeAll()
        #expect(cache.count == 0)
        _ = cache.estimate(String(repeating: "a", count: 101), with: parser)
        #expect(cache.count == 0)
    }
}
#endif
