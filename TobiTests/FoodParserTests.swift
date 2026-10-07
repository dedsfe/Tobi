import Testing
@testable import Tobi

struct FoodParserTests {
    let parser = FoodParser.shared

    @Test func splitsClassicBrazilianPlate() {
        let estimate = parser.estimate("arroz, feijão e bife")
        #expect(estimate.items.map(\.foodName) == ["Arroz branco", "Feijão", "Bife"])
        #expect(Int(estimate.total.kcal.rounded()) == 531)
    }

    @Test func countsUnits() {
        let estimate = parser.estimate("2 ovos")
        #expect(estimate.items.first?.grams == 100)
    }

    @Test func readsGramsAnywhere() {
        #expect(parser.estimate("200g de frango").items.first?.grams == 200)
        #expect(parser.estimate("frango 150 gramas").items.first?.grams == 150)
        #expect(parser.estimate("1,5 kg de melancia").items.first?.grams == 1500)
    }

    @Test func understandsWordsAndFractions() {
        #expect(parser.estimate("meio pão francês").items.first?.grams == 25)
        #expect(parser.estimate("duas bananas").items.first?.grams == 140)
        #expect(parser.estimate("1/2 pizza").items.first?.grams == 110)
    }

    @Test func usesHouseholdMeasures() {
        #expect(parser.estimate("3 colheres de arroz").items.first?.grams == 75)
        #expect(parser.estimate("2 fatias de pizza").items.first?.grams == 220)
        #expect(parser.estimate("1 copo de leite").items.first?.grams == 240)
        #expect(parser.estimate("1 colher de chá de açúcar").items.first?.grams == 5)
    }

    @Test func prefersLongestName() {
        #expect(parser.estimate("2 pães de queijo").items.first?.foodName == "Pão de queijo")
        #expect(parser.estimate("coca zero").items.first?.foodName == "Refrigerante zero")
        #expect(parser.estimate("ovo frito").items.first?.foodName == "Ovo frito")
    }

    @Test func treatsMealTitlesAsLabels() {
        #expect(parser.estimate("Almoço").isLabel)
        #expect(parser.estimate("Café da manhã:").isLabel)
        #expect(parser.estimate("Almoço: arroz").items.first?.foodName == "Arroz branco")
    }

    @Test func flagsUnknownFood() {
        let estimate = parser.estimate("arroz e xpto")
        #expect(estimate.hasUnknown)
        #expect(estimate.items.first?.isRecognized == true)
    }

    @Test func usesOfficialTacoNumbers() {
        // Feijão carioca cozido, TACO 561: 76 kcal, 8,5 g de fibra e 2 mg de sódio por 100 g.
        let feijao = parser.estimate("100g de feijão").total
        #expect(feijao.kcal == 76)
        #expect(feijao.fiber == 8.5)
        #expect(feijao.sodium == 2)
    }

    @Test func findsFoodsOnlyInTaco() {
        let item = parser.estimate("quiabo").items.first
        #expect(item?.isRecognized == true)
        #expect(item?.foodName?.hasPrefix("Quiabo") == true)
    }

    @Test func tellsQuailEggFromEgg() {
        let item = parser.estimate("6 ovos de codorna").items
        #expect(item.map(\.foodName) == ["Ovo de codorna"])
        #expect(item.first?.grams == 60)
    }

    @Test func matchesTacoVarieties() {
        #expect(parser.estimate("banana da terra").items.first?.foodName == "Banana, da terra, crua")
        #expect(parser.estimate("feijão fradinho").items.first?.foodName == "Feijão, fradinho, cozido")
    }

    @Test func keepsDishesTogether() {
        let names = parser.estimate("pão com manteiga e café com leite").items.map(\.foodName)
        #expect(names == ["Pão com manteiga", "Café com leite"])
    }

    @Test(arguments: ["acarajé", "vatapá", "feijão tropeiro", "galinhada", "misto quente", "pudim",
                      "brigadeiro", "farofa", "pão de queijo", "cuscuz", "canjica", "pamonha",
                      "frango à milanesa", "bisteca de porco", "mandioquinha", "jiló", "caldo de cana",
                      "suco de maracujá", "vitamina de banana", "sopa de legumes"])
    func knowsBrazilianFood(food: String) {
        #expect(parser.estimate(food).items.first?.isRecognized == true)
    }

    @Test func usesIbgeMeasures() {
        // IBGE: pamonha = 160 g a unidade, 40 g a fatia.
        #expect(parser.estimate("2 pamonhas").items.first?.grams == 320)
        #expect(parser.estimate("1 fatia de pamonha").items.first?.grams == 40)
    }

    @Test func curatedWinsOverTaco() {
        #expect(parser.estimate("arroz").items.first?.foodName == "Arroz branco")
        #expect(parser.estimate("banana").items.first?.foodName == "Banana")
    }

    @Test func emptyLineIsEmpty() {
        #expect(parser.estimate("   ") == .empty)
    }
}
