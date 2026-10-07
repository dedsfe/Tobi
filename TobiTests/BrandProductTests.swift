import Testing
@testable import Tobi

struct BrandProductTests {
    private let toddynho = Food(
        brand: "Bebida Láctea Toddynho Levinho 200ml", aliases: ["Bebida Láctea Toddynho Levinho 200ml", "toddynho"],
        per100: Nutrition(kcal: 55, protein: 2.5, carbs: 9, fat: 1, sugar: 8),
        barcode: "7894321242521", portion: 200
    )

    @Test func savedProductIsRecognizedOffline() {
        let parser = FoodParser.shared.adding([toddynho])
        let item = parser.estimate("1 toddynho").items.first
        #expect(item?.foodName == toddynho.name)
        #expect(item?.grams == 200)
        #expect(item?.nutrition.sugar == 16)
    }

    @Test func savedProductWinsTies() {
        let parser = FoodParser.shared.adding([toddynho])
        #expect(parser.estimate("toddynho").items.first?.foodName == toddynho.name)
    }

    @Test func sharedParserIsUntouched() {
        _ = FoodParser.shared.adding([toddynho])
        // O IBGE já conhece "Toddynho"; o produto salvo não pode vazar pra base compartilhada.
        #expect(FoodParser.shared.estimate("toddynho").items.first?.foodName == "Toddynho")
    }
}
