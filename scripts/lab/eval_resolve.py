#!/usr/bin/env python3
"""Mede a resolve-line: frases brasileiras -> candidatos da base -> Jev. Roda em paralelo.
Uso: python3 scripts/lab/eval_resolve.py [-v]"""
import json, re, sys, unicodedata, urllib.request, concurrent.futures as cf, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://wluqzlfkclrjocdjlmeu.supabase.co/functions/v1/resolve-line"
KEY = "sb_publishable_cryhZudzqSF0tlHwCTKQAg_v0OXxHic"

def fold(s):
    s = unicodedata.normalize("NFD", s.lower())
    return re.sub(r"[^a-z0-9 ]+", " ", "".join(c for c in s if unicodedata.category(c) != "Mn"))

STOP = set("de da do das dos com e a o as os um uma na no nas nos em pra para ao".split())
def toks(s): return [t for t in fold(s).split() if t not in STOP]

foods = []
for src in ("taco", "ibge", "fastfood"):
    for x in json.load(open(ROOT / f"Tobi/Resources/{src}.json")):
        foods.append({"id": f"{src}:{x['id']}", "name": x["name"], "src": src,
                      "aliases": x.get("aliases", []),
                      "t": set(toks(x["name"] + " " + " ".join(x.get("aliases", []))))})

# A lista curada do app (FoodDatabase.swift) também entra, como entra no app.
for m in re.finditer(r'Food\("([^"]+)",\s*\[([^\]]*)\]', (ROOT / "Tobi/Nutrition/FoodDatabase.swift").read_text()):
    name, al = m.group(1), re.findall(r'"([^"]+)"', m.group(2))
    foods.append({"id": f"curated:{len(foods)}", "name": name, "src": "curated", "aliases": al,
                  "t": set(toks(name + " " + " ".join(al)))})

def stem(t): return t[:4] if len(t) > 4 else t

BRANDS = {"mc","mcdonalds","mequi","bk","burger","king","kfc","subway","bobs","habibs","outback"}

def brand_ok(f, qset):
    if f["src"] != "fastfood": return True
    return bool(qset & BRANDS) or any(set(toks(a)) <= qset for a in f["aliases"])

def candidates(text, k=30):
    q = toks(text)
    qset = set(q)
    qs = {stem(t) for t in q}
    scored = []
    for f in foods:
        fs = {stem(t) for t in f["t"]}
        hit = len(qs & fs)
        if hit and brand_ok(f, qset):
            scored.append((hit / (len(qs) ** 0.5 * len(fs) ** 0.5), f))
    scored.sort(key=lambda p: -p[0])
    return [f for _, f in scored[:k]]

# (frase, regex do nome aceito | None = deve dizer nenhum/não-comida)
CASES = [
 ("pão na chapa", r"^Pão com manteiga"),
 ("pão com manteiga", r"^Pão com manteiga"),
 ("pãozinho com ovo", r"^Pão com ovo"),
 ("tapioquinha com queijo", None),
 ("tapioca com manteiga", r"^Tapioca, com manteiga"),
 ("cuscuz com ovo", None),
 ("café com leite", r"café.*leite|leite.*café"),
 ("suquinho de laranja", r"suco.*laranja|laranja.*suco"),
 ("coca zero", r"refrigerante.*(cola|zero|diet)|coca"),
 ("guaraná", r"guaran"),
 ("cerveja", r"cerveja"),
 ("açaí", r"a[cç]a[ií]"),
 ("coxinha", r"coxinha"),
 ("pastel de queijo", r"pastel.*queijo"),
 ("pastel de carne", r"pastel.*carne"),
 ("misto quente", r"misto|queijo.*presunto|presunto.*queijo"),
 ("pão de queijo", r"^Pão de queijo"),
 ("brigadeiro", r"brigadeiro"),
 ("bolo de cenoura", r"bolo.*cenoura"),
 ("vitamina de banana", r"vitamina.*banana"),
 ("iogurte natural", r"iogurte.*natural|iogurte, natural"),
 ("pizza de calabresa", r"calabr"),
 ("feijoada", r"feijoada"),
 ("strogonoff de frango", r"strogon.*frango|frango.*strogon"),
 ("farofa", r"farofa"),
 ("macarrão ao molho", r"macarr[aã]o.*molho"),
 ("bife acebolado", r"bife.*cebola|bife acebolado"),
 ("frango grelhado", r"frango.*grelh"),
 ("ovo mexido", r"ovo.*mexid"),
 ("ovo frito", r"ovo.*frito"),
 ("banana com aveia", None),
 ("whey protein", r"whey"),
 ("sushi", r"sushi"),
 ("hot roll", r"hot roll"),
 ("x-bacon", r"bacon"),
 ("xis salada", r"salada|x-salada"),
 ("academia 18h", "NONFOOD"),
 ("reunião com o cliente", "NONFOOD"),
 ("comprar leite", "NONFOOD"),
 ("pagar a conta de luz", "NONFOOD"),
 ("dormi 6 horas", "NONFOOD"),
 ("bebi 2 litros de água", r"^Água$"),
 ("agua", r"^[áa]gua$"),
 ("arroz e feijão", r"arroz.*feij"),
 ("pão francês", r"^Pão, trigo, francês|^Pão francês"),
 ("pão de forma", r"p[ãa]o.*forma"),
 ("queijo minas", r"queijo.*minas"),
 ("presunto", r"presunto"),
 ("mamão com granola", None),
 ("salada de frutas", r"salada.*fruta"),
 ("sopa de legumes", r"legum"),
 ("empadinha de frango", r"empad.*frango"),
 ("esfiha de carne", r"esf[ih]r{0,2}a.*carne"),
 ("kibe", r"kibe|quibe"),
 ("leite com chocolate", r"chocolat|chocomilk"),
 ("danone", None),
 ("miojo", r"macarr[aã]o.*instant|miojo"),
 ("batata frita", r"batata.*frit"),
 ("bolacha recheada", r"biscoito.*recheado|bolacha.*recheada"),
 ("chocolate ao leite", r"chocolate.*leite|chocolate, ao leite"),
 ("picanha", r"picanha"),
 ("linguiça", r"lingui[cç]a"),
 # holdout: frases que não usei pra ajustar nada
 ("pão com ovo", r"^Pão com ovo"),
 ("suco de uva", r"suco.*uva|uva.*suco"),
 ("sorvete de creme", r"sorvete.*creme"),
 ("mandioca frita", r"mandioca.*frit|aipim.*frit"),
 ("peito de frango", r"peito.*frango|frango.*peito"),
 ("carne moída", r"carne.*mo[ií]da"),
 ("salada de alface e tomate", None),
 ("lasanha", r"lasanha"),
 ("nhoque", r"nhoque"),
 ("paçoca", r"pa[cç]oca"),
 ("pipoca", r"pipoca"),
 ("cheeseburger", r"cheese|hamb"),
 ("big mac", r"big mac"),
 ("whopper", r"whopper"),
 ("treino de perna", "NONFOOD"),
 ("ligar pro médico", "NONFOOD"),
 ("tô com dor de cabeça", "NONFOOD"),
 ("uma maçã", r"ma[cç][aã]"),
 ("melancia", r"melancia"),
 ("castanha de caju", r"castanha.*caju"),
 ("amendoim", r"amendoim"),
 ("pão com queijo", None),
 ("omelete", r"omelete"),
 ("tapioca", r"tapioca"),
 ("moqueca de peixe", r"moqueca"),
 ("acarajé", r"acaraj"),
 ("tacacá", r"tacac"),
]

