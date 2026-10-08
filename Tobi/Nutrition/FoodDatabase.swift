import Foundation

/// Base local de comida brasileira: os apelidos e porções do dia a dia em cima das tabelas
/// oficiais, mais o IBGE (1.971 preparos) e a TACO (591 alimentos) inteiros.
enum FoodDatabase {
    /// Medidas caseiras genéricas, em gramas/ml.
    static let measures: [String: Double] = [
        "colher": 20, "colher de sopa": 20, "colher de sobremesa": 10, "colher de cha": 5,
        "concha": 140, "fatia": 30, "copo": 240, "xicara": 200, "lata": 350,
        "pedaco": 100, "scoop": 30, "punhado": 25, "prato": 350, "pote": 170,
        "bola": 60, "tigela": 300, "garrafa": 600, "taca": 150,
        "posta": 120, "rodela": 15, "gomo": 10, "barra": 25, "dose": 50, "escumadeira": 70,
        "pegador": 60, "garfada": 20, "cumbuca": 250, "caneca": 300, "pires": 80,
        "espetinho": 60, "espeto": 100, "folha": 10,
        // Medianas da Tabela de Medidas Referidas da POF 2008-2009 (IBGE), quando o alimento não tem a dele.
        // Fora as que também são nome de comida ("bife", "colher de arroz"), que o parser confundiria.
        "colher de servir": 50, "colher de cafe": 2.5, "ponta de faca": 12.5,
        "copo americano": 150, "copo de requeijao": 240, "copo grande": 300, "copo medio": 240,
        "xicara de cha": 200, "xicara de cafe": 50, "prato fundo": 300,
        "prato raso": 140, "prato de sobremesa": 120, "caneco": 300,
        // Unidades por extenso: "meio quilo de carne", "duzentos gramas de arroz", "trezentos ml de suco".
        "grama": 1, "quilo": 1000, "kilo": 1000, "litro": 1000, "mililitro": 1, "miligrama": 0.001,
        "quilograma": 1000, "kilograma": 1000, "centilitro": 10, "decilitro": 100, "onca": 28.35, "libra": 453.6,
        // Embalagens com tamanho de mercado: lata 350 ml, latão 473 ml, long neck 355 ml.
        "latao": 473, "long neck": 355, "caixinha": 200, "litrinho": 300, "litrao": 1000,
        // Medidas de cozinha sem tabela oficial: o número sai sempre com "~" (ver FoodParser.roughMeasures).
        "pitada": 0.5, "fio": 5, "gota": 0.05, "dedo": 30, "gole": 30, "sache": 5, "tablete": 20,
        "quadradinho": 5, "dente": 5, "cubo": 10, "lasca": 20, "naco": 50,
        "calice": 50, "tulipa": 300, "mordida": 20, "bocado": 20,
        "borrifada": 0.3, "envelope": 10,
    ]

    /// Medidas que são unidade de peso ou volume: sempre exatas.
    static let absoluteMeasures: Set<String> = [
        "grama", "quilo", "kilo", "litro", "mililitro", "miligrama", "quilograma", "kilograma",
        "centilitro", "decilitro", "onca", "libra", "litrinho", "litrao",
    ]

