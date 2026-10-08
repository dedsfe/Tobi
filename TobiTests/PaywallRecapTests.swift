import Foundation
import Testing
@testable import Tobi

struct PaywallRecapTests {
    private let today = Calendar.current.startOfDay(for: .now)

    @Test func sumsCaloriesAndMacrosSinceTheStart() throws {
        let note = DayNote(day: today, text: "Almoço\narroz, feijão e bife\n2 ovos")
        let recap = try #require(PaywallRecap(notes: [note], since: today))
        let total = ["arroz, feijão e bife", "2 ovos"].map { FoodParser.shared.estimate($0).total }.total
        #expect(recap.kcal == Int(total.kcal.rounded()))
        #expect(recap.carbsGrams == Int(total.carbs.rounded()))
        #expect(recap.proteinGrams == Int(total.protein.rounded()))
        #expect(recap.fatGrams == Int(total.fat.rounded()))
        #expect(recap.days == 1)
    }

    @Test func goalShareAveragesTheDaysWritten() {
        #expect(PaywallRecap(kcal: 3000, carbsGrams: 0, proteinGrams: 0, fatGrams: 0, days: 2).share(of: 2000) == 0.75)
        #expect(PaywallRecap(kcal: 3000, carbsGrams: 0, proteinGrams: 0, fatGrams: 0, days: 1).share(of: 2000) == 1.5)
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

    @Test func emptyScreenExamplesAreFullyUnderstood() {
        for example in NothingWrittenHero.examples {
            let estimate = FoodParser.shared.estimate(example)
            #expect(!estimate.items.isEmpty, "\(example)")
            #expect(!estimate.hasUnknown, "\(example)")
            #expect(estimate.total.kcal > 0, "\(example)")
        }
    }
}
