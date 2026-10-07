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
