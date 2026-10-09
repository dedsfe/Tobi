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

    @Test(arguments: [
        ("1 dose whey atlhetica", "Best Whey (Atlhetica Nutrition)", 35.0, 134),
        ("2 dosadores isofort vitafor", "Isofort (Vitafor)", 30.0, 108),
        ("1 dose whey soldiers", "Whey Protein Concentrado (Soldiers Nutrition)", 30.0, 112),
        ("1 dose whey nutrata", "Whey Grego (Nutrata)", 40.0, 153),
        ("1 barra bold", "Barra Cookies Black (Bold Snacks)", 60.0, 235),
        ("pasta de amendoim dr peanut", "Pasta de Amendoim Avelã (Dr. Peanut)", 15.0, 85),
        ("1 dose whey mais mu", "Whey Protein Concentrado (Mais Mu)", 35.0, 132),
        ("1 yopro", "Bebida Láctea 15g Chocolate (YoPRO)", 250.0, 173),
        ("1 piracanjuba whey", "Bebida Láctea 23g Cacau (Piracanjuba Whey)", 250.0, 174),
        ("2 dosadores nitrohard darkness", "Nitrohard (Darkness)", 40.0, 163),
        ("1 dose albumina naturovos", "Albumina Natural (Naturovos)", 28.0, 97),
        ("1 dose nutri whey", "Nutri Whey Protein (Integralmédica)", 120.0, 432),
        ("1 dose super gainers", "Super Gainers (Max Titanium)", 160.0, 604),
        ("1 wafer bold", "Wafer Chocolate ao Leite (Bold Snacks)", 40.0, 194),
        ("1 iogurte yopro", "Iogurte Morango (YoPRO)", 160.0, 85),
        ("1 dose vegan sport", "Vegan Sport (Integralmédica)", 45.0, 160),
        ("1 dose dextrose soldiers", "Dextrose (Soldiers Nutrition)", 40.0, 148),
        ("1 dose palatinose soldiers", "Isomaltulose (Soldiers Nutrition)", 15.0, 60),
        ("1 dose striker soldiers", "Striker Pré-treino (Soldiers Nutrition)", 15.0, 26),
        ("1 energy gel vitafor", "Endurance Energy Gel (Vitafor)", 30.0, 80),
        ("1 scoop caseina optimum", "Gold Standard 100% Casein (Optimum Nutrition)", 33.0, 110),
        ("1 scoop isolate hd black skull", "Isolate HD (Black Skull)", 30.0, 123),
        ("2 dosadores medium whey", "Medium Whey (Growth)", 30.0, 121),
        ("1 dose 3 whey growth", "3 Whey Protein (Growth)", 30.0, 118),
        ("2 dosadores whey hidrolisado growth", "Whey Protein Hidrolisado (Growth)", 30.0, 115),
        ("1 bebida growth", "Bebida Láctea UHT (Growth)", 250.0, 162),
        ("1 dose haze growth", "Haze Pré-treino (Growth)", 10.0, 27),
        ("1 dose albumina growth", "Albumina (Growth)", 30.0, 104),
        ("3 dosadores blend vegan growth", "Blend Vegan (Growth)", 30.0, 123),
        ("1 dose big mass growth", "Big Mass Pro (Growth)", 160.0, 591),
        ("1 dose maltodextrina growth", "Maltodextrina (Growth)", 50.0, 192),
        ("1 colher pasta de amendoim growth", "Pasta de Amendoim Integral (Growth)", 15.0, 89),
        ("1 pasta brigadeiro growth", "Pasta de Amendoim Brigadeiro (Growth)", 15.0, 88),
        ("1 barra growth", "Barra Protein Bar Banoffee (Growth)", 30.0, 115),
        ("1 dose rice protein growth", "Rice Protein (Growth)", 30.0, 120),
        ("1 dose soy protein growth", "Soy Protein (Growth)", 30.0, 116),
        ("1 dose pea protein growth", "Pea Protein (Growth)", 30.0, 131),
        ("1 barra crisp growth", "Barra Crisp Protein Bar (Growth)", 40.0, 150),
        ("1 barra essential", "Barra Radiance Joy Protein Bar (Essential Nutrition)", 50.0, 196),
        ("1 best whey bar", "Barra Best Whey Bar (Atlhetica Nutrition)", 30.0, 100),
        ("1 best whey bar 12g atlhetica", "Barra Best Whey Bar 12g (Atlhetica Nutrition)", 49.0, 190),
        ("1 scoop fresh whey dux", "Fresh Whey (Dux)", 31.0, 126),
        ("1 barra integralmedica", "Barra Protein Crisp Brownie (Integralmédica)", 45.0, 186),
    ])
    func catalogPortions(line: String, name: String, grams: Double, kcal: Int) {
        let result = item(line)
        #expect(result.name == name)
        #expect(result.grams == grams)
        #expect(result.kcal == kcal)
        #expect(parser.estimate(line).items.count == 1)
    }

    @Test(arguments: [
        ("2 barras bold", "Barra Cookies Black (Bold Snacks)", 120.0, 470),
        ("1 garrafinha yopro", "Bebida Láctea 15g Chocolate (YoPRO)", 250.0, 173),
        ("2 caixinhas piracanjuba whey", "Bebida Láctea 23g Cacau (Piracanjuba Whey)", 500.0, 348),
        ("1 pote de iogurte yopro", "Iogurte Morango (YoPRO)", 160.0, 85),
        ("1 sache energy gel vitafor", "Endurance Energy Gel (Vitafor)", 30.0, 80),
        ("2 bold 14g", "Barra 14g Doce de Leite (Bold Snacks)", 80.0, 302),
        ("1 yopro 25g", "Bebida Láctea 25g Chocolate (YoPRO)", 250.0, 185),
        ("1 dose 3 whey probiotica", "3 Whey Protein (Probiótica)", 32.0, 128),
        ("1 barra dr peanut", "Doctor Bar Cookies & Cream (Dr. Peanut)", 62.0, 263),
        ("1 atlhetica barra 12g", "Barra Best Whey Bar 12g (Atlhetica Nutrition)", 49.0, 190),
        ("1 colher de sopa dr peanut", "Pasta de Amendoim Avelã (Dr. Peanut)", 15.0, 85),
        ("100g yopro 25g", "Bebida Láctea 25g Chocolate (YoPRO)", 100.0, 74),
        ("3 whey probiotica", "3 Whey Protein (Probiótica)", 32.0, 128),
    ])
    func packagingAndProductNumbers(line: String, name: String, grams: Double, kcal: Int) {
        let result = item(line)
        #expect(result.name == name)
        #expect(result.grams == grams)
        #expect(result.kcal == kcal)
        #expect(parser.estimate(line).items.count == 1)
    }

    @Test func genericFoodsRemainGeneric() {
        for line in ["whey", "barra de proteina", "pasta de amendoim", "iogurte", "creatina"] {
            #expect(parser.estimate(line).items.first?.foodName?.contains("(") == false)
        }
    }

    @Test func liquidLabelIsScaledFrom100mlToTheWholeBottle() {
        let nutrition = parser.estimate("1 yopro").total
        #expect(nutrition.kcal == 172.5)
        #expect(nutrition.protein == 15)
        #expect(nutrition.carbs == 21)
        #expect(nutrition.fat == 2.75)
        #expect(nutrition.sugar == 18.25)
        #expect(nutrition.sodium == 230)
        #expect(nutrition.fiber == 1.5)
    }

    @Test func aliasesDoNotCollideWithExistingFoods() {
        let supplements = FoodTables.suplementos
        let existing = FoodDatabase.curated.flatMap(\.aliases)
            + (FoodTables.taco + FoodTables.ibge + FoodTables.fastfood).flatMap(\.aliases)
        let reserved = Set(existing.map { FoodParser.tokenize($0).joined(separator: " ") })
        var seen = Set<String>()
        for food in supplements {
            #expect(food.portion > 0 && food.kcal > 0)
            for alias in food.aliases {
                let tokens = FoodParser.tokenize(alias).joined(separator: " ")
                // Flexões da mesma grafia podem cair no mesmo token dentro de um produto.
                #expect(!reserved.contains(tokens), "\(food.id): \(alias)")
            }
            for tokens in Set(food.aliases.map { FoodParser.tokenize($0).joined(separator: " ") }) {
                #expect(seen.insert(tokens).inserted, "\(food.id): \(tokens)")
            }
        }
    }

    @Test func everyCatalogProductIsRecognizedWithItsPortion() {
        for food in FoodTables.suplementos {
            let estimate = parser.estimate(food.aliases[0])
            #expect(estimate.items.count == 1, "\(food.id)")
            #expect(estimate.items.first?.foodName == food.name, "\(food.id)")
            #expect(estimate.items.first?.grams == food.portion, "\(food.id)")
        }
    }
}