    /// Jeitos de falar a mesma medida: diminutivo e aumentativo viram a medida mais parecida.
    static let measureSynonyms: [String: String] = [
        "colherzinha": "colher de cha", "colherinha": "colher de cha", "colher de chazinho": "colher de cha",
        "colherada": "colher de sopa", "copinho": "copo americano", "copao": "copo grande",
        "xicrinha": "xicara de cafe", "xicarazinha": "xicara de cafe", "latinha": "lata", "latao": "lata",
        "pedacinho": "pedaco", "fatiazinha": "fatia", "fatinha": "fatia", "conchinha": "concha",
        "potinho": "pote", "garrafinha": "garrafa", "pacotinho": "pacote", "pratinho": "prato raso",
        "pratao": "prato fundo", "unid": "unidade", "und": "unidade", "porcoe": "porcao",
        "pitadinha": "pitada", "fiozinho": "fio", "gotinha": "gota", "golinho": "gole", "golada": "gole",
        "dedinho": "dedo", "saquinho": "pacote", "sachezinho": "sache", "kg": "quilo", "gr": "grama",
        // Abreviações depois de número por extenso: "duzentos ml", "meio kg", "trezentos g".
        "g": "grama", "grs": "grama", "mg": "miligrama", "ml": "mililitro", "lt": "litro", "l": "litro",
        "cl": "centilitro", "dl": "decilitro", "cc": "mililitro", "oz": "onca", "lb": "libra",
        "quilinho": "quilo", "cubinho": "cubo", "lasquinha": "lasca", "mordidinha": "mordida",
        "punhadinho": "punhado", "mao cheia": "punhado", "mancheia": "punhado", "maozada": "punhado",
        "colherona": "colher de sopa", "conchona": "concha", "pedacao": "pedaco", "fationa": "fatia",
        "barrinha": "barra", "tigelinha": "tigela", "shot": "dose", "medidor": "scoop", "dosador": "scoop",
        "rodelinha": "rodela", "embalagem": "pacote",
    ]

    /// Palavras que significam "uma porção do próprio alimento".
    static let portionWords: Set<String> = ["unidade", "un", "porcao", "peca", "pacote"]

    /// Linhas que são só títulos de refeição, não comida.
    static let labels: Set<String> = [
        "cafe da manha", "cafe da tarde", "almoco", "janta", "jantar", "ceia",
        "lanche", "lanche da manha", "lanche da tarde", "pre treino", "pos treino",
    ]

    /// Ordem = prioridade quando dois apelidos empatam: a lista do dia a dia, as tabelas oficiais
    /// das redes de fast food, o IBGE (comida pronta do jeito brasileiro) e por fim a TACO (ingredientes).
    static let foods: [Food] = curated
        + FoodTables.fastfood.map { Food(table: $0, source: .chain($0.id, estimated: $0.estimated ?? false)) }
        + FoodTables.ibge.map { Food(table: $0, source: .ibge($0.id)) }
        + FoodTables.taco.map { Food(table: $0, source: .taco($0.id)) }

    /// Só acrescenta grafias aos preparos existentes do IBGE; preserva nutrientes e medidas.
    private static func ibge(_ id: String, aliases: [String], guesses: Set<String> = []) -> Food {
        guard let food = FoodTables.ibge.first(where: { $0.id == id }) else {
            preconditionFailure("IBGE \(id) não existe")
        }
        return Food(table: food, source: .ibge(id), additionalAliases: aliases, guessedAliases: guesses)
    }

    /// Colheres de tempero seco: "pimenta em pó" da Tabela de Medidas Referidas (POF 2008-2009, IBGE).
    private static let spoon: [String: Double] = [
        "colher de cafe": 1.2, "colher de cha": 1.5, "colher de sobremesa": 6.5, "colher de sopa": 13, "colher": 13,
    ]

