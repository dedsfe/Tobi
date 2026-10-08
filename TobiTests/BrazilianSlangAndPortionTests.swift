import Testing
@testable import Tobi

@Suite("Testes de Expressões Brasileiras, Gírias e Porções")
struct BrazilianSlangAndPortionTests {
    let parser = FoodParser.shared

    // MARK: - Leite Ninho e Leite em Pó

    @Test("Variações de Leite Ninho e colheres brasileiras")
    func testLeiteNinhoVariations() {
        // "2 colheres de leite ninho" -> 2 * 16g = 32g
        let ninho2 = parser.estimate("2 colheres de leite ninho")
        #expect(ninho2.items.count == 1)
        #expect(ninho2.items.first?.foodName == "Leite em pó integral")
        #expect(ninho2.items.first?.grams == 32)
        #expect(ninho2.items.first?.isRecognized == true)
        #expect(ninho2.items.first?.confidence == .exact)
        #expect(Int(ninho2.total.kcal.rounded()) == 154)

        // "3 colheres de sopa de ninho" -> 3 * 16g = 48g (48 * 4.79 kcal = 229.92 kcal)
        let ninho3 = parser.estimate("3 colheres de sopa de ninho")
        #expect(ninho3.items.first?.foodName == "Leite em pó integral")
        #expect(ninho3.items.first?.grams == 48)
        #expect(ninho3.items.first?.confidence == .exact)
        #expect(Int(ninho3.total.kcal.rounded()) == 230)

        // "1 colher de sobremesa de ninho" -> 9g
        let ninhoSobremesa = parser.estimate("1 colher de sobremesa de ninho")
        #expect(ninhoSobremesa.items.first?.foodName == "Leite em pó integral")
        #expect(ninhoSobremesa.items.first?.grams == 9)

        // "1 colher de chá de leite ninho" -> 4.5g
        let ninhoCha = parser.estimate("1 colher de chá de leite ninho")
        #expect(ninhoCha.items.first?.foodName == "Leite em pó integral")
        #expect(ninhoCha.items.first?.grams == 4.5)

        // "2 colheres de leite ninho desnatado" -> 2 * 10g = 20g
        let ninhoDesn = parser.estimate("2 colheres de leite ninho desnatado")
        #expect(ninhoDesn.items.first?.foodName == "Leite em pó desnatado")
        #expect(ninhoDesn.items.first?.grams == 20)

        // Composto: "açaí com leite ninho"
        let acaiNinho = parser.estimate("açaí com leite ninho")
        #expect(acaiNinho.items.count == 2)
        #expect(acaiNinho.items[0].foodName == "Açaí")
        #expect(acaiNinho.items[1].foodName == "Leite em pó integral")
    }

    // MARK: - Meio / Metade e Frações

    @Test("Meio e frações em lanches e refeições")
    func testHalvesAndFractions() {
        // "meio big mac" -> 50g (1/2 da porção de 100g do Big Mac)
        let meioBigMac = parser.estimate("meio big mac")
        #expect(meioBigMac.items.count == 1)
        #expect(meioBigMac.items.first?.foodName?.contains("Big Mac") == true)
        #expect(meioBigMac.items.first?.grams == 50)
        #expect(meioBigMac.items.first?.confidence == .exact)
        #expect(Int(meioBigMac.total.kcal.rounded()) == 262)

        // "metade de um big mac" -> 50g
        let metadeBigMac = parser.estimate("metade de um big mac")
        #expect(metadeBigMac.items.first?.foodName?.contains("Big Mac") == true)
        #expect(metadeBigMac.items.first?.grams == 50)

        // "meio whopper" -> 162.5g (metade da porção oficial de 325g do Whopper BK)
        let meioWhopper = parser.estimate("meio whopper")
        #expect(meioWhopper.items.first?.foodName?.contains("Whopper") == true)
        #expect(meioWhopper.items.first?.grams == 162.5)

        // "meio podrão" -> 75g (porção 150g do hambúrguer / 2)
        let meioPodrao = parser.estimate("meio podrão")
        #expect(meioPodrao.items.first?.foodName == "Hambúrguer")
        #expect(meioPodrao.items.first?.grams == 100) // Hambúrguer porção é 200g -> metade 100g

        // "meio pão francês" -> 25g
        let meioPao = parser.estimate("meio pão francês")
        #expect(meioPao.items.first?.foodName == "Pão francês")
        #expect(meioPao.items.first?.grams == 25)

        // "meia maçã" -> 65g
        let meiaMaca = parser.estimate("meia maçã")
        #expect(meiaMaca.items.first?.foodName == "Maçã")
        #expect(meiaMaca.items.first?.grams == 65)

        // Frações numéricas de pizza
        #expect(parser.estimate("1/2 pizza").items.first?.grams == 110)
        #expect(parser.estimate("1/4 de pizza").items.first?.grams == 55)
        #expect(parser.estimate("3/4 de pizza").items.first?.grams == 165)
    }

