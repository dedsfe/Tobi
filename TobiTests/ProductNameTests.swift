import Testing
@testable import Tobi

/// Nomes de verdade do Open Food Facts (consultados em 07/10/2026).
struct ProductNameTests {
    @Test func dropsPackageSizesThatWouldReadAsQuantity() {
        #expect(ProductName.clean("Refrigerante Coca-Cola 2Lt", brands: ["Coca-Cola"]) == "Refrigerante Coca-Cola")
        #expect(ProductName.clean("Biscoito Original Batman Oreo Pacote 90g", brands: ["Oreo"])
                == "Biscoito Original Batman Oreo")
        #expect(ProductName.clean("Bebida Láctea Uht Chocolate Toddynho Levinho Caixa 200ml", brands: ["Toddynho Levinho"])
                == "Bebida Láctea Chocolate Toddynho Levinho")
    }

    @Test func putsTheBrandFirstWhenTheNameDoesNotSayIt() {
        #expect(ProductName.clean("2.0", brands: ["Nestlé", "Nescau"]) == "Nescau 2.0")
        #expect(ProductName.clean("Tradicional", brands: ["3 Corações"]) == "3 Corações Tradicional")
        #expect(ProductName.clean("União Refinado", brands: ["Tio João", "União"]) == "União Refinado")
    }

    @Test func scannedProductWinsOverTheGenericFood() {
        let coca = Food(brand: "Refrigerante Coca-Cola", aliases: ["Refrigerante Coca-Cola", "Coca-Cola Refrigerante Coca-Cola"],
                        per100: Nutrition(kcal: 42.5), barcode: "7894900011517", portion: 200)
        let parser = FoodParser.shared.adding([coca])
        let item = parser.estimate("Refrigerante Coca-Cola").items.first
        #expect(item?.foodName == "Refrigerante Coca-Cola")
        #expect(item?.grams == 200)
        #expect(item?.confidence == .exact)
    }
}

struct BrandMeasureTests {
    @Test func scannedProductUsesHouseholdMeasuresOfTheGenericFood() {
        let generic = FoodParser.shared.householdMeasures(for: "Leite Condensado Integral moça")
        let colher = try? #require(generic["colher de sopa"])
        let moca = Food(brand: "Leite Condensado Integral moça", aliases: ["Leite Condensado Integral moça"],
                        per100: Nutrition(kcal: 325), barcode: "7891000100103", portion: 20, measures: generic)
        let parser = FoodParser.shared.adding([moca])
        let item = parser.estimate("Leite Condensado Integral moça, 2 colheres de sopa").items.first
        #expect(item?.foodName == "Leite Condensado Integral moça")
        #expect(item?.grams == colher.map { $0 * 2 })
        #expect(item?.confidence == .exact)
    }

    /// O cartão do scanner escreve a linha assim; o parser tem que ler a mesma quantidade de volta.
    @Test func linesWrittenByTheScanCardReadBack() {
        let measures = FoodParser.shared.householdMeasures(for: "Leite Condensado Integral moça")
        let colher = measures["colher de sopa"] ?? 0
        let moca = Food(brand: "Leite Condensado Integral moça", aliases: ["Leite Condensado Integral moça"],
                        per100: Nutrition(kcal: 325), barcode: "7891000100103", portion: 20, measures: measures)
        let parser = FoodParser.shared.adding([moca])
        func grams(_ line: String) -> Double? { parser.estimate(line).items.first?.grams }
        #expect(grams("1,5 colheres de sopa de Leite Condensado Integral moça") == 1.5 * colher)
        #expect(grams("meia colher de sopa de Leite Condensado Integral moça") == 0.5 * colher)
        #expect(grams("meia porção de Leite Condensado Integral moça") == 10)
        #expect(grams("2 porções de Leite Condensado Integral moça") == 40)
        #expect(grams("395 g de Leite Condensado Integral moça") == 395)
    }
}
