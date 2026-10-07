"""Gera Tobi/Resources/fastfood.json a partir das tabelas nutricionais OFICIAIS das redes de
fast food (McDonald's, Burger King, KFC, Subway, Bob's e Habib's), mais o Outback como estimativa.

Os números vêm de data/fastfood/<rede>.json, transcritos das fontes oficiais de cada rede pelo
projeto Refeição Livre (github.com/FernandoGarciaRangel/Refeicao-Livre, commit 50068ff). A
transcrição do Burger King foi conferida contra o PDF oficial (sha256 eff2c526...): bate.

Unidade = 1 sanduíche/porção. Onde a rede publica o peso, os valores viram "por 100 g" com a
porção real; o McDonald's não publica peso, então a porção vira 100 "gramas" simbólicas e os
valores por 100 são os da porção inteira ("2 big mac" = 2 × a tabela).

Bob's e parte do Habib's (beirute, pizza, pratos) só publicam "por 100 g". O peso da unidade
sai do próprio rótulo oficial, que diz que fração da unidade são esses 100 g (data/fastfood/
porcoes.json). O Outback Brasil não publica tabela: entram os valores oficiais do Outback dos
EUA, marcados como estimativa ("estimated": true), porque a porção daqui pode ser outra.
Bebidas ficam de fora (o refrigerante genérico da base já cobre).

Uso: python3 -I scripts/build_fastfood.py data/fastfood Tobi/Resources/fastfood.json \
         Tobi/Resources/taco.json Tobi/Resources/ibge.json Tobi/Nutrition/FoodDatabase.swift
(taco, ibge e a lista curada entram só pra nenhum apelido de rede roubar comida comum.)
"""
import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

CHAINS = {
    "mcdonalds": ("McDonald's", ["do mc", "do mcdonalds", "do mequi", "mcdonalds", "mequi"]),
    "burger-king": ("Burger King", ["do bk", "do burger king", "burger king"]),
    "kfc": ("KFC", ["do kfc", "kfc"]),
    "subway": ("Subway", ["do subway", "subway"]),
    "habibs": ("Habib's", ["do habibs", "do habib", "habibs"]),
    "bobs": ("Bob's", ["do bobs", "do bob s", "bobs", "bob s"]),
    "outback": ("Outback", ["do outback", "outback"]),
}
SKIP_CATEGORIES = {"bebidas"}

# Palavras de cardápio que sozinhas não dizem de qual rede é: um nome feito só delas (e de
# comida comum) não vira apelido solto, só "<nome> do mc", "<nome> do bk"...
GENERIC = {
    "cheeseburger", "hamburger", "hamburguer", "burger", "cappuccino", "capuccino", "espresso",
    "macchiato", "latte", "sundae", "casquinha", "cookie", "croissant", "nugget", "chicken",
    "bacon", "cheddar", "duplo", "triplo", "egg", "cheese", "crispy", "iced", "mix", "shake",
    "milk", "smoothie", "panini", "wrap", "combo", "box", "jr", "deluxe", "onion", "ring",
    "rings", "crocante", "grande", "media", "pequena", "individual", "unidade", "fatia",
    "chipotle", "ranch", "barbecue", "bbq", "teriyaki", "pepperoni", "molho", "chantilly",
    "premium", "curto", "simples", "quente", "gelado", "recheado", "recheada", "soft", "mista",
    "misto", "do", "de", "da", "com", "e", "sabor", "tipo", "zero", "acucar", "light",
}

