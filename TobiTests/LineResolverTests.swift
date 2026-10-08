import Foundation
import Testing
@testable import Tobi

struct LineResolverTests {
    private func foods(_ count: Int = 3) -> [Food] {
        (0..<count).map { Food(brand: "Opção \($0)", aliases: ["opcao \($0)"], per100: Nutrition(kcal: 100),
                             barcode: String($0), portion: 100) }
    }

    private func response(_ json: String, status: Int = 200) -> LineResolver.Fetch {
        { request in
            (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    @Test func confirmedOptionComesFirstWithoutDuplicatesOrUnknownIDs() async throws {
        let candidates = foods()
        let result = try await LineResolver.suggestions(for: "comida", among: candidates, fetch: response(
            #"{"isFood":0.95,"match":"2","top":[{"id":"2","p":0.8},{"id":"0","p":0.2},{"id":"-1","p":0.5},{"id":"99","p":0.5},{"id":"01","p":0.5}]}"#))
        #expect(result.map(\.name) == ["Opção 2", "Opção 0"])
    }

    @Test func nonFoodAndInvalidProbabilitiesDoNotBecomeSuggestions() async throws {
        let nonFood = try await LineResolver.suggestions(for: "pagar conta", among: foods(), fetch: response(
            #"{"isFood":0.2,"match":"0","top":[{"id":"1","p":0.9}]}"#))
        #expect(nonFood.isEmpty)
        let unlikely = try await LineResolver.suggestions(for: "comida", among: foods(), fetch: response(
            #"{"isFood":0.9,"match":null,"top":[{"id":"0","p":0.14},{"id":"1","p":1.5},{"id":"2","p":-0.5}]}"#))
        #expect(unlikely.isEmpty)
    }

    @Test func serverCannotChooseAnOptionThatWasNotSent() async throws {
        let result = try await LineResolver.suggestions(for: "comida", among: foods(50), fetch: response(
            #"{"isFood":0.9,"match":"45","top":[{"id":"39","p":0.2},{"id":"40","p":0.3}]}"#))
        #expect(result.map(\.name) == ["Opção 39"])
    }

    @Test func requestsRespectServerLimitsEvenWithEmoji() async throws {
        _ = try await LineResolver.suggestions(for: String(repeating: "🍔", count: 300), among: foods(50)) { request in
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect((json["text"] as? String)?.utf16.count == 200)
            #expect((json["candidates"] as? [[String: String]])?.count == 40)
            return (Data(#"{"isFood":0,"match":null,"top":[]}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    @Test func emptyInputDoesNotCallTheService() async throws {
        let result = try await LineResolver.suggestions(for: "  ", among: foods()) { _ in
            Issue.record("Enviou um trecho vazio")
            throw URLError(.badURL)
        }
        #expect(result.isEmpty)
    }

    @Test func canceledRequestDoesNotAcceptALateResponse() async {
        let candidates = foods()
        let task = Task {
            try await LineResolver.suggestions(for: "comida", among: candidates) { request in
                withUnsafeCurrentTask { $0?.cancel() }
                return (Data(#"{"isFood":1,"match":"0","top":[]}"#.utf8),
                        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
        do {
            _ = try await task.value
            Issue.record("Aceitou resposta cancelada")
        } catch is CancellationError {
        } catch { Issue.record("Erro inesperado: \(error)") }
    }

    @Test func errorsKeepTheCallerInControlOfTheOriginalNote() async {
        do {
            _ = try await LineResolver.suggestions(for: "comida", among: foods(), fetch: response("{}", status: 503))
            Issue.record("Aceitou uma falha do serviço")
        } catch let error as URLError { #expect(error.code == .badServerResponse) }
        catch { Issue.record("Erro inesperado: \(error)") }
    }
}

struct FoodCorrectionTests {
    @Test func improvesOnlyTheFoodAndKeepsQuantitiesOtherFoodsAndTitle() async throws {
        let parser = await FoodParser.prepared()
        let food = try #require(parser.estimate("banana").items.first?.foodName)
        let candidate = try #require(parser.candidates(for: "banana").first { $0.name == food })
        let line = "Almoço: 2 bananazinhas, 100g de arroz e 1 copo de leite"
        #expect(FoodCorrection.replacing("bananazinhas", in: line, with: candidate, parser: parser)
                == "Almoço: 2 Banana, 100g de arroz e 1 copo de leite")
    }

    @Test func replacementUsesOriginalUnicodeRange() {
        let food = Food(brand: "Café", aliases: ["cafe"], per100: Nutrition(kcal: 5), barcode: "cafe", portion: 100)
        let parser = FoodParser(foods: []).adding([food])
        #expect(FoodCorrection.replacing("cafezinho", in: "🍞 200ml de CAFEZINHO e 2 ovos", with: food, parser: parser)
                == "🍞 200ml de Café e 2 ovos")
        #expect(FoodCorrection.replacing("cafe", in: "200ml de cafe\u{301}", with: food, parser: parser)
                == "200ml de Café")
    }

    @Test func missingAmbiguousAndPartialWordsAreNeverWholeLineReplacements() {
        let food = Food(brand: "Banana", aliases: ["banana"], per100: Nutrition(kcal: 90), barcode: "banana", portion: 100)
        let parser = FoodParser(foods: []).adding([food])
        for (piece, line) in [("", "2 bananas"), ("xis", "100g arroz"), ("banana", "2 bananadas"),
                              ("banana", "1 banana, 2 banana")] {
            #expect(FoodCorrection.replacing(piece, in: line, with: food, parser: parser) == nil)
        }
    }
}
