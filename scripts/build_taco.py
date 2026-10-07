"""Gera Tobi/Resources/taco.json a partir dos CSVs da TACO 4ª ed. (NEPA/Unicamp).

Fonte dos CSVs: github.com/raulfdm/taco-api (references/csv).
Uso: python3 -I scripts/build_taco.py data/taco Tobi/Resources/taco.json

Cada alimento ganha apelidos pra busca ("Arroz, tipo 1, cozido" → "arroz", "arroz tipo 1 cozido").
Quando vários disputam o mesmo apelido, fica o preparo mais comum no prato: carne e grão
cozidos/grelhados, fruta e verdura cruas.
"""
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path

PORTION_BY_CATEGORY = {  # gramas de uma porção típica quando a pessoa não diz quanto
    "Cereais e derivados": 100, "Verduras, hortaliças e derivados": 80, "Frutas e derivados": 120,
    "Gorduras e óleos": 10, "Pescados e frutos do mar": 120, "Carnes e derivados": 120,
    "Leite e derivados": 150, "Bebidas (alcoólicas e não alcoólicas)": 250, "Ovos e derivados": 50,
    "Produtos açucarados": 30, "Miscelâneas": 30, "Outros alimentos industrializados": 50,
    "Alimentos preparados": 200, "Leguminosas e derivados": 140, "Nozes e sementes": 30,
}
COOKED_FIRST = {"Cereais e derivados", "Pescados e frutos do mar", "Carnes e derivados",
                "Ovos e derivados", "Leguminosas e derivados"}
RAW_FIRST = {"Frutas e derivados", "Verduras, hortaliças e derivados"}


def normalize(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def number(value):
    value = (value or "").strip()
    try:
        return float(value)
    except ValueError:  # "", "NA", "Tr" (traço) → 0
        return 0.0


def score(name, category):
    n = normalize(name)
    s = -0.5 * name.count(",")
    cooked = re.search(r"\b(cozid|grelhad|assad|frit)", n)
    raw = re.search(r"\b(cru|crua)\b", n)
    if category in COOKED_FIRST:
        s += 3 if cooked else 0
        s -= 3 if raw else 0
    if category in RAW_FIRST:
        s += 3 if raw else 0
    if re.search(r"\b(po|desidratad|concentrad|industrializad|calda|farinha|mistura)", n):
        s -= 2
    return s


def main(src, out):
    src = Path(src)
    categories = {r["id"]: r["name"] for r in csv.DictReader(open(src / "categories.csv"))}
    nutrients = {r["foodId"]: r for r in csv.DictReader(open(src / "nutrients.csv"))}

    foods = []
    for row in csv.DictReader(open(src / "food.csv")):
        n = nutrients[row["id"]]
        if not n["kcal"].strip():
            continue  # TACO sem energia analisada: fica de fora
        name = " ".join(row["name"].split())
        category = categories[row["categoryId"]]
        foods.append({
            "id": row["id"], "name": name, "category": category,
            "portion": PORTION_BY_CATEGORY[category], "measures": {},
            "kcal": number(n["kcal"]), "protein": number(n["protein"]), "fat": number(n["lipids"]),
            "carbs": number(n["carbohydrates"]), "fiber": number(n["dietaryFiber"]),
            "sodium": number(n["sodium"]),
            "_score": score(name, category),
        })

    # Apelidos por prefixo do nome: "Ovo, de codorna, inteiro, cru" → "ovo", "ovo de codorna",
    # "ovo de codorna inteiro". Cada apelido fica com o melhor candidato; nome inteiro é sempre de cada um.
    best = {}
    for food in foods:
        parts = [p for p in food["name"].split(",") if p.strip()]
        for end in range(1, len(parts)):
            alias = normalize(",".join(parts[:end]))
            if alias not in best or food["_score"] > best[alias]["_score"]:
                best[alias] = food
    for food in foods:
        full = normalize(food["name"])
        food["aliases"] = [full] + [a for a, f in best.items() if f is food and a != full]
        del food["_score"]

    Path(out).write_text(json.dumps(foods, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(foods)} alimentos → {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