    // MARK: - Frações ao Final ("e meio", "e meia") e Separação de Prato

    @Test("Expressões com 'e meio / e meia' e listas no prato")
    func testTrailingHalvesAndPlateSeparators() {
        // "1 pão e meio" -> 1.5 * 50g = 75g
        let paoEMeio = parser.estimate("1 pão e meio")
        #expect(paoEMeio.items.count == 1)
        #expect(paoEMeio.items.first?.foodName == "Pão francês")
        #expect(paoEMeio.items.first?.grams == 75)

        // "2 bananas e meia" -> 2.5 * 70g = 175g
        let bananaEMeia = parser.estimate("2 bananas e meia")
        #expect(bananaEMeia.items.count == 1)
        #expect(bananaEMeia.items.first?.foodName == "Banana")
        #expect(bananaEMeia.items.first?.grams == 175)

        // "uma colher e meia de açúcar" -> 1.5 * 12g = 18g
        let acucarEMeio = parser.estimate("uma colher e meia de açúcar")
        #expect(acucarEMeio.items.count == 1)
        #expect(acucarEMeio.items.first?.foodName == "Açúcar")
        #expect(acucarEMeio.items.first?.grams == 18)

        // "2 ovos e meio pão" -> Ovo (100g) + Pão (25g)
        let ovosEMeioPao = parser.estimate("2 ovos e meio pão")
        #expect(ovosEMeioPao.items.count == 2)
        #expect(ovosEMeioPao.items[0].foodName == "Ovo")
        #expect(ovosEMeioPao.items[0].grams == 100)
        #expect(ovosEMeioPao.items[1].foodName == "Pão francês")
        #expect(ovosEMeioPao.items[1].grams == 25)

        // "arroz, feijão e meio bife" -> Arroz + Feijão + Bife (60g)
        let pratoMeioBife = parser.estimate("arroz, feijão e meio bife")
        #expect(pratoMeioBife.items.count == 3)
        #expect(pratoMeioBife.items[0].foodName == "Arroz branco")
        #expect(pratoMeioBife.items[1].foodName == "Feijão")
        #expect(pratoMeioBife.items[2].foodName == "Bife")
        #expect(pratoMeioBife.items[2].grams == 60)
    }

    // MARK: - Gírias, Comidas Típicas e Suplementos

    @Test("Gírias brasileiras, bebidas e preparos típicos")
    func testBrazilianSlangAndDishes() {
        // "um podrão" -> Hambúrguer
        let podrao = parser.estimate("um podrão")
        #expect(podrao.items.first?.foodName == "Hambúrguer")
        #expect(podrao.items.first?.isRecognized == true)

        // "1 xícara de café" -> Café (não fica como medida solta nem parcial)
        let xicaraCafe = parser.estimate("1 xícara de café")
        #expect(xicaraCafe.items.first?.foodName == "Café")
        #expect(xicaraCafe.items.first?.grams == 50)
        #expect(xicaraCafe.items.first?.isRecognized == true)

        // Bebidas comuns brasileiras
        #expect(parser.estimate("1 chopp").items.first?.foodName == "Cerveja")
        #expect(parser.estimate("1 latão de cerveja").items.first?.grams == 473)
        #expect(parser.estimate("1 long neck de heineken").items.first?.grams == 355)
        #expect(parser.estimate("1 cafezinho").items.first?.foodName == "Café")

        // Suplementação na rotina brasileira
        let creatina = parser.estimate("5g de creatina")
        #expect(creatina.items.first?.foodName == "Creatina")
        #expect(creatina.items.first?.grams == 5)
        #expect(creatina.items.first?.confidence == .estimated)

        let creatinaScoop = parser.estimate("1 scoop de creatina")
        #expect(creatinaScoop.items.first?.foodName == "Creatina")
        #expect(creatinaScoop.items.first?.grams == 5)

        let whey = parser.estimate("1 dose de whey")
        #expect(whey.items.first?.foodName == "Whey")
        #expect(whey.items.first?.grams == 30)

        // Preparos clássicos
        let milanesa = parser.estimate("1 bife à milanesa")
        #expect(milanesa.items.first?.foodName == "Bife à milanesa")
        #expect(milanesa.items.first?.grams == 120)

        let acebolado = parser.estimate("bife acebolado")
        #expect(acebolado.items.first?.foodName == "Bife")
        #expect(acebolado.items.first?.grams == 120)

        let paoChapa = parser.estimate("pão na chapa com manteiga")
        #expect(paoChapa.items.first?.foodName?.contains("Pão") == true)
    }

