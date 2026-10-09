import XCTest

/// Tira os prints da página da App Store no iPhone, com um dia de exemplo no banco em memória.
/// Rodar só este arquivo: `-only-testing:TobiUITests/AppStoreScreenshots`. Os prints saem como
/// anexos no .xcresult (`xcrun xcresulttool export attachments`).
@MainActor
final class AppStoreScreenshots: XCTestCase {
    /// Um dia de quem treina, do jeito que se escreve no Tobi.
    private static let day = [
        "Café da manhã",
        "2 ovos mexidos",
        "1 pão francês na chapa",
        "Café com leite",
        "Almoço",
        "Arroz, feijão e bife",
        "Salada de alface e tomate",
        "Pós treino",
        "2 scoops de whey growth",
        "1 banana",
        "Jantar",
        "150g de frango grelhado",
        "100g de batata doce",
    ]

    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    func testDayGoalsAndWidgets() {
        let app = XCUIApplication.launchedForTesting()
        let note = app.textViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let add = app.buttons["Adicionar comida"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        app.assertStillTesting()
        note.typeText(Self.day.joined(separator: "\n"))
        pause(2.5)
        shot("02-escrevendo")

        app.buttons["Fechar teclado"].tap()
        pause(2)
        shot("01-dia")

        app.buttons.matching(NSPredicate(format: "label ENDSWITH 'Ver metas'")).firstMatch.tap()
        pause(2.5)
        shot("03-metas")

        // Os widgets da tela de início já mostram este dia.
        XCUIDevice.shared.press(.home)
        pause(3)
        shot("04-widgets")
    }

    func testOnboardingScreens() {
        for step in ["welcome", "goals", "celebration", "paywall"] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-onboardingShot", step]
            app.launch()
            // Deixa o Tobi 3D carregar e as animações de entrada terminarem.
            pause(step == "celebration" ? 6 : 4)
            shot("onboarding-\(step)")
            app.terminate()
        }
    }
}
