import XCTest

/// Todo botão da tela de escrever tem que responder no primeiro toque, sempre, rápido.
/// Cada teste repete o toque algumas vezes e dá no máximo 2 segundos pra resposta aparecer.
final class WritingScreenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(note.waitForExistence(timeout: 5))
    }

    private var note: XCUIElement { app.textViews.firstMatch }
    private var keyboard: XCUIElement { app.keyboards.firstMatch }
    private var addButton: XCUIElement { app.buttons["Adicionar comida"] }

    private func waitGone(_ element: XCUIElement, _ message: String) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: 2)
        XCTAssertFalse(element.exists, message)
    }

    @MainActor
    func testAddFoodOpensTheKeyboardOnANewLine() {
        // Dia vazio: o convite "Adicionar comida" está na tela.
        XCTAssertTrue(addButton.waitForExistence(timeout: 2), "dia vazio sem o botão de adicionar")
        addButton.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2), "Adicionar comida não abriu o teclado")
        note.typeText("arroz")
        for round in 1...3 {
            app.buttons["Fechar teclado"].tap()
            waitGone(keyboard, "Fechar teclado não fechou (rodada \(round))")
            XCTAssertTrue(addButton.waitForExistence(timeout: 2))
            addButton.tap()
            XCTAssertTrue(keyboard.waitForExistence(timeout: 2), "+ não abriu o teclado (rodada \(round))")
            note.typeText("feijão \(round)")
        }
        XCTAssertEqual(note.value as? String, "arroz\nfeijão 1\nfeijão 2\nfeijão 3")
    }

    /// O microfone tem que responder todo toque: ou começa a ouvir, ou diz na tela por que não deu.
    /// Nunca pode ficar parado sem resposta.
    @MainActor
    func testMicAlwaysAnswersTheTap() throws {
        addButton.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2))
        let listening = app.buttons["Parar ditado"]
        let problem = app.descendants(matching: .any)["dictationProblem"]
        for round in 1...4 {
            app.buttons["Ditar"].tap()
            let answered = expectation(for: NSPredicate { _, _ in listening.exists || problem.exists }, evaluatedWith: nil)
            wait(for: [answered], timeout: 2)
            XCTAssertTrue(listening.exists || problem.exists, "toque no microfone sem resposta (rodada \(round))")
            if problem.exists {
                // A gravação de tela automática do teste no iOS 26 segura o áudio (561017449).
                // Fora do teste isso não acontece; o que importa aqui é a mensagem ter aparecido.
                if "\(problem.value ?? "")".contains("561017449") {
                    throw XCTSkip("áudio ocupado pela gravação de tela do teste; a mensagem apareceu")
                }
                XCTFail("ditado falhou: \(problem.label) [\(problem.value ?? "")]")
                return
            }
            listening.tap()
            XCTAssertTrue(app.buttons["Ditar"].waitForExistence(timeout: 2), "microfone não parou (rodada \(round))")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testScannerOpensAndClosesEveryTime() {
        addButton.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2))
        for round in 1...3 {
            app.buttons["Ler código de barras"].tap()
            XCTAssertTrue(app.buttons["Fechar"].waitForExistence(timeout: 3), "scanner não abriu (rodada \(round))")
            app.buttons["Fechar"].tap()
            waitGone(app.buttons["Fechar"], "scanner não fechou (rodada \(round))")
            if !keyboard.exists { note.tap() }
            XCTAssertTrue(keyboard.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testTotalsOpenAndCloseGoals() {
        addButton.tap()
        note.typeText("2 big mac")
        app.buttons["Fechar teclado"].tap()
        waitGone(keyboard, "teclado não fechou")
        let totals = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'Ver metas'")).firstMatch
        XCTAssertTrue(totals.waitForExistence(timeout: 2), "barra de total sumiu")
        for round in 1...3 {
            totals.tap()
            XCTAssertTrue(app.descendants(matching: .any)["goalsCard"].waitForExistence(timeout: 2), "metas não abriram (rodada \(round))")
            totals.tap()
            waitGone(app.descendants(matching: .any)["goalsCard"], "metas não fecharam (rodada \(round))")
        }
    }

    @MainActor
    func testSettingsAndCalendarOpen() {
        for _ in 1...2 {
            app.buttons["Ajustes"].tap()
            XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 2), "Ajustes não abriu")
            app.buttons["OK"].firstMatch.tap()
            waitGone(app.navigationBars["Ajustes"], "Ajustes não fechou")

            app.buttons["Hoje"].tap()
            XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 2), "calendário não abriu")
            app.swipeDown(velocity: .fast)
            waitGone(app.datePickers.firstMatch, "calendário não fechou")
        }
    }
}