    // MARK: - Medidas Caseiras Típicas Brasileiras

    @Test("Medidas caseiras da cozinha brasileira")
    func testBrazilianHouseholdMeasures() {
        // Concha de feijão
        let conchaFeijao = parser.estimate("2 conchas de feijão")
        #expect(conchaFeijao.items.first?.foodName == "Feijão")
        #expect(conchaFeijao.items.first?.grams == 280) // 2 * 140g

        // Colher de arroz (arroz tem medida própria de 25g por colher)
        let colherArroz = parser.estimate("4 colheres de arroz")
        #expect(colherArroz.items.first?.foodName == "Arroz branco")
        #expect(colherArroz.items.first?.grams == 100) // 4 * 25g

        // Pratos raso e fundo
        let pratoRaso = parser.estimate("1 prato raso de salada")
        #expect(pratoRaso.items.first?.grams == 140)

        let pratoFundo = parser.estimate("1 prato fundo de sopa")
        #expect(pratoFundo.items.first?.grams == 300)

        // Copo americano
        let copoAmericano = parser.estimate("1 copo americano de leite")
        #expect(copoAmericano.items.first?.grams == 150)

        // Fatia de pizza e de bolo
        let fatiaPizza = parser.estimate("2 fatias de pizza")
        #expect(fatiaPizza.items.first?.grams == 220)

        let pedacoBolo = parser.estimate("1 pedaço de bolo")
        #expect(pedacoBolo.items.first?.grams == 80)
    }

    // MARK: - Padoca e Café da Manhã Paulista / Brasileiro

    @Test("Padoca e café da manhã brasileiro")
    func testPadocaEBebidas() {
        // "pingado" -> Café com leite (IBGE 8501303-99), 240g
        let pingado = parser.estimate("pingado")
        #expect(pingado.items.first?.foodName == "Café com leite")
        #expect(pingado.items.first?.grams == 240)

        // "pingado com pão na chapa"
        let comboPadoca = parser.estimate("pingado com pão na chapa")
        #expect(comboPadoca.items.count == 2)
        #expect(comboPadoca.items[0].foodName == "Café com leite")
        #expect(comboPadoca.items[1].foodName?.contains("Pão") == true)

        // "vitamina de banana com aveia e leite"
        let vitamina = parser.estimate("vitamina de banana com aveia e leite")
        #expect(vitamina.items.count == 2)
        #expect(vitamina.items[0].isRecognized)
        #expect(vitamina.items[1].isRecognized)

        // "crepioca com frango desfiado"
        let crepioca = parser.estimate("crepioca com frango desfiado")
        #expect(crepioca.items.count == 2)
        #expect(crepioca.items[0].foodName == "Crepioca")
        #expect(crepioca.items[1].foodName == "Frango grelhado")
    }

    // MARK: - Boteco e Petiscos

    @Test("Boteco, salgados e bebidas em lata")
    func testBotecoESalgados() {
        // "coxinha e uma coca lata" -> lata como medida no fim da bebida
        let lancheLata = parser.estimate("coxinha e uma coca lata")
        #expect(lancheLata.items.count == 2)
        #expect(lancheLata.items[0].foodName == "Coxinha")
        #expect(lancheLata.items[1].foodName == "Refrigerante")
        #expect(lancheLata.items[1].grams == 350)
        #expect(!lancheLata.items[0].isPartial)
        #expect(!lancheLata.items[1].isPartial)

        // "calabresa acebolada"
        let calabresa = parser.estimate("calabresa acebolada")
        #expect(calabresa.items.first?.foodName == "Linguiça")
        #expect(calabresa.items.first?.isPartial == false)

        // "1 pastel de carne e 1 caldo de cana"
        let pastelCaldo = parser.estimate("1 pastel de carne e 1 caldo de cana")
        #expect(pastelCaldo.items.count == 2)
        #expect(pastelCaldo.items[0].foodName?.contains("Pastel") == true)
        #expect(pastelCaldo.items[1].foodName == "Caldo de cana")

        // "2 chopes e 1 pastel"
        let chopes = parser.estimate("2 chopes e 1 pastel")
        #expect(chopes.items[0].foodName == "Cerveja")
        #expect(chopes.items[0].grams == 700)
    }