# Apelido do dia a dia → item da tabela (nome exatamente como na tabela da rede). A maioria
# escolhe um sabor ou tamanho por padrão ("mcflurry" → Ovomaltine, "batata do mc" → média), então
# vira estimativa no app; os de NICKNAMES são só outro nome pro mesmo item e contam como certos.
EXTRA_ALIASES = {
    "mcdonalds": {
        "McFritas Média": ["mcfritas", "batata do mc", "fritas do mc", "batata media do mc",
                           "fritas media do mc", "batata do mequi", "batata do mcdonalds"],
        "McFritas Grande": ["batata grande do mc", "fritas grande do mc", "batata grande do mequi"],
        "Batata P": ["mcfritas pequena", "mcfritas p", "batata pequena do mc",
                     "fritas pequena do mc", "batata pequena do mequi"],
        "McFlurry Ovomaltine Rocks chocolate": ["mcflurry", "mcflurry ovomaltine"],
        "McFlurry M&M's chocolate": ["mcflurry m m", "mcflurry de m m", "mcflurry mms",
                                     "mcflurry de mms"],
        "McShake Ovomaltine": ["mcshake", "shake do mc", "milkshake do mc", "milk shake do mc"],
        "Casquinha Baunilha": ["casquinha do mc", "casquinha do mequi"],
        "Sundae chocolate": ["sundae do mc"],
        "Torta de Maçã": ["torta do mc"],
        "Quarterão com Queijo": ["quarterao"],
    },
    "burger-king": {
        "Batata Frita – média": ["batata do bk", "fritas do bk", "batata media do bk",
                                 "fritas media do bk", "batata do burger king"],
        "Batata Frita – grande": ["batata grande do bk", "fritas grande do bk"],
        "Batata Frita – pequena": ["batata pequena do bk", "fritas pequena do bk"],
        "Onion Rings – média": ["onion rings do bk", "onion do bk", "onion ring do bk"],
        "Sundae de Chocolate": ["sundae do bk"],
        "Casquinha de Baunilha": ["casquinha do bk"],
        "Shake de Chocolate": ["shake do bk", "milkshake do bk", "milk shake do bk"],
    },
    "kfc": {
        "Batata Média": ["batata do kfc", "fritas do kfc", "batata media do kfc"],
        "Batata Grande": ["batata grande do kfc"],
        "Batata Pequena": ["batata pequena do kfc"],
        "Coxa Crocante": ["coxa do kfc"],
        "Asa Crocante": ["asa do kfc", "asinha do kfc"],
        "Sobrecoxa Crocante": ["sobrecoxa do kfc"],
        "Peito Central Crocante": ["peito do kfc"],
        "Tirinha Crocante": ["tirinha do kfc", "tirinhas do kfc"],
        "Casquinha Baunilha": ["casquinha do kfc"],
    },
    "habibs": {
        "Bib'sfiha de Carne": ["esfiha do habibs", "esfirra do habibs", "esfiha de carne do habibs",
                               "esfirra de carne do habibs"],
        "Bib'sfiha de Queijo": ["esfiha de queijo do habibs", "esfirra de queijo do habibs"],
        "Bib'sfiha de Frango": ["esfiha de frango do habibs", "esfirra de frango do habibs"],
        "Kibe": ["kibe do habibs", "quibe do habibs"],
        "Batata Frita (100 g)": ["batata do habibs", "fritas do habibs"],
        "Beirute Tradicional Rosbife": ["beirute", "beirute do habibs", "beirute de rosbife"],
        "Pizza de Mussarela": ["pizza do habibs"],
    },
    "bobs": {
        "Batata Palito": ["batata do bobs", "fritas do bobs", "batata do bob s", "fritas do bob s"],
        "Milk Shake Chocolate": ["milk shake do bobs", "milkshake do bobs", "shake do bobs",
                                 "milk shake do bob s", "milkshake do bob s", "shake do bob s"],
        "Casquinha Baunilha": ["casquinha do bobs", "casquinha do bob s"],
        "Sundae Chocolate": ["sundae do bobs", "sundae do bob s"],
    },
    "outback": {
        "Bloomin' Onion": ["blooming onion", "cebola do outback", "cebola australiana", "bloomin"],
        "Aussie Cheese Fries": ["cheese fries do outback", "cheese fries"],
        "Aussie Fries": ["batata do outback", "fritas do outback"],
        "Kookaburra Wings": ["kookaburra", "asinha do outback", "asa do outback"],
        "Coconut Shrimp": ["camarao do outback"],
        "Pão Australiano com manteiga": ["pao australiano", "pao do outback"],
        "Ribs on the Barbie": ["ribs", "costela do outback", "ribs do outback", "costelinha do outback"],
        "Grilled Chicken on the Barbie": ["frango do outback"],
        "Victoria's Filet Mignon": ["file mignon do outback", "filet mignon do outback"],
        "Chocolate Thunder from Down Under": ["chocolate thunder", "thunder"],
    },
}

