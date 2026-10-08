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

/// Do jeito que se fala na cozinha: pitada, fio, gota, um pouco, meio quilo, um terço.
struct KitchenTalkTests {
    let parser = FoodParser.shared

    private func item(_ line: String) -> ItemEstimate? { parser.estimate(line).items.first }

    @Test func pinchesDropsAndDrizzles() {
        #expect(item("uma pitada de sal")?.foodName == "Sal")
        #expect(item("uma pitada de sal")?.grams == 0.5)
        #expect(item("uma pitada de sal")?.confidence == .estimated)
        #expect(item("pitada de canela")?.foodName == "Canela")
        #expect(item("um fio de azeite")?.foodName == "Azeite de oliva")
        #expect(item("um fio de azeite")?.grams == 8)
        #expect(item("3 gotas de adoçante")?.foodName == "Adoçante")
        #expect(item("1 colher de chá de pimenta do reino")?.grams == 1.5)
        #expect(item("azeite")?.foodName == "Azeite de oliva")
    }

    @Test func wordsForWeightAndFractions() {
        #expect(item("meio quilo de carne moída")?.grams == 500)
        #expect(item("meio quilo de carne moída")?.confidence == .exact)
        #expect(item("duzentos gramas de arroz")?.grams == 200)
        #expect(item("meio litro de leite")?.grams == 500)
        #expect(item("um terço de pizza")?.grams == (item("1 pizza")?.grams).map { $0 / 3 })
        #expect(item("um par de ovos")?.grams == item("2 ovos")?.grams)
    }

    @Test func vagueAmountsAreEstimates() {
        let some = item("um pouco de arroz")
        #expect(some?.foodName == "Arroz branco")
        #expect(some?.grams == (item("arroz")?.grams).map { $0 / 2 })
        #expect(some?.confidence == .estimated)
        #expect(item("bastante feijão")?.grams == (item("feijão")?.grams).map { $0 * 1.5 })
    }

    @Test func drinksBySize() {
        #expect(item("1 long neck de cerveja")?.grams == 355)
        #expect(item("um latão de cerveja")?.grams == 473)
        #expect(item("dois dedos de whisky")?.isRecognized != nil)
    }
}

/// Toda unidade de peso e volume que o brasileiro escreve, abreviada, por extenso ou gringa.
struct UnitTests {
    let parser = FoodParser.shared
    func grams(_ line: String) -> Double? { parser.estimate(line).items.first?.grams }

    @Test func weightUnits() {
        #expect(grams("500mg de sal") == 0.5)
        #expect(grams("1 mg de sal") == 0.001)
        #expect(grams("2 miligramas de sal") == 0.002)
        #expect(grams("200 gr de melancia") == 200)
        #expect(grams("200grs de melancia") == 200)
        #expect(grams("2 kilos de melancia") == 2000)
        #expect(grams("1 quilograma de melancia") == 1000)
        #expect(grams("1 kg de melancia") == 1000)
        #expect(grams("1.000 g de melancia") == 1000)
        #expect(grams("1,5 kg de melancia") == 1500)
        #expect(grams("melancia 300 gramas") == 300)
    }

    @Test func volumeUnits() {
        #expect(grams("350ml de leite") == 350)
        #expect(grams("2 lts de leite") == 2000)
        #expect(grams("1 lt de leite") == 1000)
        #expect(grams("1,5 l de leite") == 1500)
        #expect(grams("1 dl de leite") == 100)
        #expect(grams("5 cl de leite") == 50)
        #expect(grams("250 cc de leite") == 250)
        #expect(grams("2 mililitros de leite") == 2)
    }

    @Test func spelledOutNumbersWithAbbreviations() {
        #expect(grams("duzentos ml de leite") == 200)
        #expect(grams("trezentos g de melancia") == 300)
        #expect(grams("meio kg de melancia") == 500)
        #expect(grams("meio litro de leite") == 500)
        #expect(grams("um litro e meio de leite") == 1500)
    }

    @Test func importedUnits() {
        #expect(grams("8 oz de leite") == 8 * 28.35)
        #expect(grams("1 lb de melancia") == 453.6)
    }

