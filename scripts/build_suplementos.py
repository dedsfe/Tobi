"""Gera Tobi/Resources/suplementos.json: whey e hipercalórico das marcas que quem treina usa.

Cada número é a tabela nutricional do rótulo (sabor mais vendido), conferida em pelo menos duas
fontes (site da marca ou loja que reproduz o rótulo, mais uma base de rótulos). O rótulo muda um
pouco por sabor e lote: a diferença entre sabores fica em ±5 kcal por dose.

Unidade = 1 dose do rótulo (`portion`, em gramas). "scoop"/"dosador" = 1 medidor do pote.
Valores saem por 100 g, como nas outras tabelas.

Uso: python3 -I scripts/build_suplementos.py Tobi/Resources/suplementos.json
"""
import json
import sys

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
}

# id, marca, nome, nomes do produto, dose (g), scoop (g), por dose: kcal, prot, carbo, gord, açúcar, sódio (mg),
# apelidos que valem sozinhos (sem a marca), e se "whey <marca>" escolhe este produto.
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
    ("essential-vanilla", "essential", "Vanilla Whey", ["vanilla whey", "whey vanilla", "whey baunilha"],
     25, 25, 90, 22, 0.4, 0.0, None, 89, ["vanilla whey"], True),
    # Essential Nutrition Cacao Whey, dose 28 g: 104 kcal, 22 g, 1,9 g, 0,9 g, sódio 89 mg (site oficial).
    ("essential-cacao", "essential", "Cacao Whey", ["cacao whey", "whey cacao", "whey cacau"],
     28, 28, 104, 22, 1.9, 0.9, None, 89, ["cacao whey"], False),
]


def per100(value, dose):
    return round(value * 100 / dose, 2)


def build():
    foods = []
    for (pid, brand, name, names, dose, scoop, kcal, prot, carbs, fat, sugar, sodium, standalone, default) in PRODUCTS:
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
            "measures": {"scoop": scoop, "dose": dose},
            "estimated": False,
            "guesses": guesses if default else [],
            "kcal": per100(kcal, dose),
            "protein": per100(prot, dose),
            "fat": per100(fat, dose),
            "carbs": per100(carbs, dose),
            "fiber": 0.0,
            "sodium": per100(sodium, dose),
            "sugar": per100(sugar, dose) if sugar is not None else None,
        })
    return foods


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "Tobi/Resources/suplementos.json"
    foods = build()
    seen = {}
    for food in foods:
        for alias in food["aliases"]:
            if alias in seen:
                raise SystemExit(f"apelido repetido: {alias} ({seen[alias]} e {food['id']})")
            seen[alias] = food["id"]
    with open(out, "w") as f:
        json.dump(foods, f, ensure_ascii=False, indent=1)
    print(f"{len(foods)} produtos, {len(seen)} apelidos -> {out}")