NICKNAMES = {
    "mcfritas", "quarterao", "blooming onion", "cebola do outback", "cebola australiana", "bloomin",
    "kookaburra", "camarao do outback", "pao australiano", "pao do outback", "chocolate thunder",
    "thunder", "cheese fries do outback", "cheese fries", "frango do outback",
    "file mignon do outback", "filet mignon do outback", "bibsfiha", "esfiha do habibs",
    "esfirra do habibs", "esfiha de carne do habibs", "esfirra de carne do habibs",
    "esfiha de queijo do habibs", "esfirra de queijo do habibs", "esfiha de frango do habibs",
    "esfirra de frango do habibs", "kibe do habibs", "quibe do habibs", "mcflurry m m",
    "mcflurry de m m", "mcflurry mms", "mcflurry de mms", "onion rings do bk", "onion ring do bk",
    "coxa do kfc", "asa do kfc", "asinha do kfc", "sobrecoxa do kfc", "tirinha do kfc",
    "tirinhas do kfc", "beirute de rosbife", "asinha do outback", "asa do outback",
}

# Apelido que já diz o tamanho ("batata grande do mc") não é chute.
SIZES = {"p", "pequena", "media", "grande", "individual"}

# Itens que a pessoa conta por unidade, tirados de uma caixa da tabela: "10 mcnuggets".
PER_UNIT = {
    "mcdonalds": [("Chicken McNuggets 6 unidades", 6, "Chicken McNugget",
                   ["mcnugget", "chicken mcnugget", "nugget do mc", "nugget do mequi"])],
    "burger-king": [("BK® Chicken – 6 unidades", 6, "BK Chicken (nugget)",
                     ["bk chicken", "nugget do bk", "chicken do bk"])],
}


