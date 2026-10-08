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

    @Test func quantityGoesToTheItemWhereItIsWritten() {
        let items = parser.estimate("10 gramas de bacon, arroz e feijão").items
        #expect(items.map(\.grams) == [10, 150, 140])
    }

    @Test func eachSpreadsTheQuantity() {
        #expect(parser.estimate("10 gramas de bacon, arroz e feijão cada").items.map(\.grams) == [10, 10, 10])
        #expect(parser.estimate("2 colheres de arroz e feijão cada").items.map(\.grams) == [50, 40])
        #expect(parser.estimate("100g de cada, arroz e frango").items.map(\.grams) == [100, 100])
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

    // MARK: - Fast food (tabelas oficiais das redes)

    @Test func countsFastFoodByTheUnit() {
        let estimate = parser.estimate("2 big mac")
        #expect(estimate.items.map(\.foodName) == ["Big Mac (McDonald's)"])
        #expect(Int(estimate.total.kcal.rounded()) == 1048)
    }

    @Test func readsChainSizesAndNicknames() {
        #expect(parser.estimate("mc fritas média").items.first?.foodName == "McFritas Média (McDonald's)")
        #expect(parser.estimate("batata do mc").items.first?.foodName == "McFritas Média (McDonald's)")
        #expect(Int(parser.estimate("whopper").total.kcal.rounded()) == 717)
        #expect(parser.estimate("whopper do bk").items.first?.foodName == "Whopper (Burger King)")
        #expect(parser.estimate("mcflurry").items.first?.foodName == "McFlurry Ovomaltine Rocks chocolate (McDonald's)")
        #expect(Int(parser.estimate("10 mcnuggets").total.kcal.rounded()) == 387)
    }

    @Test func recoversChainsPublishedPer100Grams() {
        // Bob's e Habib's: o peso da unidade sai do rótulo ("100 g = 3/7 do Big Bob").
        #expect(Int(parser.estimate("big bob").total.kcal.rounded()) == 602)
        #expect(parser.estimate("beirute de kafta do habibs").items.first?.foodName == "Beirute de Kafta (Habib's)")
        #expect(parser.estimate("2 fatias de pizza de mussarela do habibs").items.first?.grams == 172)
    }

    // MARK: - Confiança

    @Test func officialTableWithClearQuantityIsExact() {
        #expect(parser.estimate("2 big mac").confidence == .exact)
        #expect(parser.estimate("whopper").confidence == .exact)
        #expect(parser.estimate("200g de arroz").confidence == .exact)
        #expect(parser.estimate("2 ovos").confidence == .exact)
    }

    @Test func guessesAreEstimated() {
        #expect(parser.estimate("arroz").confidence == .estimated)       // porção chutada
        #expect(parser.estimate("1 pizza").confidence == .estimated)     // prato genérico
        #expect(parser.estimate("mcflurry").confidence == .estimated)    // sabor padrão
        #expect(parser.estimate("bloomin onion").confidence == .estimated) // tabela dos EUA
    }

    @Test func halfUnderstoodNameIsEstimated() {
        let estimate = parser.estimate("2 costelas do madero")
        #expect(estimate.items.first?.isRecognized == true)
        #expect(estimate.confidence == .estimated)
    }

    @Test func fixesTypos() {
        let estimate = parser.estimate("whoper")
        #expect(estimate.items.first?.foodName == "Whopper (Burger King)")
        #expect(estimate.confidence == .estimated)
        #expect(parser.estimate("2 bananaz").items.first?.foodName == "Banana")
    }

    @Test func unknownStaysUnknown() {
        let estimate = parser.estimate("xablau")
        #expect(estimate.hasUnknown)
        #expect(estimate.confidence == .unknown)
        #expect(estimate.total.kcal == 0)
    }

    @Test func chainsDoNotStealCommonFood() {
        #expect(parser.estimate("batata frita").items.first?.foodName == "Batata frita")
        #expect(parser.estimate("pão de queijo").items.first?.foodName == "Pão de queijo")
        #expect(parser.estimate("cheeseburger").items.first?.foodName?.contains("(") != true)
    }
}

/// Quantidade do jeito que o brasileiro escreve e fala (medidas da POF 2008-2009 do IBGE).
struct BrazilianQuantityTests {
    let parser = FoodParser.shared

    private func grams(_ line: String) -> Double? { parser.estimate(line).items.first?.grams }

    @Test func quantityAfterTheFood() {
        #expect(grams("arroz 3 colheres") == grams("3 colheres de arroz"))
        #expect(grams("leite condensado, 2 colheres de sopa") == grams("2 colheres de sopa de leite condensado"))
        #expect(parser.estimate("leite condensado, 2 colheres de sopa").items.count == 1)
        #expect(grams("ovo x2") == grams("2 ovos"))
    }

    @Test func spokenNumbersAndHalves() {
        #expect(grams("uma colher e meia de açúcar") == 1.5 * grams("1 colher de açúcar")!)
        #expect(grams("meia dúzia de ovos") == grams("6 ovos"))
        #expect(grams("quinze morangos") == 15 * grams("1 morango")!)
    }

    @Test func householdMeasures() {
        #expect(grams("1 colher de chá de açúcar") == 5)
        #expect(grams("2 colheres de sobremesa de mel") != nil)
        #expect(grams("um copo americano de suco") == 150)
        #expect(grams("1 xícara de café de leite") == 50)
        #expect(grams("ponta de faca de manteiga") != nil)
        #expect(parser.estimate("ponta de faca de manteiga").items.first?.foodName == "Manteiga")
    }

    @Test func diminutivesAndRoughMeasuresAreEstimates() {
        #expect(grams("2 colherzinhas de açúcar") == 10)
        #expect(parser.estimate("1 colher cheia de açúcar").confidence == .estimated)
        #expect(parser.estimate("um pedacinho de bolo").confidence == .estimated)
    }

    @Test func numbersInsideNamesStayInTheName() {
        // "Tasty Turbo 1 carne" é um sanduíche, não 1 carne.
        #expect(parser.estimate("tasty turbo 1 carne").items.first?.foodName == "Tasty Turbo 1 carne (McDonald's)")
        // "postas" só é medida com comida junto.
        #expect(grams("2 postas de peixe") == 240)
    }
}
