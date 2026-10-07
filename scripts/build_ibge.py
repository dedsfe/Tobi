"""Gera Tobi/Resources/ibge.json a partir das tabelas oficiais da POF 2008-2009 do IBGE:
"Tabelas de Composição Nutricional dos Alimentos Consumidos no Brasil" e
"Tabela de Medidas Referidas para os Alimentos Consumidos no Brasil".

São ~1.970 alimentos *do jeito que o brasileiro come* (pão com manteiga, bife acebolado,
coxinha, refrigerante de cola), com açúcar, sódio e medidas caseiras (concha, fatia, unidade).

Uso: uv run --with xlrd python3 -I scripts/build_ibge.py data/ibge Tobi/Resources/ibge.json \
         Tobi/Resources/taco.json
(o taco.json entra pra variedade específica da TACO, tipo "banana da terra", ganhar do
grupo genérico do IBGE "Banana (ouro, prata, da terra...)".)
"""
import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import xlrd

# Preparo da POF → como a pessoa escreve. O primeiro de cada lista vira o nome exibido.
PREPARATIONS = {
    "COZIDO(A)": ["cozido", "cozida"],
    "FRITO(A)": ["frito", "frita"],
    "ASSADO(A)": ["assado", "assada"],
    "REFOGADO(A)": ["refogado", "refogada"],
    "CRU(A)": ["cru", "crua"],
    "ENSOPADO": ["ensopado", "ensopada"],
    "GRELHADO(A)/BRASA/CHURRASCO": ["grelhado", "grelhada", "na brasa", "na chapa", "no churrasco"],
    "MOLHO VERMELHO": ["ao molho", "com molho", "ao molho vermelho", "com molho vermelho", "ao sugo"],
    "EMPANADO(A)/A MILANESA": ["empanado", "empanada", "a milanesa", "milanesa"],
    "AO VINAGRETE": ["ao vinagrete", "vinagrete"],
    "MOLHO BRANCO": ["ao molho branco", "com molho branco"],
    "AO ALHO E OLEO": ["ao alho e oleo", "alho e oleo"],
    "COM MANTEIGA/OLEO": ["com manteiga", "na manteiga", "com oleo"],
}
# Preparos que viram prefixo: "sopa de feijão", "mingau de aveia".
PREFIX_PREPARATIONS = {"SOPA": ["sopa de", "caldo de"], "MINGAU": ["mingau de"]}
# Sem preparo dito ("frango"), qual vale: o mais comum no prato.
PREFERENCE = ["NAO SE APLICA", "COZIDO(A)", "GRELHADO(A)/BRASA/CHURRASCO", "ASSADO(A)",
              "REFOGADO(A)", "CRU(A)", "FRITO(A)", "ENSOPADO"]

# Medida da POF → palavra que o FoodParser reconhece. Em ordem de preferência.
MEASURES = {
    "colher": ["COLHER DE ARROZ/SERVIR", "COLHER DE SOPA"],
    "colher de sopa": ["COLHER DE SOPA"],
    "colher de sobremesa": ["COLHER DE SOBREMESA"],
    "colher de cha": ["COLHER DE CHA"],
    "concha": ["CONCHA"],
    "fatia": ["FATIA"],
    "pedaco": ["PEDACO"],
    "copo": ["COPO MEDIO", "COPO DE REQUEIJAO", "COPO AMERICANO", "COPO GRANDE"],
    "xicara": ["XICARA DE CHA"],
    "lata": ["LATA (350 ML)", "LATA (N. E.)", "LATA (335 ML)", "LATA (250 ML)"],
    "prato": ["PRATO RASO", "PRATO FUNDO"],
    "garrafa": ["GARRAFA (600 ML)", "GARRAFA (500 ML)", "GARRAFA (1 L)"],
    "unidade": ["UNIDADE"],
    "porcao": ["PORCAO"],
    **{word: [word.upper()] for word in [
        "pote", "bola", "tigela", "taca", "punhado", "pacote", "posta", "rodela", "gomo", "barra",
        "dose", "escumadeira", "pegador", "garfada", "cumbuca", "caneca", "pires", "espetinho",
        "espeto", "folha"]},
}

QUALIFIERS = [r"de qualquer (?:sabor|marca|tipo)", r"nao especificad[oa]", r"tradicional",
              r"com ou sem (?:sal|acucar)", r"em pedacos", r"inteir[oa]"]
# Como o nome oficial é chamado na rua.
SYNONYMS = {
    "ovo de galinha": ["ovo"], "pao de sal": ["pao frances", "cacetinho"], "tapioca de goma": ["tapioca"],
    "carne bovina": ["carne"], "galinha": ["frango"], "refrigerante de cola": ["coca", "coca cola"],
    "prato de comida brasileiro": ["prato de comida", "comida caseira"],
}


