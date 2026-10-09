"""Gera Tobi/Resources/suplementos.json a partir de rótulos de suplementos e snacks.

As fontes e o sabor de referência ficam junto a cada produto: site oficial ou a mesma tabela
em duas lojas. Não misturar sabores, fórmulas ou nutrientes do produto preparado com leite.

Unidade = 1 dose do rótulo (`portion`, em gramas). "scoop"/"dosador" = 1 medidor do pote.
Valores saem por 100 g, como nas outras tabelas.

Uso: python3 -I scripts/build_suplementos.py Tobi/Resources/suplementos.json
"""
import json
from pathlib import Path
import re
import sys
import unicodedata

# marca: (nome bonito, jeitos de escrever a marca)
BRANDS = {
    "growth": ("Growth", ["growth", "growth supplements", "da growth"]),
    "maxtitanium": ("Max Titanium", ["max titanium", "da max titanium", "max", "da max", "titanium"]),
    "integralmedica": ("Integralmédica", ["integralmedica", "integral medica", "da integralmedica", "da integral medica"]),
    "probiotica": ("Probiótica", ["probiotica", "da probiotica"]),
    "dux": ("Dux", ["dux", "da dux", "dux nutrition"]),
    "blackskull": ("Black Skull", ["black skull", "blackskull", "da black skull"]),
    "optimum": ("Optimum Nutrition", ["optimum", "optimum nutrition", "da optimum"]),
    "essential": ("Essential Nutrition", ["essential", "essential nutrition", "da essential"]),
    "atlhetica": ("Atlhetica Nutrition", ["atlhetica", "athletica", "atletica", "atlhetica nutrition", "athletica nutrition"]),
    "vitafor": ("Vitafor", ["vitafor", "vita for", "da vitafor"]),
    "soldiers": ("Soldiers Nutrition", ["soldiers", "soldier", "soldiers nutrition", "da soldiers"]),
    "nutrata": ("Nutrata", ["nutrata", "da nutrata"]),
    "bold": ("Bold Snacks", ["bold", "bold snacks", "da bold"]),
    "drpeanut": ("Dr. Peanut", ["dr peanut", "drpeanut", "doctor peanut", "da dr peanut"]),
    "maismu": ("Mais Mu", ["mais mu", "maismu", "mu", "da mais mu"]),
    "yopro": ("YoPRO", ["yopro", "yo pro", "da yopro"]),
    "piracanjuba": ("Piracanjuba Whey", ["piracanjuba", "piracanjuba whey", "piracanjuba proforce", "proforce"]),
    "darkness": ("Darkness", ["darkness", "da darkness", "darkness integralmedica", "darkness integral medica"]),
    "naturovos": ("Naturovos", ["naturovos", "da naturovos"]),
}

