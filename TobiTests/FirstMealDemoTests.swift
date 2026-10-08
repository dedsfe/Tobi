import Testing
@testable import Tobi

struct FirstMealDemoTests {
    @Test(arguments: FirstMealDemo.lines)
    func everyDemoLineIsUnderstood(_ line: String) {
        let estimate = FoodParser.shared.estimate(line)
        if estimate.isLabel { return }
        #expect(!estimate.items.isEmpty, "\(line)")
        #expect(!estimate.hasUnknown, "\(line)")
        #expect(estimate.total.kcal > 0, "\(line)")
    }

    @Test func mealTitlesAreLabels() {
        #expect(FoodParser.shared.estimate("Café da manhã").isLabel)
        #expect(FoodParser.shared.estimate("Almoço").isLabel)
    }

    @Test(arguments: InputMethodsDemo.writeLines + [InputMethodsDemo.spokenLine])
    func everyShowcaseLineIsUnderstood(_ line: String) {
        let estimate = FoodParser.shared.estimate(line)
        #expect(!estimate.items.isEmpty, "\(line)")
        #expect(!estimate.hasUnknown, "\(line)")
        #expect(estimate.total.kcal > 0, "\(line)")
    }
}