    @Test func marketSizes() {
        #expect(grams("1 litrão de cerveja") == 1000)
        #expect(grams("1 litrinho de cerveja") == 300)
    }

    @Test func unusualKitchenMeasuresAreRough() {
        let tulipa = parser.estimate("uma tulipa de feijoada").items.first
        #expect(tulipa?.foodName == "Feijoada")
        #expect(tulipa?.grams == 300)
        #expect(tulipa?.confidence == .estimated)
        // "Marmita" e "tirinha" são nome de comida (prato feito, tirinha do KFC), não medida.
        #expect(parser.estimate("marmita").items.first?.foodName == "Prato feito")
        #expect(parser.estimate("1 dente de alho").items.first?.foodName?.localizedCaseInsensitiveContains("alho") == true)
        #expect(parser.estimate("uma mão cheia de amendoim").items.first?.foodName?.localizedCaseInsensitiveContains("amendoim") == true)
    }

    @Test func absoluteUnitsAreExact() {
        #expect(parser.estimate("200 gr de melancia").items.first?.confidence == .exact)
        #expect(parser.estimate("trezentos g de melancia").items.first?.confidence == .exact)
    }

    @Test func wordsThatLookLikeUnitsStayFood() {
        #expect(grams("2 lanches") != 2000)
        #expect(grams("3 goiabas") != 3)
        #expect(grams("2 ovos") == 100)
    }
}

/// Produto salvo escrito do jeito da pessoa, não do jeito do rótulo.
struct SavedProductAnyOrderTests {
    let paprica = Food(brand: "Páprica Picante Essencial Br Spices",
                       aliases: ["Páprica Picante Essencial Br Spices", "Br Spices Páprica Picante Essencial"],
                       per100: Nutrition(kcal: 280), barcode: "1", portion: 5)

    @Test func wordsInAnyOrder() {
        let parser = FoodParser.shared.adding([paprica])
        let item = parser.estimate("1 mg de páprica picante br spice").items.first
        #expect(item?.foodName == paprica.name)
        #expect(item?.grams == 0.001)
        #expect(parser.estimate("br spices páprica").items.first?.foodName == paprica.name)
        #expect(parser.estimate("2 colheres de chá de páprica br spices").items.first?.foodName == paprica.name)
    }

    @Test func genericNameStaysGeneric() {
        let parser = FoodParser.shared.adding([paprica])
        #expect(parser.estimate("páprica picante").items.first?.foodName == "Páprica")
    }

    @Test func wordOutsideTheProductDoesNotPickIt() {
        let parser = FoodParser.shared.adding([paprica])
        #expect(parser.estimate("páprica picante da kitano").items.first?.foodName != paprica.name)
    }
}

/// Ajuda da linha "?": trecho sublinhado, porquê e sugestões que voltam a ser o alimento.
struct UnknownHelpTests {
    let parser = FoodParser.shared

    @Test func foodTextLeavesTheQuantityOut() {
        #expect(parser.foodText(in: "2 colheres de xis salada") == "xis salada")
        #expect(parser.foodText(in: "xablau 200g") == "xablau")
    }

    @Test func typoBecomesTheFirstSuggestion() {
        let help = parser.help(for: "picanah")
        #expect(help.typoFix?.name.localizedCaseInsensitiveContains("picanha") == true)
        #expect(help.suggestions.first?.name == help.typoFix?.name)
    }

    @Test func everySuggestionReadsBackAsItself() {
        for piece in ["pao na chapa", "suco de cupuacu", "picanah", "frango xadrez"] {
            for food in parser.help(for: piece).suggestions {
                if let name = parser.writtenName(for: food) {
                    #expect(parser.estimate(name).items.first?.foodName == food.name)
                }
            }
        }
    }

    @Test func candidatesSkipChainsUnlessNamed() {
        #expect(!parser.candidates(for: "pao na chapa").contains { $0.name.contains("McDonald") })
        #expect(parser.candidates(for: "pao na chapa do mc").contains { $0.name.contains("McDonald") })
    }

    @Test func nonsenseHasNoTypoAndSaysWhy() {
        let help = parser.help(for: "xablau")
        #expect(help.typoFix == nil)
        #expect(help.unknownWords == ["xablau"])
        #expect(!help.reasons.isEmpty)
    }
}
