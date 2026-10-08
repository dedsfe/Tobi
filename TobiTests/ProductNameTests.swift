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