def normalize(text):
    """Igual ao FoodParser.normalize + clean: minúsculas, sem acento, só letras e números."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9./]+", " ", text).strip()


def singularize(word):
    """Mesmas regras do FoodParser.singularize."""
    if len(word) <= 3:
        return word
    for suffix, replacement in [("oes", "ao"), ("aes", "ao"), ("eis", "el"), ("ais", "al"),
                                ("res", "r"), ("ns", "m")]:
        if word.endswith(suffix):
            return word[: -len(suffix)] + replacement
    if word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


def tokens(text):
    return tuple(singularize(word) for word in normalize(text).split())


def spellings(name):
    """Jeitos de escrever o nome: "Bib'sfiha" vira "bibsfiha" e "bib sfiha";
    "McFritas" vira "mcfritas" e "mc fritas"."""
    name = re.sub(r"\(\s*\d[^)]*\)|[®™]", " ", name)
    variants = {normalize(name.replace("'", "")), normalize(name)}
    for variant in list(variants):
        split = re.sub(r"\bmc(?=[a-z]{3,})", "mc ", variant)
        variants.add(split)
    return {v for v in variants if v}


def number(value):
    return float(value or 0)


def grams(portion):
    match = re.match(r"\s*(\d+(?:[.,]\d+)?)\s*(g|ml)\b", portion or "")
    return float(match.group(1).replace(",", ".")) if match else None


def base_vocabulary(taco, ibge, curated):
    aliases = set()
    for path in (taco, ibge):
        for food in json.loads(Path(path).read_text()):
            aliases.update(tokens(alias) for alias in food["aliases"])
    source = Path(curated).read_text()
    for group in re.findall(r'Food\("[^"]+",\s*\[([^\]]*)\]', source):
        aliases.update(tokens(alias) for alias in re.findall(r'"([^"]+)"', group))
    words = {word for alias in aliases for word in alias}
    return aliases, words


def main(src, out, taco, ibge, curated):
    base_aliases, base_words = base_vocabulary(taco, ibge, curated)
    units = json.loads((Path(src) / "porcoes.json").read_text())
    brand_words = lambda alias: [w for w in alias if w not in base_words and w not in GENERIC
                                 and not w.replace(".", "").isdigit()]

    foods = []
    for slug, (chain, tags) in CHAINS.items():
        data = json.loads((Path(src) / f"{slug}.json").read_text())
        estimated = data.get("estimado", False)
        chain_units = units.get(slug, {})
        items = {item["nome"]: item for category in data["categorias"]
                 if category["slug"] not in SKIP_CATEGORIES for item in category["itens"]}
        extras = EXTRA_ALIASES.get(slug, {})
        missing = set(extras) - set(items)
        if missing:
            sys.exit(f"{slug}: apelidos pra itens que não existem: {missing}")

        def add(name, item, divide=1, extra=()):
            weight = grams(item.get("porcao"))
            if item.get("kcal") is None:
                return
            measures = {}
            # Tabela só "por 100 g": o peso da unidade vem do rótulo (porcoes.json); sem ele, fica de fora.
            per100_only = slug == "bobs" or (slug == "habibs" and weight == 100 and "(100 g)" not in name)
            if per100_only:
                unit = chain_units.get(name)
                if not unit:
                    return
                portion, factor = unit["grams"] / divide, 1
                if unit["unit"] != "unidade":
                    measures[unit["unit"]] = unit["grams"]
            else:
                portion = (weight or 100) / divide
                factor = 100 / weight if weight else 1
            names = spellings(name)
            aliases = [f"{n} {tag}" for n in names for tag in tags]
            aliases += [n for n in names if brand_words(tokens(n))]
            aliases += list(extra) + extras.get(name, [])
            guesses = [normalize(a) for a in extras.get(name, [])
                       if normalize(a) not in NICKNAMES and not SIZES & set(normalize(a).split())]
            foods.append({
                "id": f"{slug}-{len(foods)}",
                "name": f"{re.sub(r'[®™]', '', name).replace('WHOPPER', 'Whopper').strip()} ({chain})",
                "category": chain,
                "aliases": aliases,
                "portion": round(portion, 2),
                "measures": measures,
                "estimated": estimated,
                "guesses": guesses,
                "kcal": round(number(item["kcal"]) * factor, 2),
                "protein": round(number(item.get("prot")) * factor, 2),
                "fat": round(number(item.get("gord")) * factor, 2),
                "carbs": round(number(item.get("carb")) * factor, 2),
                "fiber": round(number(item.get("fibra")) * factor, 2),
                "sodium": round(number(item.get("sodio")) * factor, 2),
                "sugar": None if item.get("acucar") is None else round(number(item["acucar"]) * factor, 2),
            })

        for name, item in items.items():
            add(name, item)
        for source, count, name, aliases in PER_UNIT.get(slug, []):
            add(name, items[source], divide=count, extra=aliases)

    # Apelido que já é comida comum, ou que duas redes disputam, não fica com ninguém.
    owners = defaultdict(set)
    for food in foods:
        for alias in food["aliases"]:
            owners[tokens(alias)].add(food["category"])
    dropped = 0
    for food in foods:
        seen, kept = set(), []
        for alias in food["aliases"]:
            key = tokens(alias)
            if not key or key in seen or key in base_aliases or len(owners[key]) > 1:
                dropped += key not in seen
                continue
            seen.add(key)
            kept.append(normalize(alias))
        food["aliases"] = kept
        food["guesses"] = [alias for alias in food["guesses"] if alias in kept]

    Path(out).write_text(json.dumps(foods, ensure_ascii=False, separators=(",", ":")))
    by_chain = defaultdict(int)
    for food in foods:
        by_chain[food["category"]] += 1
    print(f"{len(foods)} itens → {out} ({dict(by_chain)}); {dropped} apelidos descartados por conflito")


if __name__ == "__main__":
    main(*sys.argv[1:6])