# id, marca, nome, nomes do produto, dose (g), scoop (g), por dose: kcal, prot, carbo, gord, açúcar, sódio (mg),
# apelidos que valem sozinhos (sem a marca), se "whey <marca>" escolhe este produto,
# e fibras por dose (opcional para os registros antigos).
# scoop=None: alimento por unidade/porção; scoop=0: pó sem dosador confiável, aceita só dose.
PRODUCTS = [
    # Growth Whey Protein Concentrado 80%, dose 30 g: 122 kcal, 23 g, 4,0 g, 1,6 g, sódio 53 mg.
    # solufition.com.br/whey-protein-concentrada-tabela-nutricional-growth; tabelatacoonline (sabor natural).
    ("growth-whey", "growth", "Whey Protein Concentrado", ["whey", "whey protein", "whey concentrado", "whey protein concentrado", "whey 80", "concentrado"],
     30, 30, 122, 23, 4.0, 1.6, None, 53, [], True),
    # Growth Whey Protein Isolado 90%, dose 30 g: 112 kcal, 26 g, 2 g, 0,3 g, sódio 68 mg.
    # captainsupplements.com.br (rótulo); dicasdetreino.com.br (tabela).
    ("growth-isolado", "growth", "Whey Protein Isolado", ["whey isolado", "whey protein isolado", "isolado", "whey isolate", "whey 90"],
     30, 30, 112, 26, 2.0, 0.3, None, 68, [], False),
    # Growth Basic Whey, dose 30 g: 117 kcal, 10 g, 15 g, 2 g, sódio 101 mg (mercadolivre, rótulo).
    ("growth-basic", "growth", "Basic Whey", ["basic whey", "whey basic"],
     30, 30, 117, 10, 15, 2.0, None, 101, ["basic whey"], False),
    # Max Titanium 100% Whey, dose 30 g (2 dosadores): 121 kcal, 21 g, 4,5 g, 2,1 g (baunilha).
    # paguemenos.com.br e curitibasuplementos.com.br (rótulo).
    ("max-100whey", "maxtitanium", "100% Whey", ["whey", "100 whey", "whey 100", "whey protein"],
     30, 15, 121, 21, 4.5, 2.1, None, 60, [], True),
    # Max Titanium Top Whey 3W Mais Performance, dose 40 g (2 dosadores): 165 kcal, 31 g, 4,5 g, 2,3 g.
    # otimanutri.com.br e materiaprimasuplementos.com.br (rótulo, média dos sabores).
    ("max-topwhey3w", "maxtitanium", "Top Whey 3W", ["top whey", "top whey 3w", "whey 3w", "3w"],
     40, 20, 165, 31, 4.5, 2.3, None, 80, ["top whey", "top whey 3w"], False),
    # Max Titanium Mass Titanium 17500, dose 160 g (5 dosadores): 604 kcal, 17 g, 132 g, 0,9 g, sódio 183 mg.
    # nutrimaxsuplementos.com.br e suplementosblumenau.com.br (rótulo).
    ("max-mass17500", "maxtitanium", "Mass Titanium 17500", ["mass titanium", "mass titanium 17500", "mass 17500", "massa 17500", "hipercalorico", "mass"],
     160, 32, 604, 17, 132, 0.9, None, 183, ["mass titanium", "mass titanium 17500", "mass 17500", "massa 17500"], False),
    # Integralmédica Whey 100% Pure, dose 30 g (2 scoops): 116 kcal, 21 g, 4,6 g, 2,0 g, sódio 60 mg (baunilha).
    # otimanutri.com.br e hubsuplementos.com.br (rótulo).
    ("integral-100pure", "integralmedica", "Whey 100% Pure", ["whey", "whey 100 pure", "whey pure", "100 pure", "whey protein"],
     30, 15, 116, 21, 4.6, 2.0, None, 60, [], True),
    # Probiótica 100% Pure Whey, dose 30 g: 119 kcal, 21 g, 5,1 g, 2,1 g (baunilha).
    # hiperpumpsuplementos.com.br e materiaprimasuplementos.com.br (rótulo).
    ("probiotica-purewhey", "probiotica", "100% Pure Whey", ["whey", "pure whey", "100 pure whey", "whey pure", "whey protein"],
     30, 15, 119, 21, 5.1, 2.1, None, 60, [], True),
    # Dux Whey Protein Concentrado, dose 30 g: 128 kcal, 20 g, 6,7 g, 2,3 g, açúcares 4,9 g, sódio 112 mg.
    # duxhumanhealth.com (site oficial, pote 900 g).
    ("dux-whey", "dux", "Whey Protein Concentrado", ["whey", "whey concentrado", "whey protein concentrado", "whey protein"],
     30, 30, 128, 20, 6.7, 2.3, 4.9, 112, [], True),
    # Black Skull Whey 100% HD, dose 30 g: 125 kcal, 21 g, 5,9 g, 1,9 g, açúcares 5,9 g, sódio 64 mg.
    # materiaprimasuplementos.com.br e supz.com.br (rótulo).
    ("blackskull-100hd", "blackskull", "Whey 100% HD", ["whey", "whey 100 hd", "whey hd", "100 hd", "whey protein"],
     30, 30, 125, 21, 5.9, 1.9, 5.9, 64, [], True),
    # Optimum Nutrition Gold Standard 100% Whey, dose 30,4 g: 120 kcal, 24 g, 3 g, 1 g, sódio 130 mg.
    # otimanutri.com.br e materiaprimasuplementos.com.br (rótulo brasileiro).
    ("optimum-goldstandard", "optimum", "Gold Standard 100% Whey", ["gold standard", "whey gold standard", "whey gold", "gold standard whey", "whey"],
     30.4, 30.4, 120, 24, 3.0, 1.0, None, 130, ["gold standard", "whey gold standard", "gold standard whey"], True),
    # Essential Nutrition Vanilla Whey, dose 25 g: 90 kcal, 22 g, 0,4 g, 0 g, sódio 89 mg (site oficial).
    # https://www.essentialnutrition.com.br/produtos/vanilla-whey-protein-baunilha
    ("essential-vanilla", "essential", "Vanilla Whey", ["vanilla whey", "whey vanilla", "whey baunilha"],
     25, 25, 90, 22, 0.4, 0.0, 0.3, 89, ["vanilla whey"], True),
    # Essential Nutrition Cacao Whey, dose 28 g: 104 kcal, 22 g, 1,9 g, 0,9 g, sódio 89 mg (site oficial).
    # https://www.essentialnutrition.com.br/cacao-whey-protein-chocolate-30-doses
    ("essential-cacao", "essential", "Cacao Whey", ["cacao whey", "whey cacao", "whey cacau"],
     28, 28, 104, 22, 1.9, 0.9, 0.3, 89, ["cacao whey"], False, 1.6),

    # Iso Whey chocolate, 30 g (2 dosadores): 119 kcal, P26 C2,5 G0,6 açúcar0,7 sódio141 mg.
    # https://www.oficialsuplementos.com.br/produto/iso-whey-900g/794
    # https://www.biosuplementosbc.com.br/produto/iso-whey-900g---vencimento-23122026/2476049
    ("max-isowhey", "maxtitanium", "Iso Whey", ["iso whey", "whey isolado", "isolado"],
     30, 15, 119, 26, 2.5, 0.6, 0.7, 141, [], False, 0),
    # Super Gainers, 160 g (6 dosadores): 604 kcal, P16 C131 G1,8 açúcar29 sódio145 mg fibra1.
    # https://www.oficialsuplementos.com.br/produto/super-gainers-3kg/2449739
    # https://www.maximumnutri.com.br/produto/super-gainers-3kg/2449739
    ("max-supergainers", "maxtitanium", "Super Gainers", ["super gainers", "super gainer"],
     160, 160 / 6, 604, 16, 131, 1.8, 29, 145, ["super gainers"], False, 1),
    # Super Whey chocolate, 120 g (5 dosadores): 461 kcal, P30 C78 G3,2 sódio246 mg fibra0,8.
    # https://www.oficialsuplementos.com.br/produto/super-whey-900g---3-unidades/2455337
    # https://www.maximumnutri.com.br/produto/super-whey-900g---3-unidades/2455337
    ("max-superwhey", "maxtitanium", "Super Whey", ["super whey"],
     120, 24, 461, 30, 78, 3.2, None, 246, [], False, 0.8),
    # Femini Whey, 40 g (2 dosadores): 163 kcal, P27 C7,4 G2,8 açúcar6 sódio141 mg.
    # https://www.oficialsuplementos.com.br/produto/femini-whey-900g/2458216
    # https://www.maximumnutri.com.br/produto/femini-whey-900g/2458216
    ("max-femini", "maxtitanium", "Femini Whey", ["femini whey", "whey femini"],
     40, 20, 163, 27, 7.4, 2.8, 6, 141, ["femini whey"], False),
    # Iso Triple Zero chocolate, 30 g (2 dosadores): 111 kcal, P25 C2,7 G0 açúcar0,6 sódio133 mg.
    # https://www.integralmedica.com.br/whey-protein-isolado-900g/p
    ("integral-isotriple", "integralmedica", "Iso Triple Zero", ["iso triple zero", "iso triple", "whey isolado", "isolado"],
     30, 15, 111, 25, 2.7, 0, 0.6, 133, ["iso triple zero"], False, 0),
    # Nutri Whey chocolate, 120 g (2 dosadores): 432 kcal, P30 C73 G2,2 açúcar25 sódio201 mg fibra1,1.
    # https://www.integralmedica.com.br/nutri-whey-protein-900g/p?sabor=Chocolate&tamanho=900g
    # https://loca.integralmedica.com.br/WebTrade/Produtos/FichaTecnica/77278.pdf
    ("integral-nutriwhey", "integralmedica", "Nutri Whey Protein", ["nutri whey", "nutriwhey", "nutri whey protein", "hipercalorico"],
     120, 60, 432, 30, 73, 2.2, 25, 201, ["nutri whey", "nutriwhey", "nutri whey protein"], False, 1.1),
    # Vegan Sport chocolate, 45 g (2 dosadores): 160 kcal, P28 C3,8 G2,6 açúcar1,2 sódio376 mg fibra6,5.
    # https://bhsuplementos.com.br/produtos/vegan-sport-675g-sabor-chocolate-integralmedica/
    # https://graosdopraia.com.br/produtos/im-vegan-sport-sabor-chocolate-675g/
    ("integral-vegan", "integralmedica", "Vegan Sport", ["vegan sport", "proteina vegana", "whey vegano"],
     45, 22.5, 160, 28, 3.8, 2.6, 1.2, 376, ["vegan sport"], False, 6.5),
    # Iso Pro Whey baunilha, 30 g (2 dosadores): 105 kcal, P26 C1,3 G0 sódio151 mg.
    # https://www.maximumnutri.com.br/produto/iso-pro-whey-900g/950172
    # https://www.oficialsuplementos.com.br/produto/iso-pro-whey-900g/2458339
    ("probiotica-isopro", "probiotica", "Iso Pro Whey", ["iso pro whey", "isopro", "iso pro", "whey isolado"],
     30, 15, 105, 26, 1.3, 0, None, 151, ["iso pro whey"], False, 0),
    # 3 Whey Protein, 32 g (2 medidas): 128 kcal, P24 C3,3 G2 sódio70 mg fibra1.
    # https://www.oficialsuplementos.com.br/produto/3-whey-protein-900g/2447704
    # https://www.nutriethos.com.br/produto/3-whey-protein-900g/2447704
    ("probiotica-3whey", "probiotica", "3 Whey Protein", ["3 whey", "3 whey protein", "whey 3w", "3w"],
     32, 16, 128, 24, 3.3, 2, None, 70, [], False, 1),
    # Dux isolado Cookies, 30 g (1 sachê): 115 kcal, P24 C2,8 G0 açúcar0,6 sódio123 mg. Sem peso de scoop confirmado.
    # https://www.gforcesuplementos.com.br/produto/whey-protein-isolado-sache/2467842
    # https://www.c2suplementos.com.br/produto/whey-protein-isolado-display/2467958
    ("dux-isolado", "dux", "Whey Protein Isolado", ["whey isolado", "whey protein isolado", "isolado"],
     30, 0, 115, 24, 2.8, 0, 0.6, 123, [], False),
    # Best Whey original, 35 g (2 dosadores): 134 kcal, P25 C5 G1,6 açúcar0 sódio78 mg.
    # https://www.hdrsuplementos.com.br/produto/best-whey-900g/2458109
    # https://www.vitsuplementos.com.br/produto/best-whey-900g/1410323
    ("atlhetica-bestwhey", "atlhetica", "Best Whey", ["best whey", "whey", "whey protein"],
     35, 17.5, 134, 25, 5, 1.6, 0, 78, ["best whey"], True, 0),
    # Best Whey Iso baunilha, 24 g (1 dosador): 88 kcal, P20 C2 G0 açúcar0 sódio52 mg.
    # https://www.oficialsuplementos.com.br/produto/best-whey-iso-900g/2459299
    # https://www.livewellsuplementos.com.br/produto/best-whey-iso-900g/2459299
    ("atlhetica-bestiso", "atlhetica", "Best Whey Iso", ["best whey iso", "whey isolado", "isolado"],
     24, 24, 88, 20, 2, 0, 0, 52, ["best whey iso"], False, 0),
    # Isofort baunilha, 30 g (2 medidas): 108 kcal, P26 C1 G0 açúcar0 sódio42 mg.
    # https://www.borvitnutrition.com.br/produto/isofort-900g/2461341
    # https://www.nutriethos.com.br/produto/isofort-900g/2461341
    ("vitafor-isofort", "vitafor", "Isofort", ["isofort", "iso fort", "whey", "whey isolado"],
     30, 15, 108, 26, 1, 0, 0, 42, ["isofort", "iso fort"], True, 0),
    # Whey Fort 3W Cookies & Cream, 31 g: 125 kcal, P24 C2,9 G1,9 açúcar2,2 sódio52 mg.
    # https://www.oficialsuplementos.com.br/produto/whey-fort-3w-900g/2457562
    # https://www.fortsup.com.br/produto/whey-fort-3w-900g/2457562
    ("vitafor-wheyfort", "vitafor", "Whey Fort 3W", ["whey fort", "wheyfort", "whey fort 3w", "whey 3w"],
     31, 31, 125, 24, 2.9, 1.9, 2.2, 52, ["whey fort", "wheyfort"], False, 0),
    # Soldiers concentrado Chocolate Belga, 30 g: 112 kcal, P18 C8 G2 açúcar6 sódio93 mg fibra1.
    # https://soldiersnutrition.com.br/products/whey-concentrado-60
    ("soldiers-whey", "soldiers", "Whey Protein Concentrado", ["whey", "whey protein", "whey concentrado", "whey 60"],
     30, 30, 112, 18, 8, 2, 6, 93, [], True, 1),
    # Soldiers Whey Blend chocolate, 30 g: 120 kcal, P20 C8,9 G1 sódio195 mg; açúcar não declarado.
    # https://soldiersnutrition.com.br/products/whey-blend
    ("soldiers-blend", "soldiers", "Whey Protein Blend", ["whey blend", "whey protein blend", "blend"],
     30, 30, 120, 20, 8.9, 1, None, 195, [], False),
    # ISO PRO Chocolate Belga, 30 g (1 dosador): 110 kcal, P27 C2 G0 açúcar0 sódio46 mg fibra1.
    # https://soldiersnutrition.com.br/products/iso-pro-whey
    ("soldiers-isopro", "soldiers", "ISO PRO Whey Isolado", ["iso pro", "iso pro whey", "whey isolado", "isopro"],
     30, 30, 110, 27, 2, 0, 0, 46, [], False, 1),
    # Elite Pro 80% baunilha, 50 g (2 dosadores): 192 kcal, P40 C10 G2 açúcar5 sódio91 mg fibra1.
    # https://soldiersnutrition.com.br/products/whey-80
    ("soldiers-elite", "soldiers", "Elite Pro Whey 80%", ["elite pro", "elite whey", "whey elite", "whey 80", "whey 80%"],
     50, 25, 192, 40, 10, 2, 5, 91, [], False, 1),
    # Barra Soldiers (mesma tabela nos sabores), 40 g: 164 kcal, P12 C16 G7 açúcar4 sódio41 mg fibra1,2.
    # https://soldiersnutrition.com.br/products/barra-de-proteina-40g-caixa-c-12-un-soldiers-nutrition
    ("soldiers-barra", "soldiers", "Barra de Proteína", ["barra", "barrinha", "barra de proteina", "protein bar"],
     40, None, 164, 12, 16, 7, 4, 41, [], False, 1.2),
    # Army Super Mass, 160 g (6 dosadores): 645 kcal, P15 C131 G1 açúcar92 sódio240 mg (todos os sabores).
    # https://soldiersnutrition.com.br/products/hipercalorico-army-super-mass-3kg-soldiers-nutrition
    ("soldiers-armymass", "soldiers", "Army Super Mass", ["army super mass", "army mass", "hipercalorico", "super mass"],
     160, 160 / 6, 645, 15, 131, 1, 92, 240, ["army super mass"], False),
    # Dextrose, 40 g (1 scoop): 148 kcal, P0 C37 G0 açúcar37 sódio0 (não significativo no rótulo).
    # https://soldiersnutrition.com.br/products/dextrose-100-puro-importado-soldiers-nutrition-tamanho-1kg
    ("soldiers-dextrose", "soldiers", "Dextrose", ["dextrose"],
     40, 40, 148, 0, 37, 0, 37, 0, [], False, 0),
    # Isomaltulose, 15 g: 60 kcal, P0 C14 G0 sódio0 (não significativo); açúcar total não declarado.
    # https://soldiersnutrition.com.br/products/isomaltulose-100-puro
    ("soldiers-isomaltulose", "soldiers", "Isomaltulose", ["isomaltulose", "palatinose"],
     15, 0, 60, 0, 14, 0, None, 0, [], False, 0),
    # Maltodextrina, 50 g (1 scoop): 188 kcal, P0 C47 G0 sódio25 mg; açúcar não declarado.
    # https://soldiersnutrition.com.br/products/maltodextrina-100-puro-importado-soldiers-nutrition-tamanho-1kg
    ("soldiers-malto", "soldiers", "Maltodextrina", ["maltodextrina", "malto"],
     50, 50, 188, 0, 47, 0, None, 25, [], False, 0),
    # Waxy Maize, 40 g (1 scoop): 136 kcal, P0 C34 G0 sódio0 (não significativo); açúcar não declarado.
    # https://soldiersnutrition.com.br/products/waxy-maize-100-puro-soldiers-nutrition-tamanho-1kg
    ("soldiers-waxy", "soldiers", "Waxy Maize", ["waxy maize", "waxy"],
     40, 40, 136, 0, 34, 0, None, 0, [], False, 0),
    # Striker (mesma tabela nos sabores), 15 g (3 dosadores): 26 kcal, P0 C6,6 G0 açúcar0,2 sódio12 mg.
    # https://soldiersnutrition.com.br/products/pre-treino-striker-suplemento-alimentar-em-po-cafeina-300g-20-doses-soldiers-nutrition
    ("soldiers-striker", "soldiers", "Striker Pré-treino", ["striker", "pre treino striker", "pre treino"],
     15, 5, 26, 0, 6.6, 0, 0.2, 12, ["striker"], False),
    # Nutrata Iso Whey Creme de Baunilha, 30 g: 115 kcal, P25 C2,5 G0,6 açúcar1 sódio70 mg.
    # https://www.lanutrifit.com.br/produto/iso-whey-900g/2458242
    # https://www.ibalancesuplementos.com.br/produto/iso-whey-900g/2471518
    ("nutrata-isowhey", "nutrata", "Iso Whey", ["iso whey", "whey isolado", "isolado"],
     30, 30, 115, 25, 2.5, 0.6, 1, 70, [], False, 0),
    # Whey Grego brigadeiro, 40 g: 153 kcal, P25 C5,7 G3,3 sódio82 mg. Dosadores divergem (2 ou 3).
    # https://www.casalmonstro.com.br/whey-grego-450g-brigadeiro-nutrata
    # https://www.drogasil.com.br/nutrata-whey-grego-pouch-brigadeiro-900g-959690.html
    ("nutrata-grego", "nutrata", "Whey Grego", ["whey grego", "grego", "whey", "whey protein"],
     40, 0, 153, 25, 5.7, 3.3, None, 82, [], True, 0),
    # BOLD Cookies Black 21g, barra60 g: 235 kcal, P21 C15 G11 açúcar1,8 sódio128 mg fibra4,2.
    # https://www.boldsnacks.com.br/products/bold-cookies-black
    ("bold-barra", "bold", "Barra Cookies Black", ["barra", "bar", "bold bar", "barrinha", "barra de proteina", "cookies black"],
     60, None, 235, 21, 15, 11, 1.8, 128, ["bold bar", "bold"], False, 4.2),
    # BOLD 14g Doce de Leite, barra40 g: 151 kcal, P14 C13 G5,5 açúcar2,5 sódio61 mg fibra2,4.
    # https://www.boldsnacks.com.br/products/bold-doce-de-leite-40g
    ("bold-14g", "bold", "Barra 14g Doce de Leite", ["barra 14g", "bar 14g", "14g", "thin", "barra thin"],
     40, None, 151, 14, 13, 5.5, 2.5, 61, [], False, 2.4),
    # BOLD Crunch Brigadeiro, barra60 g: 215 kcal, P18 C17 G9,8 açúcar2 sódio200 mg fibra5,3.
    # https://www.boldsnacks.com.br/products/bold-crunch-brigadeiro
    ("bold-crunch", "bold", "Crunch Brigadeiro", ["crunch", "barra crunch", "crunch brigadeiro"],
     60, None, 215, 18, 17, 9.8, 2, 200, [], False, 5.3),
    # BOLD Wafer Chocolate ao Leite, 40 g: 194 kcal, P10 C14 G12 açúcar2,1 sódio36 mg fibra2,6.
    # https://www.boldsnacks.com.br/products/bold-wafer-chocolate-ao-leite
    ("bold-wafer", "bold", "Wafer Chocolate ao Leite", ["wafer", "wafer proteico"],
     40, None, 194, 10, 14, 12, 2.1, 36, [], False, 2.6),
    # BOLD Tube Avelã, 40 g: 179 kcal, P10 C11 G12 açúcar1 sódio26 mg fibra2.
    # https://www.boldsnacks.com.br/products/tube-avela-10gproteina
    ("bold-tube", "bold", "Tube Avelã", ["tube", "tube avela"],
     40, None, 179, 10, 11, 12, 1, 26, [], False, 2),
    # BOLD Whey chocolate, 30 g (1 dosador): 118 kcal, P22 C2,7 G2 açúcar2,2 sódio46 mg fibra0,7.
    # https://www.boldsnacks.com.br/products/bold-whey-chocolate-ao-leite-900g
    ("bold-whey", "bold", "Whey 3W", ["whey", "whey protein", "whey 3w"],
     30, 30, 118, 22, 2.7, 2, 2.2, 46, [], True, 0.7),
    # Dr. Peanut Avelã, 15 g (1 colher de sopa): 85 kcal, P2,9 C3,5 G6,9 açúcar1 sódio20 mg fibra1.
    # https://www.curitibasuplementos.com.br/produto/pasta-de-amendoim-400g/2473207
    # https://www.blackcatsuplementos.com.br/produto/pasta-de-amendoim-400g/2473207
    ("drpeanut-pasta", "drpeanut", "Pasta de Amendoim Avelã", ["pasta de amendoim", "pasta", "pasta de amendoim avela"],
     15, None, 85, 2.9, 3.5, 6.9, 1, 20, ["dr peanut", "drpeanut"], False, 1),
    # Mais Mu Whey chocolate, 35 g: 132 kcal, P18 C11 G2 sódio140 mg fibra0,5.
    # https://www.suplementospg.com.br/produto/whey-protein-450g/2459660
    # https://www.cmsuplementos.com.br/produto/whey-protein-450g/2459660
    ("maismu-whey", "maismu", "Whey Protein Concentrado", ["whey", "whey protein", "whey concentrado"],
     35, 35 / 1.5, 132, 18, 11, 2, None, 140, [], True, 0.5),
    # YoPRO UHT chocolate 15g, 250 ml: tabela por100 ml 69 kcal P6 C8,4 G1,1 açúcar7,3 sódio92 mg fibra0,6.
    # https://www.yopro.com.br/produtos/bebida-lactea-uht-15g-de-proteinas/bebida-lactea-proteica-yopro-chocolate/
    ("yopro-uht15", "yopro", "Bebida Láctea 15g Chocolate", ["bebida", "shake", "bebida lactea", "bebida 15g", "shake 15g", "whey"],
     250, None, 172.5, 15, 21, 2.75, 18.25, 230, ["yopro", "yo pro"], False, 1.5),
    # YoPRO UHT chocolate 25g, 250 ml: por100 ml 74 kcal P10 C5,7 G1,1 açúcar5,4 sódio139 mg fibra0,6.
    # https://www.yopro.com.br/produtos/bebida-lactea-uht-25g-de-proteinas/bebida-lactea-proteica-yopro-25g-chocolate/
    ("yopro-uht25", "yopro", "Bebida Láctea 25g Chocolate", ["bebida 25g", "shake 25g", "25g"],
     250, None, 185, 25, 14.25, 2.75, 13.5, 347.5, [], False, 1.5),
    # YoPRO líquido café, 250 g: por100 g 52 kcal P6 C5,2 G0,7 açúcar4,6 sódio58 mg.
    # https://www.yopro.com.br/produtos/iogurte-liquido-15g/iogurte-liquido-yopro-cafe/
    ("yopro-liquido", "yopro", "Iogurte Líquido Café", ["iogurte liquido", "iogurte de cafe"],
     250, None, 130, 15, 13, 1.75, 11.5, 145, [], False, 0),
    # YoPRO colherável morango, 160 g: por100 g 53 kcal P9,5 C3,5 G0 açúcar3,1 sódio28 mg.
    # https://www.yopro.com.br/produtos/iogurte-colheravel/iogurte-proteico-yopro-morango/
    ("yopro-colheravel", "yopro", "Iogurte Morango", ["iogurte", "iogurte proteico", "iogurte morango", "iogurte colheravel"],
     160, None, 84.8, 15.2, 5.6, 0, 4.96, 44.8, [], False, 0),
    # YoPRO Pouch morango, 160 g: por100 g 53 kcal P9,5 C3,5 G0 açúcar3,1 sódio28 mg.
    # https://www.yopro.com.br/produtos/pouch/pouch-15g-morango/
    ("yopro-pouch", "yopro", "Pouch Morango", ["pouch", "pouch morango"],
     160, None, 84.8, 15.2, 5.6, 0, 4.96, 44.8, [], False, 0),
    # Piracanjuba ProForce 23g cacau, 250 ml: 174 kcal P23 C17 G1,2 açúcar17 sódio337 mg fibra3 (p6).
    # https://piracanjuba-whey-prd.s3-sa-east-1.amazonaws.com/text-button-pdf/files/guia-de-produtos-piracanjubaproforce-041-588.pdf
    ("piracanjuba-uht23", "piracanjuba", "Bebida Láctea 23g Cacau", ["whey", "bebida", "shake", "bebida lactea", "23g"],
     250, None, 174, 23, 17, 1.2, 17, 337, ["piracanjuba whey", "piracanjuba proforce"], False, 3),
    # Piracanjuba ProForce 15g chocolate, 250 ml: 155 kcal P15 C20 G1,3 açúcar20 sódio212 mg fibra3 (p9).
    # https://piracanjuba-whey-prd.s3-sa-east-1.amazonaws.com/text-button-pdf/files/guia-de-produtos-piracanjubaproforce-041-588.pdf
    ("piracanjuba-uht15", "piracanjuba", "Bebida Láctea 15g Chocolate", ["bebida 15g", "shake 15g", "15g"],
     250, None, 155, 15, 20, 1.3, 20, 212, [], False, 3),
    # Piracanjuba ProForce pó Milk, 30 g (1 dosador): 118 kcal P21 C2,4 G2 açúcar2,1 sódio61 mg fibra0,2 (p8).
    # https://piracanjuba-whey-prd.s3-sa-east-1.amazonaws.com/text-button-pdf/files/guia-de-produtos-piracanjubaproforce-041-588.pdf
    ("piracanjuba-po", "piracanjuba", "Whey Protein em Pó", ["whey em po", "whey concentrado", "whey protein em po", "po"],
     30, 30, 118, 21, 2.4, 2, 2.1, 61, [], False, 0.2),
    # Nitrohard morango, 40 g (2 dosadores): 163 kcal, P31 C3,3 G2,9 sódio137 mg.
    # https://bhsuplementos.com.br/produtos/nitrohard-darkness-integralmedica-morango-907g/
    # https://www.ironnutritionbrasil.com.br/nitro-hard-18kg-morango
    ("darkness-nitrohard", "darkness", "Nitrohard", ["nitrohard", "nitro hard", "whey", "whey protein"],
     40, 20, 163, 31, 3.3, 2.9, None, 137, ["nitrohard", "nitro hard"], True, 0),
    # Naturovos albumina natural, 28 g (4 colheres): 97 kcal, P22 C2,2 G0,1 açúcar1,5 sódio358 mg.
    # https://www.hubsuplementos.com.br/albumina-420g-naturovos
    # https://www.casaspedro.com.br/albumina-natural--clara-de-ovo--naturovos-420g023193/p
    ("naturovos-albumina", "naturovos", "Albumina Natural", ["albumina", "albumina natural"],
     28, 0, 97, 22, 2.2, 0.1, 1.5, 358, [], False, 0),
    # Doctor Bar Cookies & Cream, barra62 g: 263 kcal, P21 C22 G12 açúcar2,9 sódio117 mg fibra1,2.
    # https://www.gotsuplementos.com.br/produto/doctor-bar-62g/2474473
    # https://www.rinoproject.com.br/produto/doctor-bar-62g---vencimento-01112026/2474786
    ("drpeanut-doctorbar", "drpeanut", "Doctor Bar Cookies & Cream", ["doctor bar", "barra", "barra de proteina", "barrinha"],
     62, None, 263, 21, 22, 12, 2.9, 117, ["doctor bar"], False, 1.2),
    # Essential Açaí Whey, 30 g (2 medidas): 116 kcal, P22 C3 G1,7 açúcar1,4 sódio96 mg fibra1.
    # https://www.essentialnutrition.com.br/acai-whey-protein-acai-com-banana
    ("essential-acai", "essential", "Açaí Whey", ["acai whey", "whey acai"],
     30, 15, 116, 22, 3, 1.7, 1.4, 96, ["acai whey"], False, 1),
    # Essential Cappuccino Whey, 30 g: 104 kcal, P22 C2,9 G0,5 açúcar0,3 sódio93 mg fibra0,7.
    # https://www.essentialnutrition.com.br/cappuccino-whey-protein
    ("essential-cappuccino", "essential", "Cappuccino Whey", ["cappuccino whey", "whey cappuccino"],
     30, 30, 104, 22, 2.9, 0.5, 0.3, 93, ["cappuccino whey"], False, 0.7),
    # Essential Espresso Whey, 30 g: 110 kcal, P22 C4,5 G0,4 açúcar0 sódio86 mg fibra0,7.
    # https://www.essentialnutrition.com.br/espresso-whey-protein-hidrolisado-e-isolado
    ("essential-espresso", "essential", "Espresso Whey", ["espresso whey", "whey espresso", "whey cafe"],
     30, 30, 110, 22, 4.5, 0.4, 0, 86, ["espresso whey"], False, 0.7),
    # Essential Veggie Protein cacau, 35 g: 137 kcal, P22 C2,7 G4,2 açúcar0 sódio293 mg fibra3,5.
    # https://www.essentialnutrition.com.br/veggie-protein-cacao-chocolate
    ("essential-veggie", "essential", "Veggie Protein Cacao", ["veggie protein", "veggie", "proteina vegana", "whey vegano"],
     35, 35, 137, 22, 2.7, 4.2, 0, 293, ["veggie protein"], False, 3.5),
    # Endurance Energy Gel tangerina, sachê30 g: 80 kcal, P0 C20 G0 sódio57 mg; açúcar não declarado.
    # https://www.magnavita.com.br/products/endurance-energy-gel-tangerina-30g-vitafor
    # https://www.emporioaurea.com.br/products/endurance-energy-gel-tangerina-30g-vitafor
    ("vitafor-energygel", "vitafor", "Endurance Energy Gel", ["endurance energy gel", "energy gel", "gel", "gel de carboidrato"],
     30, None, 80, 0, 20, 0, None, 57, ["endurance energy gel"], False),
    # Gold Standard Casein Cookies & Cream, fórmula EUA 33 g (1 scoop): 110 kcal, P24 C3 G0,5 açúcar2 sódio240 mg.
    # https://ca.iherb.com/pr/optimum-nutrition-gold-standard-100-casein-cookies-cream-3-85-lb-1-75-kg/116771
    # https://www.vitacost.com/products/optimum-nutrition-gold-standard-100-casein-cookies-cream-3-85-lb-1-75-kg-116771
    ("optimum-casein", "optimum", "Gold Standard 100% Casein", ["casein", "caseina", "gold standard casein", "gold standard caseina"],
     33, 33, 110, 24, 3, 0.5, 2, 240, ["gold standard casein", "gold standard caseina"], False, 0),
    # Isolate HD (referência morango), 30 g (1 scoop): 123 kcal, P24 C4 G1,2 sódio60 mg; açúcar não declarado.
    # https://www.materiaprimasuplementos.com.br/14577-isolate-hd-900g-morango-p8748
    # https://www.fabricadeatletas.com/isolate-hd-900g-black-skull
    ("blackskull-isolatehd", "blackskull", "Isolate HD", ["isolate hd", "whey isolate hd", "whey isolado", "isolado"],
     30, 30, 123, 24, 4, 1.2, None, 60, [], False, 0),
    # Medium Whey natural, 30 g (2 dosadores): 121 kcal, P17 C8,7 G2 açúcar7,9 sódio76 mg.
    # https://www.gsuplementos.com.br/medium-whey-protein-1kg-growth-supplements-p986001
    ("growth-medium", "growth", "Medium Whey", ["medium whey", "whey medium"],
     30, 15, 121, 17, 8.7, 2, 7.9, 76, ["medium whey"], False, 0),
    # 3 Whey, tabela oficial publicada, 30 g (2,5 dosadores): 118 kcal, P24 C2,5 G1,3 açúcar1,1 sódio46 mg.
    # https://www.gsuplementos.com.br/3-whey-protein-1kg-growth-supplements-p985944
    ("growth-3whey", "growth", "3 Whey Protein", ["3 whey", "3 whey protein", "whey 3w", "3w whey"],
     30, 12, 118, 24, 2.5, 1.3, 1.1, 46, [], False, 0),
    # Hidrolisado natural, 30 g (2 dosadores): 115 kcal, P27 C0,6 G0,5 açúcar0,5 sódio68 mg.
    # https://www.gsuplementos.com.br/whey-protein-hidrolisado-1kg-sabor-natural-growth-supplements-p985872
    ("growth-hidrolisado", "growth", "Whey Protein Hidrolisado", ["whey hidrolisado", "hidrolisado", "whey hydro"],
     30, 15, 115, 27, 0.6, 0.5, 0.5, 68, [], False, 0),
    # Bebida láctea UHT, tabela oficial publicada, 250 ml: 162 kcal, P15 C18 G3 açúcar15 sódio319 mg fibra1,7.
    # https://www.gsuplementos.com.br/bebida-lactea-uht-de-proteinas-growth-supplements
    ("growth-uht", "growth", "Bebida Láctea UHT", ["bebida", "bebida lactea", "whey pronto", "shake"],
     250, None, 162, 15, 18, 3, 15, 319, [], False, 1.7),
    # Haze, tabela oficial publicada, 10 g (1,5 dosadores): 27 kcal, P0 C2,6 G0 açúcar2,6 sódio0 (não significativo).
    # https://www.gsuplementos.com.br/pre-treino-haze-hardcore-300gr-growth-supplements
    ("growth-haze", "growth", "Haze Pré-treino", ["haze", "pre treino haze", "pre treino"],
     10, 10 / 1.5, 27, 0, 2.6, 0, 2.6, 0, ["haze"], False, 0),
    # Albumina, tabela oficial publicada, 30 g (2 dosadores): 104 kcal, P24 C2 G0 açúcar0,2 sódio250 mg.
    # https://www.gsuplementos.com.br/albumina-1kg-growth-supplements-p987913
    ("growth-albumina", "growth", "Albumina", ["albumina"],
     30, 15, 104, 24, 2, 0, 0.2, 250, [], False, 0),
    # Blend Vegan, tabela oficial publicada, 30 g (3 dosadores): 123 kcal, P24 C0,6 G2,6 açúcar0 sódio167 mg fibra0,4.
    # https://www.gsuplementos.com.br/blend-vegan-growth-supplements-p988005
    ("growth-vegan", "growth", "Blend Vegan", ["blend vegan", "blend vegano", "proteina vegana", "whey vegano"],
     30, 10, 123, 24, 0.6, 2.6, 0, 167, [], False, 0.4),
    # Big Mass Pro, tabela oficial publicada, 160 g (9 dosadores): 591 kcal, P22 C100 G5,4 açúcar24 sódio191 mg fibra6,7.
    # https://www.gsuplementos.com.br/big-mass-hipercalorico-3kgs-growth-supplements
    ("growth-bigmass", "growth", "Big Mass Pro", ["big mass", "big mass pro", "hipercalorico"],
     160, 160 / 9, 591, 22, 100, 5.4, 24, 191, ["big mass pro"], False, 6.7),
    # Maltodextrina natural, 50 g (2,5 dosadores): 192 kcal, P0 C48 G0 açúcar3,2 sódio33 mg.
    # https://www.gsuplementos.com.br/maltodextrina-1kg-growth-supplements-p985957
    ("growth-malto", "growth", "Maltodextrina", ["maltodextrina", "malto"],
     50, 20, 192, 0, 48, 0, 3.2, 33, [], False, 0),
    # Pasta integral torrada, 15 g (1 colher de sopa): 89 kcal, P3,7 C1,9 G7,5 açúcar0,7 sódio0,9 mg fibra1,3.
    # https://www.gsuplementos.com.br/pasta-de-amendoim-integral-torrado-1kg-growth-supplements-p988045
    ("growth-pasta", "growth", "Pasta de Amendoim Integral", ["pasta de amendoim", "pasta integral", "pasta de amendoim integral"],
     15, None, 89, 3.7, 1.9, 7.5, 0.7, 0.9, [], False, 1.3),
    # Pasta brigadeiro (linha saborizada), 15 g (1 colher de sopa): 88 kcal, P3,6 C2,1 G7,2 açúcar0,8 sódio1 mg fibra1,4.
    # https://www.gsuplementos.com.br/pasta-de-amendoim-sabor-brigadeiro-500gr-growth-supplements-p988070
    ("growth-pastasabor", "growth", "Pasta de Amendoim Brigadeiro", ["pasta saborizada", "pasta brigadeiro", "pasta de amendoim brigadeiro"],
     15, None, 88, 3.6, 2.1, 7.2, 0.8, 1, [], False, 1.4),
    # Protein Bar Banoffee, barra30 g: 115 kcal, P8,3 C14 G3 açúcar1,5 sódio28 mg fibra2,9.
    # https://www.gsuplementos.com.br/protein-bar-growth-sabor-banoffee-30gr-display-c-12-un-growth-supplements-banoffee
    ("growth-barra", "growth", "Barra Protein Bar Banoffee", ["barra", "barra de proteina", "protein bar", "barrinha"],
     30, None, 115, 8.3, 14, 3, 1.5, 28, [], False, 2.9),
    # Rice Protein natural, 30 g (2 dosadores): 120 kcal, P24 C0,5 G2,4 açúcar0 sódio32 mg.
    # https://www.gsuplementos.com.br/rice-protein-sabor-natural-1kg-growth-supplements-p985886
    ("growth-rice", "growth", "Rice Protein", ["rice protein", "proteina de arroz", "proteina do arroz"],
     30, 15, 120, 24, 0.5, 2.4, 0, 32, [], False, 0),
    # Soy Protein natural, 30 g (2 dosadores): 116 kcal, P26 C1,5 G0,5 açúcar0 sódio330 mg fibra0,9.
    # https://www.gsuplementos.com.br/soy-protein-proteina-isolada-de-soja-1kg-sabor-natural-growth-supplements-p985855
    ("growth-soy", "growth", "Soy Protein", ["soy protein", "proteina de soja", "proteina isolada de soja"],
     30, 15, 116, 26, 1.5, 0.5, 0, 330, [], False, 0.9),
    # Pea Protein natural, 30 g (2 dosadores): 131 kcal, P25 C0,7 G2,9 açúcar0 sódio302 mg fibra0,8.
    # https://www.gsuplementos.com.br/proteina-da-ervilha-pea-protein-1kg-growth-supplements-p985816
    ("growth-pea", "growth", "Pea Protein", ["pea protein", "proteina de ervilha", "proteina da ervilha"],
     30, 15, 131, 25, 0.7, 2.9, 0, 302, [], False, 0.8),
    # Crisp Protein Bar marshmallow, barra40 g: 150 kcal, P11 C16 G4,7 açúcar1,9 sódio49 mg fibra2.
    # https://www.gsuplementos.com.br/crisp-protein-bar-sabor-marshmallow-growth-supplements
    ("growth-crisp", "growth", "Barra Crisp Protein Bar", ["crisp protein bar", "barra crisp", "crisp bar"],
     40, None, 150, 11, 16, 4.7, 1.9, 49, [], False, 2),
    # Radiance Joy chocolate, barra50 g: 196 kcal, P11 C11 G11 açúcar0,6 sódio80 mg fibra11.
    # https://www.essentialnutrition.com.br/radiance-joy-protein-bar-chocolate
    ("essential-radiance", "essential", "Barra Radiance Joy Protein Bar", ["radiance joy", "radiance joy protein bar", "barra", "barra de proteina"],
     50, None, 196, 11, 11, 11, 0.6, 80, ["radiance joy"], False, 11),
    # Best Whey Bar Original, barra30 g: 100 kcal, P10 C6,7 G4,9 açúcar0 sódio23 mg fibra4,4.
    # https://www.evoluaon.com.br/produto/best-whey-bar-30g/2459496
    # https://www.caaspshop.com.br/best-whey-bar-protein-original-30g-6429141/p
    ("atlhetica-barra", "atlhetica", "Barra Best Whey Bar", ["best whey bar", "barra", "barra de proteina", "bar"],
     30, None, 100, 10, 6.7, 4.9, 0, 23, ["best whey bar"], False, 4.4),
    # Best Whey Bar 12g Cioccolato Bianco, barra49 g: 190 kcal, P12 C18 G9,9 açúcar0 sódio60 mg fibra4,9.
    # https://www.materiaprimasuplementos.com.br/15278-best-whey-bar-49g-barra-de-protena-atlhetica-p10795
    # https://www.move.com.br/best-whey-bar-12g-protein-torta-all-cioccolato-bianco-atlhetica-nutrition-12-barras/p
    ("atlhetica-barra12g", "atlhetica", "Barra Best Whey Bar 12g", ["best whey bar 12g", "barra 12g", "best whey bar 49g"],
     49, None, 190, 12, 18, 9.9, 0, 60, [], False, 4.9),
    # Fresh Whey chocolate e avelã, 31 g (1 dosador): 126 kcal, P20 C4,4 G3,2 açúcar3,5 sódio91 mg fibra1.
    # https://www.otimanutri.com.br/fresh-whey-450g-chocolate-e-avela-dux-nutrition-20171
    # https://www.drogaraia.com.br/fresh-whey-protein-sabor-chocolate-e-avela-dux-human-health-450g-1337595.html
    ("dux-fresh", "dux", "Fresh Whey", ["fresh whey", "freshwhey"],
     31, 31, 126, 20, 4.4, 3.2, 3.5, 91, ["fresh whey", "freshwhey"], False, 1),
    # Protein Crisp Brownie de Chocolate, barra45 g: 186 kcal, P13 C18 G8,2 açúcar4,8 sódio69 mg fibra1,5.
    # https://www.otimanutri.com.br/protein-crisp-bar-12-unidades-de-45g-brownie-de-chocolate-integralmedica-33763
    # https://www.corpoevidashop.com.br/produtos/protein-crisp-bar-caixa-c-12-unidades-de-45g-integralmedica/
    ("integral-crisp", "integralmedica", "Barra Protein Crisp Brownie", ["protein crisp", "protein crisp bar", "crisp bar", "barra crisp", "barra", "barra de proteina"],
     45, None, 186, 13, 18, 8.2, 4.8, 69, ["protein crisp", "protein crisp bar"], False, 1.5),
]


