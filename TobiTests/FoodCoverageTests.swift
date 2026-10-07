import Foundation
import Testing
@testable import Tobi

// Faixas = kcal da fonte indicada × gramas / 100, com 1% (mínimo 1 kcal) de
// tolerância de arredondamento. Não são valores inventados nem saídas do parser.
// Estimativas genéricas usam SOMENTE números que já existiam em FoodDatabase.curated.
// Casos sem fonte permanecem unknown/0 e são listados no relatório da issue.
@Suite(.serialized)
struct FoodCoverageTests {
    struct Expected: Sendable {
        let name: String?
        let grams: Double
        let kcal: ClosedRange<Double>
        let confidence: Confidence
        let source: String
    }
    struct Sample: Sendable, CustomStringConvertible {
        let group: String
        let phrase: String
        let expected: [Expected]
        var description: String { "\(group): \(phrase)" }
    }
    static let samples: [Sample] = [
        Sample(group: "brasileira", phrase: "arroz", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
        ]),
        Sample(group: "brasileira", phrase: "feijão", expected: [
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
        ]),
        Sample(group: "brasileira", phrase: "bife", expected: [
            Expected(name: "Bife", grams: 120, kcal: 230.4720...235.1280, confidence: .estimated, source: "taco:346"),
        ]),
        Sample(group: "brasileira", phrase: "frango", expected: [
            Expected(name: "Frango grelhado", grams: 120, kcal: 188.8920...192.7080, confidence: .estimated, source: "taco:410"),
        ]),
        Sample(group: "brasileira", phrase: "2 ovos", expected: [
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .exact, source: "taco:488"),
        ]),
        Sample(group: "brasileira", phrase: "pão francês com manteiga", expected: [
            Expected(name: "Pão com manteiga", grams: 60, kcal: 219.4830...223.9170, confidence: .estimated, source: "ibge:8570328-99"),
        ]),
        Sample(group: "brasileira", phrase: "café com leite", expected: [
            Expected(name: "Café com leite", grams: 240, kcal: 74.4560...76.4560, confidence: .estimated, source: "ibge:8501303-99"),
        ]),
        Sample(group: "brasileira", phrase: "tapioca", expected: [
            Expected(name: "Tapioca", grams: 70, kcal: 166.3200...169.6800, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "brasileira", phrase: "cuscuz", expected: [
            Expected(name: "Cuscuz", grams: 150, kcal: 167.8050...171.1950, confidence: .estimated, source: "taco:533"),
        ]),
        Sample(group: "brasileira", phrase: "farofa", expected: [
            Expected(name: "Farofa", grams: 30, kcal: 120.5820...123.0180, confidence: .estimated, source: "taco:131"),
        ]),
        Sample(group: "brasileira", phrase: "feijoada", expected: [
            Expected(name: "Feijoada", grams: 250, kcal: 289.5750...295.4250, confidence: .estimated, source: "taco:540"),
        ]),
        Sample(group: "brasileira", phrase: "strogonoff", expected: [
            Expected(name: "Strogonoff", grams: 200, kcal: 310.8600...317.1400, confidence: .estimated, source: "taco:538"),
        ]),
        Sample(group: "brasileira", phrase: "PF", expected: [
            Expected(name: "Prato feito", grams: 600, kcal: 831.6000...848.4000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "brasileira", phrase: "marmita", expected: [
            Expected(name: "Prato feito", grams: 600, kcal: 831.6000...848.4000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "brasileira", phrase: "açaí", expected: [
            Expected(name: "Açaí", grams: 300, kcal: 326.7000...333.3000, confidence: .estimated, source: "taco:167"),
        ]),
        Sample(group: "brasileira", phrase: "pão de queijo", expected: [
            Expected(name: "Pão de queijo", grams: 40, kcal: 143.7480...146.6520, confidence: .estimated, source: "taco:140"),
        ]),
        Sample(group: "brasileira", phrase: "coxinha", expected: [
            Expected(name: "Coxinha", grams: 110, kcal: 308.1870...314.4130, confidence: .estimated, source: "taco:386"),
        ]),
        Sample(group: "brasileira", phrase: "pastel", expected: [
            Expected(name: "Pastel", grams: 100, kcal: 384.1200...391.8800, confidence: .estimated, source: "taco:56"),
        ]),
        Sample(group: "brasileira", phrase: "misto quente", expected: [
            Expected(name: "Sanduíche", grams: 150, kcal: 371.2500...378.7500, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "brasileira", phrase: "vitamina de banana", expected: [
            Expected(name: "Vitamina de banana", grams: 240, kcal: 220.4453...224.8987, confidence: .estimated, source: "ibge:8500503-99"),
        ]),
        Sample(group: "brasileira", phrase: "arroz, feijão e bife", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
            Expected(name: "Bife", grams: 120, kcal: 230.4720...235.1280, confidence: .estimated, source: "taco:346"),
        ]),
        Sample(group: "brasileira", phrase: "100g de strogonoff de carne", expected: [
            Expected(name: "Strogonoff de carne", grams: 100, kcal: 171.2700...174.7300, confidence: .exact, source: "taco:537"),
        ]),
        Sample(group: "regional", phrase: "baião de dois", expected: [
            Expected(name: "Baião de dois", grams: 200, kcal: 269.2800...274.7200, confidence: .estimated, source: "taco:527"),
        ]),
        Sample(group: "regional", phrase: "moqueca baiana", expected: [
            Expected(name: "Moqueca baiana", grams: 141, kcal: 181.6485...185.3181, confidence: .estimated, source: "ibge:8506401-99"),
        ]),
        Sample(group: "regional", phrase: "moqueca capixaba", expected: [
            Expected(name: "Moqueca capixaba", grams: 141, kcal: 140.3159...143.1505, confidence: .estimated, source: "ibge:8507101-99"),
        ]),
        Sample(group: "regional", phrase: "moqueca", expected: [
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "regional", phrase: "acarajé", expected: [
            Expected(name: "Acarajé", grams: 100, kcal: 286.1100...291.8900, confidence: .estimated, source: "ibge:8500209-99"),
        ]),
        Sample(group: "regional", phrase: "vatapá", expected: [
            Expected(name: "Vatapá", grams: 25, kcal: 55.5175...57.5175, confidence: .estimated, source: "ibge:8502801-99"),
        ]),
        Sample(group: "regional", phrase: "tacacá", expected: [
            Expected(name: "Tacacá", grams: 300, kcal: 47.0000...49.0000, confidence: .estimated, source: "ibge:8502401-99"),
        ]),
        Sample(group: "regional", phrase: "arrumadinho", expected: [
            Expected(name: "Arrumadinho", grams: 35, kcal: 68.6010...70.6010, confidence: .estimated, source: "ibge:8505501-99"),
        ]),
        Sample(group: "regional", phrase: "galinhada", expected: [
            Expected(name: "Galinhada", grams: 60, kcal: 85.1000...87.1000, confidence: .estimated, source: "ibge:8506301-99"),
        ]),
        Sample(group: "regional", phrase: "virado à paulista", expected: [
            Expected(name: "Virado à paulista", grams: 200, kcal: 607.8600...620.1400, confidence: .estimated, source: "taco:555"),
        ]),
        Sample(group: "regional", phrase: "arroz carreteiro", expected: [
            Expected(name: "Arroz carreteiro", grams: 60, kcal: 91.4000...93.4000, confidence: .estimated, source: "ibge:8579002-99"),
        ]),
        Sample(group: "regional", phrase: "pamonha", expected: [
            Expected(name: "Pamonha", grams: 160, kcal: 270.8640...276.3360, confidence: .estimated, source: "ibge:6905101-99"),
        ]),
        Sample(group: "regional", phrase: "escondidinho", expected: [
            Expected(name: "Escondidinho", grams: 300, kcal: 445.5000...454.5000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "regional", phrase: "buchada de bode", expected: [
            Expected(name: "Buchada de bode", grams: 100, kcal: 123.7500...126.2500, confidence: .estimated, source: "ibge:7107204-99"),
        ]),
        Sample(group: "regional", phrase: "buchada", expected: [
            Expected(name: "Buchada de bode", grams: 100, kcal: 123.7500...126.2500, confidence: .estimated, source: "ibge:7107204-99"),
        ]),
        Sample(group: "regional", phrase: "chimarrão", expected: [
            Expected(name: "Chimarrão", grams: 240, kcal: 5.7200...7.7200, confidence: .estimated, source: "ibge:8202804-99"),
        ]),
        Sample(group: "regional", phrase: "pequi", expected: [
            Expected(name: "Pequi", grams: 3.75, kcal: 4.7000...6.7000, confidence: .estimated, source: "ibge:6806701-99"),
        ]),
        Sample(group: "regional", phrase: "200g de baião de dois", expected: [
            Expected(name: "Baião de dois", grams: 200, kcal: 269.2800...274.7200, confidence: .exact, source: "taco:527"),
        ]),
        Sample(group: "regional", phrase: "2 pamonhas", expected: [
            Expected(name: "Pamonha", grams: 320, kcal: 541.7280...552.6720, confidence: .exact, source: "ibge:6905101-99"),
        ]),
        Sample(group: "regional", phrase: "1 fatia de pamonha", expected: [
            Expected(name: "Pamonha", grams: 40, kcal: 67.4000...69.4000, confidence: .exact, source: "ibge:6905101-99"),
        ]),
        Sample(group: "regional", phrase: "1 concha de vatapá", expected: [
            Expected(name: "Vatapá", grams: 150, kcal: 335.7140...342.4961, confidence: .exact, source: "ibge:8502801-99"),
        ]),
        Sample(group: "regional", phrase: "1 cumbuca de tacacá", expected: [
            Expected(name: "Tacacá", grams: 300, kcal: 47.0000...49.0000, confidence: .exact, source: "ibge:8502401-99"),
        ]),
        Sample(group: "americana", phrase: "hambúrguer", expected: [
            Expected(name: "Hambúrguer", grams: 200, kcal: 495.0000...505.0000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "x-tudo", expected: [
            Expected(name: "Hambúrguer", grams: 200, kcal: 495.0000...505.0000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "cachorro-quente", expected: [
            Expected(name: "Cachorro-quente", grams: 180, kcal: 427.6800...436.3200, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "pizza", expected: [
            Expected(name: "Pizza", grams: 220, kcal: 588.0600...599.9400, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "6 nuggets", expected: [
            Expected(name: "Nuggets", grams: 120, kcal: 332.6400...339.3600, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "batata frita", expected: [
            Expected(name: "Batata frita", grams: 100, kcal: 264.3300...269.6700, confidence: .estimated, source: "taco:93"),
        ]),
        Sample(group: "americana", phrase: "milk shake", expected: [
            Expected(name: "Milk shake", grams: 300, kcal: 478.4373...488.1027, confidence: .estimated, source: "ibge:6907501-99"),
        ]),
        Sample(group: "americana", phrase: "milkshake", expected: [
            Expected(name: "Milk shake", grams: 300, kcal: 478.4373...488.1027, confidence: .estimated, source: "ibge:6907501-99"),
        ]),
        Sample(group: "americana", phrase: "donut", expected: [
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "americana", phrase: "panqueca", expected: [
            Expected(name: "Panqueca", grams: 80, kcal: 160.9186...164.1694, confidence: .estimated, source: "ibge:8500913-99"),
        ]),
        Sample(group: "americana", phrase: "brownie", expected: [
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "americana", phrase: "cookie", expected: [
            Expected(name: "Biscoito", grams: 12, kcal: 55.6400...57.6400, confidence: .estimated, source: "taco:9"),
        ]),
        Sample(group: "americana", phrase: "wrap", expected: [
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "americana", phrase: "burrito", expected: [
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "americana", phrase: "hot dog", expected: [
            Expected(name: "Cachorro-quente", grams: 180, kcal: 427.6800...436.3200, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "bacon", expected: [
            Expected(name: "Bacon", grams: 15, kcal: 80.1500...82.1500, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "2 fatias de pizza", expected: [
            Expected(name: "Pizza", grams: 220, kcal: 588.0600...599.9400, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "1 x-bacon", expected: [
            Expected(name: "Hambúrguer", grams: 200, kcal: 495.0000...505.0000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "100g de batata frita", expected: [
            Expected(name: "Batata frita", grams: 100, kcal: 264.3300...269.6700, confidence: .exact, source: "taco:93"),
        ]),
        Sample(group: "americana", phrase: "um copo de milkshake", expected: [
            Expected(name: "Milk shake", grams: 240, kcal: 382.7498...390.4822, confidence: .exact, source: "ibge:6907501-99"),
        ]),
        Sample(group: "americana", phrase: "cheeseburger", expected: [
            Expected(name: "Hambúrguer", grams: 200, kcal: 495.0000...505.0000, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "americana", phrase: "2 cookies", expected: [
            Expected(name: "Biscoito", grams: 24, kcal: 112.1472...114.4128, confidence: .exact, source: "taco:9"),
        ]),
        Sample(group: "redes", phrase: "2 big mac", expected: [
            Expected(name: "Big Mac (McDonald's)", grams: 200.0, kcal: 1037.5200...1058.4800, confidence: .exact, source: "fastfood:mcdonalds-0"),
        ]),
        Sample(group: "redes", phrase: "mc fritas média", expected: [
            Expected(name: "McFritas Média (McDonald's)", grams: 100.0, kcal: 292.0500...297.9500, confidence: .exact, source: "fastfood:mcdonalds-52"),
        ]),
        Sample(group: "redes", phrase: "batata do mc", expected: [
            Expected(name: "McFritas Média (McDonald's)", grams: 100.0, kcal: 292.0500...297.9500, confidence: .estimated, source: "fastfood:mcdonalds-52"),
        ]),
        Sample(group: "redes", phrase: "whopper", expected: [
            Expected(name: "Whopper (Burger King)", grams: 325.0, kcal: 709.8448...724.1852, confidence: .exact, source: "fastfood:burger-king-151"),
        ]),
        Sample(group: "redes", phrase: "whopper jr", expected: [
            Expected(name: "Whopper Jr. (Burger King)", grams: 179.0, kcal: 384.1204...391.8804, confidence: .exact, source: "fastfood:burger-king-156"),
        ]),
        Sample(group: "redes", phrase: "10 mcnuggets", expected: [
            Expected(name: "Chicken McNugget (McDonald's)", grams: 166.70000000000002, kcal: 382.8766...390.6114, confidence: .exact, source: "fastfood:mcdonalds-131"),
        ]),
        Sample(group: "redes", phrase: "6 mcnuggets", expected: [
            Expected(name: "Chicken McNugget (McDonald's)", grams: 100.02000000000001, kcal: 229.7259...234.3669, confidence: .exact, source: "fastfood:mcdonalds-131"),
        ]),
        Sample(group: "redes", phrase: "big bob", expected: [
            Expected(name: "Big Bob (Bob's)", grams: 233.3, kcal: 595.8949...607.9331, confidence: .exact, source: "fastfood:bobs-481"),
        ]),
        Sample(group: "redes", phrase: "beirute de kafta", expected: [
            Expected(name: "Beirute de Kafta (Habib's)", grams: 530.0, kcal: 1122.8580...1145.5420, confidence: .exact, source: "fastfood:habibs-350"),
        ]),
        Sample(group: "redes", phrase: "beirute de kafta do habibs", expected: [
            Expected(name: "Beirute de Kafta (Habib's)", grams: 530.0, kcal: 1122.8580...1145.5420, confidence: .exact, source: "fastfood:habibs-350"),
        ]),
        Sample(group: "redes", phrase: "bloomin onion", expected: [
            Expected(name: "Bloomin' Onion (Outback)", grams: 100.0, kcal: 1900.8000...1939.2000, confidence: .estimated, source: "fastfood:outback-521"),
        ]),
        Sample(group: "redes", phrase: "churros do bk", expected: [
            Expected(name: "Churro", grams: 59, kcal: 234.6096...239.3492, confidence: .estimated, source: "ibge:6905001-99"),
        ]),
        Sample(group: "redes", phrase: "coxa do kfc", expected: [
            Expected(name: "Coxa Crocante (KFC)", grams: 82.0, kcal: 234.6264...239.3664, confidence: .exact, source: "fastfood:kfc-228"),
        ]),
        Sample(group: "redes", phrase: "tirinhas do kfc", expected: [
            Expected(name: "Tirinha Crocante (KFC)", grams: 76.0, kcal: 177.2128...180.7928, confidence: .exact, source: "fastfood:kfc-234"),
        ]),
        Sample(group: "redes", phrase: "6 nuggets do bk", expected: [
            Expected(name: "BK Chicken (nugget) (Burger King)", grams: 111.0, kcal: 220.7690...225.2290, confidence: .exact, source: "fastfood:burger-king-217"),
        ]),
        Sample(group: "redes", phrase: "big king", expected: [
            Expected(name: "Big King (Burger King)", grams: 266.0, kcal: 731.6112...746.3912, confidence: .exact, source: "fastfood:burger-king-132"),
        ]),
        Sample(group: "redes", phrase: "cheddar mcmelt", expected: [
            Expected(name: "Cheddar McMelt (McDonald's)", grams: 100.0, kcal: 503.9100...514.0900, confidence: .exact, source: "fastfood:mcdonalds-3"),
        ]),
        Sample(group: "redes", phrase: "batata grande do bk", expected: [
            Expected(name: "Batata Frita – grande (Burger King)", grams: 142.0, kcal: 323.7276...330.2676, confidence: .exact, source: "fastfood:burger-king-165"),
        ]),
        Sample(group: "redes", phrase: "esfiha de carne do habibs", expected: [
            Expected(name: "Bib'sfiha de Carne (Habib's)", grams: 75.0, kcal: 150.4825...153.5225, confidence: .exact, source: "fastfood:habibs-326"),
        ]),
        Sample(group: "redes", phrase: "ribs do outback", expected: [
            Expected(name: "Ribs on the Barbie (Outback)", grams: 100.0, kcal: 1425.6000...1454.4000, confidence: .estimated, source: "fastfood:outback-526"),
        ]),
        Sample(group: "redes", phrase: "frango teriyaki proteico do subway", expected: [
            Expected(name: "Frango Teriyaki Proteico (Subway)", grams: 307.0, kcal: 482.1242...491.8640, confidence: .exact, source: "fastfood:subway-264"),
        ]),
        Sample(group: "redes", phrase: "2 big mac e mc fritas média", expected: [
            Expected(name: "Big Mac (McDonald's)", grams: 200.0, kcal: 1037.5200...1058.4800, confidence: .exact, source: "fastfood:mcdonalds-0"),
            Expected(name: "McFritas Média (McDonald's)", grams: 100.0, kcal: 292.0500...297.9500, confidence: .exact, source: "fastfood:mcdonalds-52"),
        ]),
        Sample(group: "quantidades", phrase: "200g de arroz", expected: [
            Expected(name: "Arroz branco", grams: 200, kcal: 253.4400...258.5600, confidence: .exact, source: "taco:3"),
        ]),
        Sample(group: "quantidades", phrase: "200g de frango", expected: [
            Expected(name: "Frango grelhado", grams: 200, kcal: 314.8200...321.1800, confidence: .exact, source: "taco:410"),
        ]),
        Sample(group: "quantidades", phrase: "meio pão francês", expected: [
            Expected(name: "Pão francês", grams: 25, kcal: 74.0000...76.0000, confidence: .exact, source: "taco:53"),
        ]),
        Sample(group: "quantidades", phrase: "1/2 pão francês", expected: [
            Expected(name: "Pão francês", grams: 25, kcal: 74.0000...76.0000, confidence: .exact, source: "taco:53"),
        ]),
        Sample(group: "quantidades", phrase: "duas colheres de arroz", expected: [
            Expected(name: "Arroz branco", grams: 50, kcal: 63.0000...65.0000, confidence: .exact, source: "taco:3"),
        ]),
        Sample(group: "quantidades", phrase: "1 concha de feijão", expected: [
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
        ]),
        Sample(group: "quantidades", phrase: "1 fatia de pamonha", expected: [
            Expected(name: "Pamonha", grams: 40, kcal: 67.4000...69.4000, confidence: .exact, source: "ibge:6905101-99"),
        ]),
        Sample(group: "quantidades", phrase: "um copo de café com leite", expected: [
            Expected(name: "Café com leite", grams: 240, kcal: 74.4560...76.4560, confidence: .exact, source: "ibge:8501303-99"),
        ]),
        Sample(group: "quantidades", phrase: "3x ovo", expected: [
            Expected(name: "Ovo", grams: 150, kcal: 216.8100...221.1900, confidence: .exact, source: "taco:488"),
        ]),
        Sample(group: "quantidades", phrase: "10g de arroz e feijão cada", expected: [
            Expected(name: "Arroz branco", grams: 10, kcal: 11.8000...13.8000, confidence: .exact, source: "taco:3"),
            Expected(name: "Feijão", grams: 10, kcal: 6.6000...8.6000, confidence: .exact, source: "taco:561"),
        ]),
        Sample(group: "quantidades", phrase: "arroz e feijão, 10g de cada", expected: [
            Expected(name: "Arroz branco", grams: 10, kcal: 11.8000...13.8000, confidence: .exact, source: "taco:3"),
            Expected(name: "Feijão", grams: 10, kcal: 6.6000...8.6000, confidence: .exact, source: "taco:561"),
        ]),
        Sample(group: "quantidades", phrase: "2 colheres de arroz e feijão cada", expected: [
            Expected(name: "Arroz branco", grams: 50, kcal: 63.0000...65.0000, confidence: .exact, source: "taco:3"),
            Expected(name: "Feijão", grams: 40, kcal: 29.4000...31.4000, confidence: .estimated, source: "taco:561"),
        ]),
        Sample(group: "quantidades", phrase: "1,5 kg de melancia", expected: [
            Expected(name: "Melancia", grams: 1500, kcal: 490.0500...499.9500, confidence: .exact, source: "taco:235"),
        ]),
        Sample(group: "quantidades", phrase: "350 ml de refri", expected: [
            Expected(name: "Refrigerante", grams: 350, kcal: 117.8100...120.1900, confidence: .exact, source: "taco:480"),
        ]),
        Sample(group: "quantidades", phrase: "1 colher de chá de açúcar", expected: [
            Expected(name: "Açúcar", grams: 5, kcal: 18.3500...20.3500, confidence: .estimated, source: "taco:494"),
        ]),
        Sample(group: "quantidades", phrase: "2 fatias de pão de forma", expected: [
            Expected(name: "Pão de forma", grams: 50, kcal: 125.2350...127.7650, confidence: .exact, source: "taco:52"),
        ]),
        Sample(group: "quantidades", phrase: "uma lata de atum", expected: [
            Expected(name: "Atum", grams: 120, kcal: 197.2080...201.1920, confidence: .exact, source: "taco:277"),
        ]),
        Sample(group: "quantidades", phrase: "frango 150 gramas", expected: [
            Expected(name: "Frango grelhado", grams: 150, kcal: 236.1150...240.8850, confidence: .exact, source: "taco:410"),
        ]),
        Sample(group: "quantidades", phrase: "2x big mac", expected: [
            Expected(name: "Big Mac (McDonald's)", grams: 200.0, kcal: 1037.5200...1058.4800, confidence: .exact, source: "fastfood:mcdonalds-0"),
        ]),
        Sample(group: "quantidades", phrase: "meia pizza", expected: [
            Expected(name: "Pizza", grams: 110, kcal: 294.0300...299.9700, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "quantidades", phrase: "100g de arroz e 100g de feijão", expected: [
            Expected(name: "Arroz branco", grams: 100, kcal: 126.7200...129.2800, confidence: .exact, source: "taco:3"),
            Expected(name: "Feijão", grams: 100, kcal: 75.0000...77.0000, confidence: .exact, source: "taco:561"),
        ]),
        Sample(group: "quantidades", phrase: "200g de arroz, 100g de frango e 2 ovos", expected: [
            Expected(name: "Arroz branco", grams: 200, kcal: 253.4400...258.5600, confidence: .exact, source: "taco:3"),
            Expected(name: "Frango grelhado", grams: 100, kcal: 157.4100...160.5900, confidence: .exact, source: "taco:410"),
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .exact, source: "taco:488"),
        ]),
        Sample(group: "ditado", phrase: "almocei arroz feijão e um bife acebolado com salada", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
            Expected(name: "Bife", grams: 120, kcal: 230.4720...235.1280, confidence: .estimated, source: "taco:346"),
            Expected(name: "Salada", grams: 100, kcal: 10.0000...12.0000, confidence: .estimated, source: "taco:78"),
        ]),
        Sample(group: "ditado", phrase: "comi 2 ovos", expected: [
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .exact, source: "taco:488"),
        ]),
        Sample(group: "ditado", phrase: "eu comi duas bananas", expected: [
            Expected(name: "Banana", grams: 140, kcal: 135.8280...138.5720, confidence: .exact, source: "taco:182"),
        ]),
        Sample(group: "ditado", phrase: "hoje almocei 200g de arroz e 100g de frango", expected: [
            Expected(name: "Arroz branco", grams: 200, kcal: 253.4400...258.5600, confidence: .exact, source: "taco:3"),
            Expected(name: "Frango grelhado", grams: 100, kcal: 157.4100...160.5900, confidence: .exact, source: "taco:410"),
        ]),
        Sample(group: "ditado", phrase: "whoper", expected: [
            Expected(name: "Whopper (Burger King)", grams: 325.0, kcal: 709.8448...724.1852, confidence: .estimated, source: "fastfood:burger-king-151"),
        ]),
        Sample(group: "ditado", phrase: "feijao", expected: [
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
        ]),
        Sample(group: "ditado", phrase: "macarao", expected: [
            Expected(name: "Macarrão", grams: 200, kcal: 310.8600...317.1400, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "ditado", phrase: "refri", expected: [
            Expected(name: "Refrigerante", grams: 350, kcal: 117.8100...120.1900, confidence: .estimated, source: "taco:480"),
        ]),
        Sample(group: "ditado", phrase: "breja", expected: [
            Expected(name: "Cerveja", grams: 350, kcal: 142.0650...144.9350, confidence: .estimated, source: "taco:474"),
        ]),
        Sample(group: "ditado", phrase: "dogão", expected: [
            Expected(name: "Cachorro-quente", grams: 180, kcal: 427.6800...436.3200, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "ditado", phrase: "Almoço: arroz, feijão e frango", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
            Expected(name: "Frango grelhado", grams: 120, kcal: 188.8920...192.7080, confidence: .estimated, source: "taco:410"),
        ]),
        Sample(group: "ditado", phrase: "pao de queijo", expected: [
            Expected(name: "Pão de queijo", grams: 40, kcal: 143.7480...146.6520, confidence: .estimated, source: "taco:140"),
        ]),
        Sample(group: "ditado", phrase: "2 bananaz", expected: [
            Expected(name: "Banana", grams: 140, kcal: 135.8280...138.5720, confidence: .estimated, source: "taco:182"),
        ]),
        Sample(group: "ditado", phrase: "100g de feijao", expected: [
            Expected(name: "Feijão", grams: 100, kcal: 75.0000...77.0000, confidence: .exact, source: "taco:561"),
        ]),
        Sample(group: "ditado", phrase: "quero registrar 2 big mac", expected: [
            Expected(name: "Big Mac (McDonald's)", grams: 200.0, kcal: 1037.5200...1058.4800, confidence: .exact, source: "fastfood:mcdonalds-0"),
        ]),
        Sample(group: "ditado", phrase: "tomei um copo de café com leite", expected: [
            Expected(name: "Café com leite", grams: 240, kcal: 74.4560...76.4560, confidence: .exact, source: "ibge:8501303-99"),
        ]),
        Sample(group: "ditado", phrase: "comi arroz, feijão e bife", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
            Expected(name: "Feijão", grams: 140, kcal: 105.3360...107.4640, confidence: .estimated, source: "taco:561"),
            Expected(name: "Bife", grams: 120, kcal: 230.4720...235.1280, confidence: .estimated, source: "taco:346"),
        ]),
        Sample(group: "ditado", phrase: "um dogao e uma breja", expected: [
            Expected(name: "Cachorro-quente", grams: 180, kcal: 427.6800...436.3200, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
            Expected(name: "Cerveja", grams: 350, kcal: 142.0650...144.9350, confidence: .exact, source: "taco:474"),
        ]),
        Sample(group: "ditado", phrase: "2 ovos e 100g de macarao", expected: [
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .exact, source: "taco:488"),
            Expected(name: "Macarrão", grams: 100, kcal: 155.4300...158.5700, confidence: .estimated, source: "FoodDatabase.curated (valor preexistente)"),
        ]),
        Sample(group: "ditado", phrase: "100g de feijao e 2 ovoss", expected: [
            Expected(name: "Feijão", grams: 100, kcal: 75.0000...77.0000, confidence: .exact, source: "taco:561"),
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .estimated, source: "taco:488"),
        ]),
        Sample(group: "ditado", phrase: "arroz e xablau", expected: [
            Expected(name: "Arroz branco", grams: 150, kcal: 190.0800...193.9200, confidence: .estimated, source: "taco:3"),
            Expected(name: nil, grams: 0, kcal: 0.0000...0.0000, confidence: .unknown, source: "sem fonte: não soma"),
        ]),
        Sample(group: "ditado", phrase: "hoje tomei 350ml de refri", expected: [
            Expected(name: "Refrigerante", grams: 350, kcal: 117.8100...120.1900, confidence: .exact, source: "taco:480"),
        ]),
        Sample(group: "ditado", phrase: "2 ovoss", expected: [
            Expected(name: "Ovo", grams: 100, kcal: 144.5400...147.4600, confidence: .estimated, source: "taco:488"),
        ]),
        Sample(group: "ditado", phrase: "100g de buchada", expected: [
            Expected(name: "Buchada de bode", grams: 100, kcal: 123.7500...126.2500, confidence: .estimated, source: "ibge:7107204-99"),
        ]),
        Sample(group: "ditado", phrase: "whopper junior", expected: [
            Expected(name: "Whopper Jr. (Burger King)", grams: 179.0, kcal: 384.1204...391.8804, confidence: .exact, source: "fastfood:burger-king-156"),
        ]),
        Sample(group: "ditado", phrase: "brownie do outback", expected: [
            Expected(name: "Brownie (Outback)", grams: 100.0, kcal: 287.1000...292.9000, confidence: .estimated, source: "fastfood:outback-537"),
        ]),
    ]

    @Test func everyRequestedGroupHasAtLeastFifteenPhrases() {
        #expect(Self.samples.count >= 100)
        for group in ["brasileira", "regional", "americana", "redes", "quantidades", "ditado"] {
            #expect(Self.samples.filter { $0.group == group }.count >= 15)
        }
    }

    @Test(arguments: samples)
    func coverage(sample: Sample) throws {
        let actual = FoodParser.shared.estimate(sample.phrase)
        let observation: [String: Any] = [
            "group": sample.group, "phrase": sample.phrase,
            "items": actual.items.map { item -> [String: Any] in
                ["name": item.foodName as Any? ?? NSNull(), "grams": item.grams,
                 "kcal": item.nutrition.kcal, "confidence": String(describing: item.confidence)]
            },
            "totalKcal": actual.total.kcal
        ]
        let data = try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys])
        print("FOOD_COVERAGE " + String(decoding: data, as: UTF8.self))
        #expect(actual.items.map(\.foodName) == sample.expected.map(\.name), "\(sample.phrase)")
        #expect(actual.items.map(\.confidence) == sample.expected.map(\.confidence), "\(sample.phrase)")
        for (item, expected) in zip(actual.items, sample.expected) {
            #expect(abs(item.grams - expected.grams) < 0.02, "\(sample.phrase): \(expected.source)")
            #expect(expected.kcal.contains(item.nutrition.kcal), "\(sample.phrase): \(expected.source)")
        }
        let totalRange = sample.expected.reduce(0.0...0.0) {
            ($0.lowerBound + $1.kcal.lowerBound)...($0.upperBound + $1.kcal.upperBound)
        }
        #expect(totalRange.contains(actual.total.kcal), "\(sample.phrase)")
    }
}
