import Foundation
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

    // MARK: - IA conferindo a busca por nome

    private let arrozPratoFino = Food(
        brand: "Prato Fino white rice", aliases: ["Prato Fino white rice"],
        per100: Nutrition(kcal: 350), barcode: "7896079500018", portion: 100
    )

    private func answer(_ json: String) -> LineResolver.Fetch {
        { request in
            (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    @Test func nameSearchOnlySavesWhatTheAIConfirmed() async throws {
        let names = ["Queijo prato", "Prato Fino white rice"]
        // Escolheu e conferiu.
        #expect(try await LineResolver.confirmed("queijo prato", among: names, fetch: answer(
            #"{"isFood":0.9,"match":"0","top":[{"id":"0","p":0.9}]}"#)) == 0)
        // "prato" sozinho: é comida, mas nenhum produto é o que a pessoa escreveu.
        #expect(try await LineResolver.confirmed("prato", among: names, fetch: answer(
            #"{"isFood":0.85,"match":null,"top":[{"id":"1","p":0.7}]}"#)) == nil)
        // Não é comida, mesmo que o servidor aponte um.
        #expect(try await LineResolver.confirmed("mesa", among: names, fetch: answer(
            #"{"isFood":0.05,"match":"0","top":[]}"#)) == nil)
        // Índice que não foi mandado.
        #expect(try await LineResolver.confirmed("queijo", among: names, fetch: answer(
            #"{"isFood":0.9,"match":"7","top":[]}"#)) == nil)
    }

    @Test func cleanupRemovesProductsTheAIDoesNotConfirm() async throws {
        let parser = FoodParser.shared.adding([arrozPratoFino, toddynho])
        let products = [(barcode: "7896079500018", name: arrozPratoFino.name),
                        (barcode: "7894321242521", name: toddynho.name),
                        (barcode: "123", name: "Biscoito que ninguém escreveu")]
        let rejected = try await BrandCleanup.rejected(
            products: products, notes: ["Almoço\nprato, 1 toddynho", "toddynho"], parser: parser
        ) { piece, name in
            !(piece.contains("prato") && name.contains("Prato Fino"))
        }
        #expect(rejected == ["7896079500018", "123"])
    }
}