def normalize(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def code(value):
    return str(int(value)) if isinstance(value, float) else str(value).strip()


def number(value):
    return round(float(value), 2) if isinstance(value, float) else 0.0


def base_aliases(name, specific=frozenset()):
    """'BANANA (OURO, PRATA)' → banana, banana ouro, banana prata.
    'CARNE COM BATATA, INHAME OU AIPIM' → carne com batata, carne com inhame, carne com aipim."""
    parens = re.findall(r"\(([^)]*)\)", name)
    base = normalize(re.sub(r"\([^)]*\)", " ", name))
    for qualifier in QUALIFIERS:
        base = re.sub(rf"\b{qualifier}\b", " ", base)
    base = " ".join(base.split())

    parts = [p.strip() for p in re.split(r",| ou ", base) if p.strip()]
    if len(parts) > 1:
        head = re.match(r"(.* (?:com|de) )", parts[0])
        prefix = head.group(1) if head else ""
        aliases = [parts[0]] + [prefix + p if not p.startswith(prefix) else p for p in parts[1:]]
    else:
        aliases = [base]

    main = aliases[0]
    for group in parens:
        if normalize(group).startswith("exceto"):
            continue
        for piece in re.split(r",| ou |/", group):
            piece = normalize(piece)
            if len(piece) < 3:
                continue
            if f"{main} {piece}" not in specific:
                aliases.append(f"{main} {piece}")
            if " " in piece and piece not in specific:
                aliases.append(piece)
    aliases += [s for a in list(aliases) for s in SYNONYMS.get(a, [])]
    return [a for a in dict.fromkeys(aliases) if a]


def main(src, out, taco=None):
    src = Path(src)
    specific = frozenset(a for f in json.loads(Path(taco).read_text()) for a in f["aliases"]) if taco else frozenset()

    # Nomes bonitos (com acento) e categorias vêm da Tabela 1.
    pretty, categories, category = {}, {}, None
    sheet = xlrd.open_workbook(src / "tab01.xls").sheet_by_index(0)
    for r in range(4, sheet.nrows):
        row = sheet.row_values(r)
        if isinstance(row[0], float):
            key = (code(row[0]), code(row[2]))
            pretty[key] = (row[1].strip(), row[3].strip())
            categories[key] = category
        elif row[0] and not row[1]:
            category = row[0].strip()

    measures = defaultdict(dict)
    standard = {}
    sheet = xlrd.open_workbook(src / "tabelamedidas_bd.xls").sheet_by_index(0)
    for r in range(5, sheet.nrows):
        row = sheet.row_values(r)
        if row[0] == "" or not isinstance(row[8], float):
            continue
        key = (code(row[0]), code(row[2]))
        measures[key][row[5].strip()] = float(row[8])
        standard[key] = row[7].strip()

    sheet = xlrd.open_workbook(src / "tabelacompleta.xls").sheet_by_index(0)
    header = [str(c).strip() for c in sheet.row_values(3)]
    col = {name: header.index(name) for name in header}
    foods = []
    for r in range(4, sheet.nrows):
        row = sheet.row_values(r)
        if not isinstance(row[0], float):
            continue
        key = (code(row[0]), code(row[2]))
        raw_name, prep = row[1].strip(), row[3].strip()
        name, prep_pretty = pretty.get(key, (raw_name.capitalize(), prep.capitalize()))
        display = re.sub(r"\s*\([^)]*\)|\s+n[ãa]o especificad[oa]", "", name).strip()
        if prep in PREPARATIONS:
            display += ", " + prep_pretty.lower()
        elif prep in PREFIX_PREPARATIONS:
            display = f"{PREFIX_PREPARATIONS[prep][0].capitalize()} {display.lower()}"

        food_measures = {}
        for word, kinds in MEASURES.items():
            grams = next((measures[key][k] for k in kinds if k in measures[key]), None)
            if grams:
                food_measures[word] = grams
        portion = measures[key].get(standard.get(key, ""), 100.0)

        def value(column):
            return number(row[col[column]])

        foods.append({
            "id": f"{key[0]}-{key[1]}", "name": display, "category": categories.get(key) or "",
            "portion": portion, "measures": food_measures,
            "kcal": value("ENERGIA (kcal)"), "protein": value("PROTEÍNA (g)"),
            "fat": value("LIPÍDEOS TOTAIS (g)"), "carbs": value("CARBOIDRATO (g)"),
            "fiber": value("FIBRA ALIMENTAR TOTAL (g)"), "sodium": value("SÓDIO (mg)"),
            "sugar": value("AÇÚCAR TOTAL (g)"),
            "_bases": base_aliases(raw_name, specific), "_prep": prep,
        })

    # Apelido sem preparo ("frango") fica com o preparo mais comum; com preparo, é de cada um.
    best = {}
    for food in foods:
        rank = PREFERENCE.index(food["_prep"]) if food["_prep"] in PREFERENCE else len(PREFERENCE)
        is_variant = re.search(r"\b(light|diet|organic[oa])\b", food["_bases"][0]) is not None
        score = (rank, is_variant, len(food["_bases"][0]))
        for alias in food["_bases"]:
            if alias not in best or score < best[alias][0]:
                best[alias] = (score, food)
    for food in foods:
        aliases = [a for a, (_, f) in best.items() if f is food]
        prep = food.pop("_prep")
        for base in food.pop("_bases"):
            aliases += [f"{base} {p}" for p in PREPARATIONS.get(prep, [])]
            aliases += [f"{p} {base}" for p in PREFIX_PREPARATIONS.get(prep, [])]
        food["aliases"] = list(dict.fromkeys(aliases))

    Path(out).write_text(json.dumps(foods, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(foods)} alimentos → {out}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
