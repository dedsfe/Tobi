import XCTest

/// Fluxo que crashava: escrever, dar enter, apagar linhas vazias e juntar linhas.
final class LineEditingUITests: XCTestCase {
    @MainActor
    func testDeletingLinesKeepsAppAliveAndKeyboardOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let first = app.textViews.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        first.typeText("arroz\n")
        app.typeText("feijão\n")
        app.typeText("\n")

        // Apaga as linhas vazias e junta "feijão" de volta em "arroz".
        let backspace = XCUIKeyboardKey.delete.rawValue
        for _ in 0..<12 {
            app.typeText(backspace)
        }
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.keyboards.firstMatch.exists, "teclado fechou no meio da edição")
        XCTAssertEqual(app.textViews.count, 1)
    }
}

/// Estilo Notas: o dia é um texto só, então dá pra selecionar tudo de uma vez e apagar.
final class NoteSelectionUITests: XCTestCase {
    @MainActor
    func testSelectAllAndDeleteClearsEveryLine() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let note = app.textViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("2 big mac\narroz\nfeijão")
        XCTAssertEqual(note.value as? String, "2 big mac\narroz\nfeijão")

        // Como no Notas: toca segurando, "Selecionar Tudo" no menu e apaga uma vez só.
        note.press(forDuration: 0.8)
        let selectAll = app.menuItems.matching(NSPredicate(format: "label IN %@", ["Selecionar Tudo", "Select All"])).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3), "menu sem Selecionar Tudo")
        selectAll.tap()
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual((note.value as? String) ?? "", "")
        XCTAssertEqual(app.state, .runningForeground)
    }
}

/// Os botões da barra de cima do teclado têm que responder no primeiro toque, sempre.
final class KeyboardBarUITests: XCTestCase {
    @MainActor
    func testBarButtonsAnswerTheFirstTap() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let note = app.textViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        for round in 1...3 {
            note.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "teclado não abriu (rodada \(round))")
            note.typeText("arroz")
            app.buttons["Nova linha"].tap()
            note.typeText("feijão")
            app.buttons["Fechar teclado"].tap()
            let closed = NSPredicate(format: "exists == false")
            expectation(for: closed, evaluatedWith: app.keyboards.firstMatch)
            waitForExpectations(timeout: 3)
        }
        // "Nova linha" funcionou nas três rodadas: o feijão sempre caiu numa linha própria.
        XCTAssertEqual((note.value as? String)?.components(separatedBy: "\nfeijão").count, 4)
    }
}