GIRIAS = json.load(open(ROOT / "data/girias.json"))

def apply_girias(text):
    t = fold(text).strip()
    for g in sorted(GIRIAS, key=lambda g: -len(g["quando"])):
        w = fold(g["quando"]).strip()
        t2 = re.sub(rf"\b{re.escape(w)}\b", g["vira"], t)
        if t2 != t: return t2
    return text

def call(text, cands):
    body = json.dumps({"text": text, "candidates": [{"id": c["id"], "name": c["name"]} for c in cands]}).encode()
    req = urllib.request.Request(URL, body, {"Content-Type": "application/json", "apikey": KEY})
    for _ in range(3):
        try: return json.load(urllib.request.urlopen(req, timeout=20))
        except Exception as e: err = str(e)
    return {"error": err}

def run(case):
    text, want = case
    shown = text
    text = apply_girias(text)
    cands = candidates(text)
    r = call(text, cands) if cands else {"isFood": None, "match": None, "choice": None, "confidence": 0}
    names = {c["id"]: c["name"] for c in cands}
    got = names.get(r.get("match"))
    if "error" in r: verdict = "ERRO"
    elif want == "NONFOOD": verdict = "ok" if got is None else f"FALHA(achou {got})"
    elif want is None:
        verdict = "ok" if got is None else f"ERRADO({got})"
    else:
        # existe no banco algo que aceite?
        if got is None:
            avail = any(re.search(want, f["name"], re.I) for f in foods)
            in_c = any(re.search(want, c["name"], re.I) for c in cands)
            verdict = "perdeu(banco tem, candidato " + ("tinha" if in_c else "NÃO tinha") + ")" if avail else "ok(nenhum)"
        else:
            verdict = "ok" if re.search(want, got, re.I) else f"ERRADO({got})"
    return shown, verdict, r, len(cands)

if __name__ == "__main__":
    if "--hard" in sys.argv:
        from hard_cases import HARD
        CASES = HARD
    with cf.ThreadPoolExecutor(6) as ex: out = list(ex.map(run, CASES))
    bad = 0
    for text, v, r, n in out:
        flag = v.startswith("ok")
        bad += not flag
        if "-v" in sys.argv or not flag:
            names = {c['id']: c['name'] for c in candidates(apply_girias(text))}
            tp = ' | '.join(f"{(names.get(t['id']) or 'NENHUM')[:28]}={t['p']:.2f}" for t in (r.get('top') or [])[:3])
            print(f"{'✓' if flag else '✗'} {text:24} {v:48} conf={r.get('confidence')} ver={r.get('verified')} {tp}")
    wrong = sum(1 for _, v, *_ in out if v.startswith(("ERRADO", "FALHA")))
    print(f"\n{len(out)-bad}/{len(out)} ok | errados (pior caso): {wrong} | perdeu: {sum(1 for _,v,*_ in out if v.startswith('perdeu'))}")
