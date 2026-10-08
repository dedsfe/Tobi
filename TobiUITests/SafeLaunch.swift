import XCTest

extension XCUIApplication {
    /// Abre o app em modo de teste (banco em memória) e confere a marca antes de qualquer toque.
    /// Se outra sessão relançar o app normal no aparelho, o teste para aqui em vez de mexer nos
    /// dados de verdade de quem usa o iPhone.
    static func launchedForTesting(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let mark = app.descendants(matching: .any)["uiTestingMode"]
        if !mark.waitForExistence(timeout: 5) {
            XCTFail("app não está em modo de teste; nada foi digitado", file: file, line: line)
            app.terminate()
        }
        return app
    }

    /// Antes de cada passo que escreve: o app ainda é o de teste?
    func assertStillTesting(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(descendants(matching: .any)["uiTestingMode"].exists,
                      "app saiu do modo de teste (relançado por fora?)", file: file, line: line)
    }
}
