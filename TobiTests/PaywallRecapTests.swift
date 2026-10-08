import Foundation
import Testing
@testable import Tobi

struct PaywallRecapTests {
    private let today = Calendar.current.startOfDay(for: .now)

    @Test func sumsFoodsCaloriesAndProteinSinceTheStart() throws {
        let note = DayNote(day: today, text: "Almoço\narroz, feijão e bife\n2 ovos")
        let recap = try #require(PaywallRecap(notes: [note], since: today))
        let lines = ["arroz, feijão e bife", "2 ovos"].map(FoodParser.shared.estimate)
        #expect(recap.foods == 4)
        #expect(recap.kcal == Int(lines.map(\.total.kcal).reduce(0, +).rounded()))
        #expect(recap.proteinGrams == Int(lines.map(\.total.protein).reduce(0, +).rounded()))
    }

    @Test func leavesOutDaysBeforeTheStart() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let old = DayNote(day: yesterday, text: "arroz, feijão e bife")
        #expect(PaywallRecap(notes: [old], since: today) == nil)
    }

    @Test func nothingWrittenMeansNoRecap() {
        let empty = DayNote(day: today, text: "Café da manhã\n")
        #expect(PaywallRecap(notes: [empty], since: today) == nil)
    }
}
