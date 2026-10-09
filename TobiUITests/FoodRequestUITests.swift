import XCTest

final class FoodRequestUITests: XCTestCase {
    @MainActor
    func testRequestStaysReachableWithKeyboardOpen() {
        continueAfterFailure = false
        let app = XCUIApplication.launchedForTesting()
        let note = app.textViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText(String(repeating: "arroz\n", count: 8) + "Produto Zorbax Tobi")
        let unknownMark = note.staticTexts["?"].firstMatch
        XCTAssertTrue(unknownMark.waitForExistence(timeout: 5))
        // O editor rola para manter o cursor visível. A marca acompanha a linha real na tela.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 65, dy: unknownMark.frame.midY)).tap()
        let request = app.buttons["request-food"]
        XCTAssertTrue(request.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(request.isHittable)
        XCTAssertLessThanOrEqual(request.frame.maxY, app.keyboards.firstMatch.frame.minY)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "pedido-com-teclado"
        shot.lifetime = .keepAlways
        add(shot)
        request.tap()
        XCTAssertTrue(app.staticTexts["food-request-status"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.descendants(matching: .any)["suggestionBubble"])
        wait(for: [gone], timeout: 5)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
    }

    @MainActor
    func testRequestFromRedFoodSendsWithoutChangingNote() {
        continueAfterFailure = false
        let app = XCUIApplication.launchedForTesting()
        let note = app.textViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        let text = "200 g Produto Zorbax Tobi"
        note.typeText(text)
        app.buttons["Fechar teclado"].tap()
        // Toque real sobre a primeira linha vermelha, com a mesma margem do editor.
        note.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 120, dy: 28)).tap()
        let request = app.buttons["request-food"]
        XCTAssertTrue(request.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(request.isHittable)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "pedido-antes"
        before.lifetime = .keepAlways
        add(before)
        request.tap()
        let status = app.staticTexts["food-request-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertEqual(status.label, "Pedido enviado")
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "pedido-enviado"
        after.lifetime = .keepAlways
        add(after)
        XCTAssertFalse(app.staticTexts["Vamos pesquisar este produto."].exists)
        XCTAssertEqual(note.value as? String, text)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.descendants(matching: .any)["suggestionBubble"])
        wait(for: [gone], timeout: 5)

        // O mesmo nome pode ser enviado de novo, sem precisar mudar a nota nem esperar um prazo.
        for _ in 0..<2 {
            note.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 120, dy: 28)).tap()
            XCTAssertTrue(app.buttons["request-food"].waitForExistence(timeout: 5))
            app.buttons["request-food"].tap()
            XCTAssertTrue(status.waitForExistence(timeout: 20))
            XCTAssertEqual(status.label, "Pedido enviado")
            let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.descendants(matching: .any)["suggestionBubble"])
            wait(for: [dismissed], timeout: 5)
        }
        XCTAssertEqual(note.value as? String, text)
    }
}
