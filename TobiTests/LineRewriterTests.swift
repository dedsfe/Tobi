import Testing
@testable import Tobi

struct LineRewriterTests {
    @Test func dropsFillerAndKeepsFood() {
        let line = "hoje no almoço eu comi um prato de arroz com feijão e duas coxas de frango e uma coca"
        #expect(LineRewriter.compact(line) == "1 prato de arroz com feijão, 2 coxas de frango, 1 coca")
    }

    @Test func keepsWhatItDoesNotUnderstand() {
        #expect(LineRewriter.compact("marmita da firma") == "marmita da firma")
        #expect(LineRewriter.compact("aquele bolo da vó com café") == "aquele bolo da vó, café")
    }

    @Test func keepsDishesTogether() {
        #expect(LineRewriter.compact("pão com manteiga e café com leite") == "pão com manteiga, café com leite")
    }

    @Test func keepsTitle() {
        #expect(LineRewriter.compact("Almoço: arroz e feijão") == "Almoço: arroz, feijão")
        #expect(LineRewriter.compact("Almoço") == "Almoço")
    }

    @Test func neverEmptiesALine() {
        #expect(LineRewriter.compact("hoje eu comi") == "hoje eu comi")
    }

    @Test func doesNotTouchFoodNames() {
        #expect(LineRewriter.compact("café da manhã: pão na chapa") == "café da manhã: pão na chapa")
        #expect(LineRewriter.compact("batata doce") == "batata doce")
    }

    /// A linha enxuta reconhece exatamente as mesmas comidas da original (nada some).
    @Test(arguments: [
        "hoje no almoço eu comi um prato de arroz com feijão e duas coxas de frango e uma coca",
        "de manhã tomei um café com leite e comi dois pães franceses com manteiga",
        "à noite eu comi tipo duas fatias de pizza e uma cerveja",
        "acabei de comer 200g de frango com batata doce",
        "Jantar: omelete de 3 ovos + salada",
    ])
    func keepsEveryFood(line: String) {
        let parser = FoodParser.shared
        let foods = { (text: String) in parser.estimate(text).items.map(\.foodName) }
        #expect(foods(LineRewriter.compact(line)) == foods(line))
    }
}