def per100(value, dose):
    return round(value * 100 / dose, 2)


def build():
    foods = []
    for product in PRODUCTS:
        (pid, brand, name, names, dose, scoop, kcal, prot, carbs, fat, sugar, sodium, standalone, default) = product[:14]
        fiber = product[14] if len(product) == 15 else 0
        label, brand_words = BRANDS[brand]
        aliases = set(standalone)
        for product in names:
            for word in brand_words:
                aliases.add(f"{product} {word}")
                if not word.startswith("da "):
                    aliases.add(f"{word} {product}")
        # "whey growth" sozinho escolhe o carro-chefe da marca, marcado como palpite.
        vague = [n for n in names if n in ("whey", "whey protein")]
        guesses = sorted({f"{n} {w}" for n in vague for w in brand_words}
                         | {f"{w} {n}" for n in vague for w in brand_words if not w.startswith("da ")}) if default else []
        foods.append({
            "id": pid,
            "name": f"{name} ({label})",
            "category": label,
            "aliases": sorted(aliases),
            "portion": dose,
            "measures": ({"scoop": scoop, "dose": dose} if scoop else {"dose": dose}) if scoop is not None else {},
            "estimated": False,
            "guesses": guesses if default else [],
            "kcal": per100(kcal, dose),
            "protein": per100(prot, dose),
            "fat": per100(fat, dose),
            "carbs": per100(carbs, dose),
            "fiber": per100(fiber, dose),
            "sodium": per100(sodium, dose),
            "sugar": per100(sugar, dose) if sugar is not None else None,
        })
    return foods


