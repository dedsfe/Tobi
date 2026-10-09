import Testing
@testable import Tobi

/// Whey e hipercalórico de marca: o jeito que quem treina escreve vira o rótulo certo.
@Suite("Suplementos de marca")
struct SupplementTests {
    let parser = FoodParser.shared

    private func item(_ line: String) -> (name: String?, grams: Double?, kcal: Int) {
        let estimate = parser.estimate(line)
        return (estimate.items.first?.foodName, estimate.items.first?.grams, Int(estimate.total.kcal.rounded()))
    }

    @Test func scoopsOfGrowth() {
        let result = item("2 scoops de whey growth")
        #expect(result.name == "Whey Protein Concentrado (Growth)")
        #expect(result.grams == 60)
        #expect(result.kcal == 244)
    }

    @Test func doseOfTopWhey() {
        let result = item("1 dose de top whey")
        #expect(result.name == "Top Whey 3W (Max Titanium)")
        #expect(result.grams == 40)
        #expect(result.kcal == 165)
    }

    @Test func dosadoresOfMaxTitanium() {
        let result = item("3 dosadores whey max titanium")
        #expect(result.name == "100% Whey (Max Titanium)")
        #expect(result.grams == 45)
    }

    @Test func isolatedGrowth() {
        #expect(item("whey isolado da growth").name == "Whey Protein Isolado (Growth)")
    }

    @Test func plainWheyStaysGeneric() {
        #expect(item("1 scoop de whey").name == "Whey")
    }

    @Test func massTitanium() {
        let result = item("mass titanium")
        #expect(result.name == "Mass Titanium 17500 (Max Titanium)")
        #expect(result.kcal == 604)
    }

    @Test func massTitaniumWithNumberIsNotAQuantity() {
        let result = item("mass titanium 17500")
        #expect(result.name == "Mass Titanium 17500 (Max Titanium)")
        #expect(result.kcal == 604)
    }

    @Test func gramsOfGoldStandard() {
        let result = item("30g de gold standard")
        #expect(result.name == "Gold Standard 100% Whey (Optimum Nutrition)")
        #expect(result.kcal == 118)
    }

    @Test func wheyWithBrandFirst() {
        #expect(item("1 scoop growth whey").name == "Whey Protein Concentrado (Growth)")
        #expect(item("whey integralmedica").name == "Whey 100% Pure (Integralmédica)")
        #expect(item("whey black skull").name == "Whey 100% HD (Black Skull)")
    }
}