    // MARK: - Fast Food e Adjetivos Populares ("completo")

    @Test("Fast food e adjetivo 'completo'")
    func testFastFoodEDelivery() {
        // "cachorro quente completo" -> 'completo' não fica como token estranho
        let dogao = parser.estimate("cachorro quente completo")
        #expect(dogao.items.first?.foodName == "Cachorro-quente")
        #expect(dogao.items.first?.isPartial == false)

        // "casquinha de baunilha"
        let casquinha = parser.estimate("casquinha de baunilha")
        #expect(casquinha.items.first?.foodName == "Casquinha de baunilha")
        #expect(casquinha.items.first?.grams == 100)

        // "batata frita média do mcdonalds"
        let fritasMc = parser.estimate("batata frita média do mcdonalds")
        #expect(fritasMc.items.first?.foodName == "Batata frita do McDonald's")
        #expect(fritasMc.items.first?.grams == 100)

        // "cheddar mcmelt"
        let cheddar = parser.estimate("cheddar mcmelt")
        #expect(cheddar.items.first?.foodName?.contains("Cheddar McMelt") == true)
    }

    // MARK: - Fitness e Maromba

    @Test("Alimentação fitness e suplementação")
    func testFitnessEMaromba() {
        // "omelete de 3 ovos" -> porção correta sem duplicar omelete + 3 ovos
        let omelete3 = parser.estimate("omelete de 3 ovos")
        #expect(omelete3.items.count == 1)
        #expect(omelete3.items.first?.foodName == "Omelete de 3 ovos")
        #expect(omelete3.items.first?.grams == 160)

        // "shake de whey com pasta de amendoim"
        let shake = parser.estimate("shake de whey com pasta de amendoim")
        #expect(shake.items.count == 2)
        #expect(shake.items[0].foodName == "Whey")
        #expect(shake.items[0].grams == 30)
        #expect(shake.items[1].foodName == "Amendoim")
        #expect(shake.items[1].grams == 20)

        // "patinho moído com arroz e brócolis"
        let patinho = parser.estimate("patinho moído com arroz e brócolis")
        #expect(patinho.items.count == 3)
        #expect(patinho.items[0].foodName == "Carne moída")
        #expect(patinho.items[1].foodName == "Arroz branco")
        #expect(patinho.items[2].foodName == "Legumes")

        // "barra de proteína" -> 'barra' como começo de nome, não medida de 25g
        let barra = parser.estimate("barra de proteína")
        #expect(barra.items.first?.foodName == "Barra de proteína")
        #expect(barra.items.first?.grams == 45)
    }

    // MARK: - Caso Real do Usuário (Screenshot)

    @Test("Frase do screenshot sem vírgula entre medida e fração")
    func testScreenshotCase() {
        // "Coca 2 copos 1 terço de lasanha, 5 colheres de arroz"
        let estimate = parser.estimate("Coca 2 copos 1 terço de lasanha, 5 colheres de arroz")
        #expect(estimate.items.count == 3)
        #expect(estimate.hasUnknown == false)

        // Item 1: Coca 2 copos -> 480ml/g
        #expect(estimate.items[0].foodName == "Refrigerante")
        #expect(estimate.items[0].grams == 480)
        #expect(!estimate.items[0].isPartial)

        // Item 2: 1 terço de lasanha -> 100g (1/3 de 300g)
        #expect(estimate.items[1].foodName == "Lasanha")
        #expect(estimate.items[1].grams == 100)
        #expect(!estimate.items[1].isPartial)

        // Item 3: 5 colheres de arroz -> 125g (5 * 25g)
        #expect(estimate.items[2].foodName == "Arroz branco")
        #expect(estimate.items[2].grams == 125)
        #expect(!estimate.items[2].isPartial)

        // Total exato: 163.2 + 160 + 160 = 483.2 kcal (e não 803 kcal com lasanha inteira)
        #expect(Int(estimate.total.kcal.rounded()) == 483)
    }
}