def normalize(text):
    text = unicodedata.normalize("NFD", text.lower())
    return " ".join("".join(c for c in text if not unicodedata.combining(c)).split())


def validate(foods):
    """Falha antes de escrever: IDs, nutrientes, apelidos e colisões com a base existente."""
    root = Path(__file__).resolve().parents[1]
    reserved = {}
    for filename in ("taco.json", "ibge.json", "fastfood.json"):
        for food in json.loads((root / "Tobi/Resources" / filename).read_text()):
            for alias in food.get("aliases", []):
                reserved[normalize(alias)] = filename
    # Lista curada é declarativa: todas as strings do bloco incluem os apelidos e os nomes.
    curated = (root / "Tobi/Nutrition/FoodDatabase.swift").read_text().split("static let curated: [Food] = [", 1)[1]
    for alias in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', curated):
        reserved[normalize(alias)] = "FoodDatabase.curated"
    seen = {}
    ids = set()
    for food in foods:
        if food["id"] in ids:
            raise ValueError(f"ID repetido: {food['id']}")
        ids.add(food["id"])
        if food["portion"] <= 0 or food["kcal"] <= 0:
            raise ValueError(f"produto sem dose/calorias: {food['id']}")
        for key in ("protein", "carbs", "fat", "fiber", "sodium", "sugar"):
            if food[key] is not None and food[key] < 0:
                raise ValueError(f"nutriente negativo: {food['id']}/{key}")
        for alias in food["aliases"]:
            if alias != normalize(alias):
                raise ValueError(f"apelido não normalizado: {alias}")
            if alias in seen:
                raise ValueError(f"apelido repetido: {alias} ({seen[alias]} e {food['id']})")
            if alias in reserved:
                raise ValueError(f"apelido reservado: {alias} ({reserved[alias]})")
            seen[alias] = food["id"]
    return len(seen)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "Tobi/Resources/suplementos.json"
    foods = build()
    try:
        alias_count = validate(foods)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    with open(out, "w") as f:
        json.dump(foods, f, ensure_ascii=False, indent=1)
    print(f"{len(foods)} produtos, {alias_count} apelidos -> {out}")