    /// Os que a gente fala todo dia, com apelido e porção caseira. Sem `taco:` = estimativa nossa
    /// (prato pronto que a TACO não tem). Ganham da TACO automática quando o apelido empata.
    static let curated: [Food] = [
        // IBGE POF 2008–2009: mesmos preparos e porções, sem novos números nutricionais.
        ibge("8570328-99", aliases: ["pao frances com manteiga"]),
        ibge("6907501-99", aliases: ["milkshake"]),
        ibge("7107204-99", aliases: ["buchada"], guesses: ["buchada"]),
        // Arroz, feijão e acompanhamentos
        Food("Arroz branco", ["arroz", "arroz branco"], taco: 3, portion: 150, measures: ["colher": 25]),
        Food("Arroz integral", ["arroz integral"], taco: 1, portion: 150, measures: ["colher": 25]),
        Food("Feijão", ["feijao", "feijao carioca", "caldo de feijao"], taco: 561, portion: 140),
        Food("Feijão preto", ["feijao preto"], taco: 567, portion: 140),
        Food("Feijoada", ["feijoada"], taco: 540, portion: 250, measures: ["concha": 150]),
        Food("Baião de dois", ["baiao de dois", "baiao"], taco: 527, portion: 200),
        Food("Farofa", ["farofa"], taco: 131, portion: 30, measures: ["colher": 15]),
        Food("Macarrão", ["macarrao", "espaguete", "massa", "penne"], kcal: 157, p: 5.8, c: 30.9, f: 0.9, portion: 200),
        Food("Miojo", ["miojo", "lamen", "macarrao instantaneo"], taco: 39, portion: 85),
        Food("Lasanha", ["lasanha"], kcal: 160, p: 9, c: 14, f: 7, portion: 300),
        Food("Purê de batata", ["pure", "pure de batata"], kcal: 100, p: 1.8, c: 15, f: 3.6, portion: 150),
        Food("Batata cozida", ["batata", "batata cozida", "batata inglesa"], taco: 91, portion: 150),
        Food("Batata frita", ["batata frita", "frita"], taco: 93, portion: 100),
        Food("Batata doce", ["batata doce"], taco: 88, portion: 150),
        Food("Mandioca", ["mandioca", "aipim", "macaxeira"], taco: 129, portion: 150),
        Food("Mandioca frita", ["mandioca frita", "aipim frito", "macaxeira frita"], taco: 132, portion: 120),
        Food("Cuscuz", ["cuscuz", "cuscuz de milho", "cuscuz nordestino"], taco: 533, portion: 150),
        Food("Tapioca", ["tapioca"], kcal: 240, p: 0.5, c: 59, f: 0.2, portion: 70),
        Food("Crepioca", ["crepioca"], kcal: 200, p: 10, c: 18, f: 9, portion: 100),
        Food("Salada", ["salada", "alface", "salada verde", "rucula"], taco: 78, portion: 100),
        Food("Tomate", ["tomate"], taco: 157, portion: 100),
        Food("Legumes", ["legume", "brocolis", "cenoura", "abobrinha", "chuchu", "vagem"], kcal: 30, p: 1.5, c: 6, f: 0.3, portion: 100),
        Food("Sopa", ["sopa", "caldo", "canja"], kcal: 50, p: 3, c: 6, f: 1.5, portion: 300),

        // Carnes, ovos e proteínas
        Food("Bife", ["bife", "carne", "carne bovina", "alcatra", "contrafile", "patinho", "maminha", "fraldinha"], taco: 346, portion: 120),
        Food("Picanha", ["picanha"], taco: 381, portion: 150),
        Food("Carne moída", ["carne moida"], taco: 326, portion: 100),
        Food("Frango grelhado", ["frango", "frango grelhado", "peito de frango", "file de frango", "frango desfiado"], taco: 410, portion: 120),
        Food("Frango frito", ["frango frito", "coxa de frango", "sobrecoxa", "frango assado"], taco: 396, portion: 120),
        Food("Parmegiana", ["parmegiana", "file a parmegiana", "bife a parmegiana", "frango a parmegiana"], kcal: 230, p: 18, c: 8, f: 14, portion: 250),
        Food("Strogonoff", ["strogonoff", "estrogonofe", "strogonoff de frango", "estrogonofe de frango"], taco: 538, portion: 200),
        Food("Strogonoff de carne", ["strogonoff de carne", "estrogonofe de carne"], taco: 537, portion: 200),
        Food("Escondidinho", ["escondidinho"], kcal: 150, p: 9, c: 13, f: 7, portion: 300),
        Food("Peixe", ["peixe", "tilapia", "file de peixe", "merluza", "pescada"], kcal: 128, p: 26, c: 0, f: 2.7, portion: 120),
        Food("Salmão", ["salmao"], taco: 315, portion: 120),
        Food("Atum", ["atum", "atum em lata"], taco: 277, portion: 120, measures: ["lata": 120]),
        Food("Ovo", ["ovo", "ovo cozido"], taco: 488, portion: 50),
        Food("Ovo de codorna", ["ovo de codorna", "ovinho de codorna", "ovo de codorna cozido"], taco: 485, portion: 10),
        Food("Ovo frito", ["ovo frito"], taco: 490, portion: 50),
        Food("Ovo mexido", ["ovo mexido"], kcal: 180, p: 12, c: 1.5, f: 14, portion: 60),
        Food("Omelete", ["omelete", "omelet"], kcal: 180, p: 12, c: 1.5, f: 14, portion: 130),
        Food("Linguiça", ["linguica", "linguica toscana", "calabresa"], taco: 423, portion: 100),
        Food("Bacon", ["bacon"], kcal: 541, p: 37, c: 1.4, f: 42, portion: 15, measures: ["fatia": 10]),
        Food("Presunto", ["presunto"], taco: 439, portion: 30, measures: ["fatia": 15]),
        Food("Peito de peru", ["peito de peru", "blanquet"], kcal: 105, p: 18, c: 2, f: 2.5, portion: 30, measures: ["fatia": 15]),
        Food("Whey", ["whey", "whey protein"], kcal: 400, p: 80, c: 8, f: 6, portion: 30, measures: ["scoop": 30, "dose": 30]),

        // Pães, café da manhã e laticínios
        Food("Pão francês", ["pao", "pao frances", "pao de sal", "cacetinho"], taco: 53, portion: 50),
        Food("Pão de forma", ["pao de forma", "pao integral", "torrada"], taco: 52, portion: 50, measures: ["fatia": 25]),
        Food("Pão de queijo", ["pao de queijo"], taco: 140, portion: 40),
        Food("Manteiga", ["manteiga", "margarina"], taco: 261, portion: 10, measures: ["colher": 10]),
        Food("Requeijão", ["requeijao", "catupiry"], taco: 468, portion: 20, measures: ["colher": 15]),
        Food("Queijo minas", ["queijo", "queijo minas", "queijo branco", "queijo coalho"], taco: 461, portion: 30),
        Food("Queijo prato", ["queijo prato"], taco: 467, portion: 20, measures: ["fatia": 20]),
        Food("Mussarela", ["mussarela", "mucarela", "queijo mussarela"], taco: 463, portion: 20, measures: ["fatia": 20]),
        Food("Café", ["cafe", "cafe preto", "cafezinho", "expresso"], taco: 471, portion: 100),
        Food("Leite", ["leite", "leite integral"], kcal: 61, p: 3.2, c: 4.7, f: 3.3, portion: 200),
        Food("Leite desnatado", ["leite desnatado"], kcal: 35, p: 3.4, c: 5.0, f: 0.1, portion: 200),
        Food("Iogurte", ["iogurte", "iogurte natural"], taco: 448, portion: 170),
        Food("Iogurte grego", ["iogurte grego"], kcal: 120, p: 5, c: 14, f: 5, portion: 100),
        Food("Aveia", ["aveia"], taco: 7, portion: 30, measures: ["colher": 15]),
        Food("Granola", ["granola"], kcal: 420, p: 9, c: 66, f: 14, portion: 40, measures: ["colher": 15]),
        Food("Açúcar", ["acucar"], taco: 494, portion: 5, measures: ["colher": 12]),
        Food("Mel", ["mel"], taco: 507, portion: 15),

        // Lanches e salgados
        Food("Sanduíche", ["sanduiche", "sanduiche natural", "misto", "misto quente"], kcal: 250, p: 12, c: 28, f: 10, portion: 150),
        Food("Hambúrguer", ["hamburguer", "burger", "cheeseburger", "cheese burger", "x burguer", "x salada", "x bacon", "x tudo", "x egg"], kcal: 250, p: 13, c: 24, f: 11, portion: 200),
        Food("Cachorro-quente", ["cachorro quente", "hot dog", "dogao"], kcal: 240, p: 9, c: 26, f: 11, portion: 180),
        Food("Pizza", ["pizza"], kcal: 270, p: 11, c: 30, f: 11, portion: 220, measures: ["fatia": 110, "pedaco": 110]),
        Food("Coxinha", ["coxinha"], taco: 386, portion: 110),
        Food("Pastel", ["pastel"], taco: 56, portion: 100),
        Food("Esfiha", ["esfiha", "esfirra"], kcal: 280, p: 10, c: 40, f: 9, portion: 80),
        Food("Nuggets", ["nugget"], kcal: 280, p: 14, c: 17, f: 18, portion: 20),
        Food("Sushi", ["sushi", "niguiri", "uramaki", "sashimi"], kcal: 150, p: 5, c: 28, f: 2, portion: 30),
        Food("Hot roll", ["hot roll", "hot"], kcal: 260, p: 6, c: 30, f: 13, portion: 30),
        Food("Yakisoba", ["yakisoba"], kcal: 130, p: 7, c: 18, f: 3.5, portion: 350),
        Food("Prato feito", ["pf", "prato feito", "marmita", "marmitex"], kcal: 140, p: 8, c: 18, f: 4, portion: 600),

        // Frutas
        Food("Banana", ["banana", "banana prata", "banana nanica"], taco: 182, portion: 70),
        Food("Maçã", ["maca"], taco: 222, portion: 130),
        Food("Laranja", ["laranja", "mexerica", "tangerina", "bergamota"], taco: 214, portion: 150),
        Food("Mamão", ["mamao", "papaia"], taco: 226, portion: 150),
        Food("Melancia", ["melancia"], taco: 235, portion: 200),
        Food("Melão", ["melao"], taco: 236, portion: 200),
        Food("Manga", ["manga"], taco: 228, portion: 150),
        Food("Uva", ["uva"], taco: 256, portion: 100),
        Food("Morango", ["morango"], taco: 239, portion: 100),
        Food("Abacate", ["abacate"], taco: 163, portion: 100),
        Food("Açaí", ["acai", "acai na tigela"], taco: 167, portion: 300, measures: ["copo": 300]),

        // Doces e beliscos
        Food("Brigadeiro", ["brigadeiro"], kcal: 425, p: 4, c: 60, f: 18, portion: 20),
        Food("Chocolate", ["chocolate", "barra de chocolate", "bombom"], taco: 495, portion: 25),
        Food("Sorvete", ["sorvete"], kcal: 200, p: 3.5, c: 24, f: 10, portion: 120),
        Food("Pudim", ["pudim"], kcal: 250, p: 6, c: 40, f: 7, portion: 100),
        Food("Bolo", ["bolo", "bolo de cenoura", "bolo de chocolate", "bolo de fuba"], kcal: 370, p: 5, c: 55, f: 15, portion: 80, measures: ["fatia": 80, "pedaco": 80]),
        Food("Biscoito", ["biscoito", "bolacha", "biscoito recheado", "bolacha recheada", "cookie"], taco: 9, portion: 12, measures: ["pacote": 130]),
        Food("Paçoca", ["pacoca"], taco: 579, portion: 20),
        Food("Pipoca", ["pipoca"], taco: 61, portion: 50),
        Food("Gelatina", ["gelatina"], kcal: 60, p: 1.2, c: 14, f: 0, portion: 100),
        Food("Amendoim", ["amendoim", "pasta de amendoim"], taco: 558, portion: 20, measures: ["colher": 15]),
        Food("Castanhas", ["castanha", "castanha do para", "castanha de caju", "noz", "mix de castanha"], kcal: 600, p: 15, c: 25, f: 50, portion: 25),

        // Temperos e óleos. Números da TACO, do IBGE ou do USDA (o que a TACO não tem); as colheres
        // dos temperos secos são as da "pimenta em pó" da POF 2008-2009 do IBGE.
        Food("Azeite de oliva", ["azeite", "azeite de oliva", "azeite extra virgem"], taco: 260, portion: 8,
             measures: ["colher": 8, "colher de sopa": 8, "colher de sobremesa": 5, "colher de cha": 2, "colher de cafe": 1, "fio": 8]),
        Food("Sal", ["sal", "sal refinado", "sal grosso", "sal marinho", "sal rosa", "sal do himalaia"], usda: 173468,
             kcal: 0, p: 0, c: 0, f: 0, sodium: 38_800, portion: 1),
        Food("Pimenta-do-reino", ["pimenta", "pimenta do reino", "pimenta preta", "pimenta em po"], usda: 170931,
             kcal: 251, p: 10.4, c: 64, f: 3.26, fiber: 25.3, sodium: 20, portion: 0.5, measures: spoon),
        Food("Canela", ["canela", "canela em po"], usda: 171320, kcal: 247, p: 3.99, c: 80.6, f: 1.24, fiber: 53.1,
             sodium: 10, portion: 0.5, measures: spoon),
        Food("Cominho", ["cominho", "cominho em po"], usda: 170923, kcal: 375, p: 17.8, c: 44.2, f: 22.3, fiber: 10.5,
             sodium: 168, portion: 0.5, measures: spoon),
        Food("Páprica", ["paprica", "paprica doce", "paprica picante", "paprica defumada"], usda: 171329,
             kcal: 282, p: 14.1, c: 54, f: 12.9, fiber: 34.9, sodium: 68, portion: 0.5, measures: spoon),
        Food("Louro", ["louro", "folha de louro"], usda: 170917, kcal: 313, p: 7.61, c: 75, f: 8.36, fiber: 26.3,
             sodium: 23, portion: 0.5, measures: spoon),
        Food("Noz-moscada", ["noz moscada"], usda: 171326, kcal: 525, p: 5.84, c: 49.3, f: 36.3, fiber: 20.8,
             sodium: 16, portion: 0.5, measures: spoon),
        Food("Cravo", ["cravo", "cravo da india"], usda: 171321, kcal: 274, p: 5.97, c: 65.5, f: 13, fiber: 33.9,
             sodium: 277, portion: 0.5, measures: spoon),
        Food("Gengibre", ["gengibre"], usda: 169231, kcal: 80, p: 1.82, c: 17.8, f: 0.75, fiber: 2, sodium: 13, portion: 5),
        Food("Vinagre", ["vinagre", "vinagre de maca", "vinagre de vinho", "vinagre de alcool"], usda: 172237,
             kcal: 18, p: 0, c: 0.04, f: 0, sodium: 2, portion: 15),
        Food("Adoçante", ["adocante", "adocante liquido", "adocante em po", "stevia", "sucralose"],
             kcal: 0, p: 0, c: 0, f: 0, portion: 0.3, measures: ["gota": 0.3, "colher de cha": 0.8, "sache": 0.8]),

        // Bebidas
        Food("Refrigerante", ["refrigerante", "refri", "coca", "coca cola", "guarana", "fanta", "sprite"], taco: 480, portion: 350),
        Food("Refrigerante zero", ["refrigerante zero", "refri zero", "coca zero", "guarana zero", "coca cola zero"], kcal: 0.3, p: 0, c: 0, f: 0, portion: 350),
        Food("Suco", ["suco", "suco de laranja", "suco natural"], taco: 215, portion: 250),
        Food("Cerveja", ["cerveja", "chopp", "chope", "breja"], taco: 474, portion: 350, measures: ["copo": 300]),
        Food("Vinho", ["vinho"], kcal: 85, p: 0.1, c: 2.6, f: 0, portion: 150),
        Food("Água de coco", ["agua de coco"], taco: 478, portion: 300),
        Food("Água", ["agua"], kcal: 0, p: 0, c: 0, f: 0, portion: 250),
    ]
}
