// resolve-line: recebe uma linha que o Tobi não reconheceu ("?") e uma lista de candidatos
// da base local, e pergunta ao Jev (TypeSafe) se é comida e qual candidato é.
// O Jev só escolhe dentro da lista: nenhum número nutricional sai daqui.

const JEV_URL = "https://api.typesafe.ai/v1/systemone";
const NONE = "nenhum";
const MAX_TEXT = 200;
const MAX_CANDIDATES = 40;
const MAX_NAME = 120;
// Abaixo disso a linha continua "?". Fica aqui pra ajustar sem atualizar o app.
const MIN_FOOD = 0.5;
const MIN_CONFIDENCE = 0.6;
const MIN_MASS = 0.6;
const MIN_VERIFY = 0.6;

type Candidate = { id: string; name: string };

type Answer = {
  isFood: number;
  /** id do candidato escolhido, ou null se não é comida, é "nenhum" ou a confiança é baixa. */
  match: string | null;
  /** Escolha antes da segunda opinião. */
  choice: string | null;
  confidence: number;
  /** Quanto a segunda opinião confirma o candidato escolhido (0 se não houve). */
  verified: number;
  /** As 5 opções mais prováveis (id null = "nenhum"). */
  top: { id: string | null; p: number }[];
};

const STOP = new Set("de da do das dos com e a o as os um uma na no nas nos em pra para ao".split(" "));

function fold(s: string): string {
  return s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9 ]+/g, " ");
}

function stem(t: string): string {
  return t.length > 4 ? t.slice(0, 4) : t;
}

function content(s: string): string[] {
  return fold(s).split(" ").filter((t) => t && !STOP.has(t) && !/^\d+[a-z]{0,2}$/.test(t)).map(stem);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function parse(body: unknown): { text: string; candidates: Candidate[] } | string {
  if (typeof body !== "object" || body === null) return "corpo inválido";
  const { text, candidates } = body as Record<string, unknown>;
  if (typeof text !== "string" || !text.trim()) return "text obrigatório";
  if (text.length > MAX_TEXT) return `text passa de ${MAX_TEXT} caracteres`;
  if (!Array.isArray(candidates) || candidates.length === 0) return "candidates obrigatório";
  if (candidates.length > MAX_CANDIDATES) return `no máximo ${MAX_CANDIDATES} candidates`;
  const clean: Candidate[] = [];
  const seen = new Set<string>();
  for (const c of candidates) {
    const { id, name } = (c ?? {}) as Record<string, unknown>;
    if (typeof id !== "string" || typeof name !== "string" || !id || !name) return "candidate inválido";
    if (name.length > MAX_NAME || id.length > MAX_NAME) return "candidate grande demais";
    if (seen.has(id)) continue;
    seen.add(id);
    clean.push({ id, name });
  }
  return { text: text.trim(), candidates: clean };
}

async function jev(key: string, payload: unknown): Promise<Response> {
  const body = JSON.stringify(payload);
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(JEV_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(8000),
    });
    if ((res.status === 429 || res.status === 529) && attempt === 0) {
      await new Promise((r) => setTimeout(r, 400));
      continue;
    }
    return res;
  }
}

function askItem(key: string, text: string, candidates: Candidate[]): Promise<Response> {
  // As opções vão como "c0", "c1"... pro id da base não influenciar a escolha.
  const criteria: Record<string, string> = {};
  candidates.forEach((c, i) => (criteria[`c${i}`] = c.name));
  criteria[NONE] = "Nenhum alimento da lista corresponde ao que a linha descreve";

  return jev(key, {
    model: "jev-latest",
    state: { linha: text },
    questions: {
      is_food: {
        type: "noul",
        instructions: "A `linha` é uma anotação de algo que a pessoa comeu ou bebeu?",
        criteria: {
          true: "Descreve uma comida, bebida, prato ou ingrediente consumido",
          false: "É outra coisa: tarefa, lembrete, exercício, humor ou texto sem relação com comida",
        },
      },
      item: {
        type: "choice",
        instructions:
          "Qual alimento da lista é exatamente o que a `linha` descreve? Ignore quantidades e medidas. " +
          "Respeite o preparo citado (frito, grelhado, cozido, cru). " +
          "O alimento da lista não pode ter ingrediente a mais nem a menos que a linha: " +
          "'banana com aveia' não é 'vitamina de banana com aveia'. " +
          "Prefira o item genérico e comum do Brasil; marca de rede só se a linha citar a marca. " +
          "Zero, light e diet são a mesma coisa; refri é refrigerante; xis é x- (lanche com hambúrguer). " +
          "Se nenhum for o mesmo alimento, escolha nenhum.",
        criteria,
      },
    },
  });
}

// Segunda opinião: o candidato é mesmo o que a linha diz, sem prato a mais ou a menos?
async function verify(key: string, text: string, name: string): Promise<number> {
  try {
    const res = await jev(key, {
      model: "jev-latest",
      state: { linha: text, alimento: name },
      questions: {
        same: {
          type: "noul",
          instructions:
            "A `linha` e `alimento` são o mesmo prato? Ignore quantidades. " +
            "Preparo padrão do prato (frito, cozido, assado), pontuação, singular ou plural e nome regional não mudam o alimento. " +
            "Zero, light e diet são a mesma coisa. Num nome com 'ou', as duas partes são o mesmo alimento. " +
            "Se a `linha` traz um qualificador que `alimento` não tem (marca, versão diet ou light, 'da vovó', sabor), não são o mesmo. " +
            "Palavras de conversa (comi, tomei, um, uma) e quantidades não contam como qualificador.",
          criteria: {
            true: "Mesmo alimento ou prato, só escrito de outro jeito ou com o preparo padrão",
            false: "Alimento diferente, mais genérico que a linha, prato maior que contém o outro, com ingrediente que a linha não cita, ou sem um qualificador que a linha cita",
          },
        },
      },
    });
    if (!res.ok) return 0;
    return (await res.json()).answers?.same?.noul ?? 0;
  } catch {
    return 0;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "use POST" }, 405);

  // "resolve-line" é o nome com que a chave foi salva no painel.
  const key = Deno.env.get("TYPESAFE_API_KEY") ?? Deno.env.get("resolve-line");
  if (!key) return json({ error: "TYPESAFE_API_KEY não configurada" }, 500);

  let input: unknown;
  try {
    input = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }
  const parsed = parse(input);
  if (typeof parsed === "string") return json({ error: parsed }, 400);
  const { text, candidates } = parsed;

  let res: Response;
  try {
    res = await askItem(key, text, candidates);
  } catch (e) {
    return json({ error: `Jev não respondeu: ${(e as Error).name}` }, 504);
  }
  if (!res.ok) {
    console.error("jev", res.status, await res.text());
    return json({ error: `Jev respondeu ${res.status}` }, 502);
  }

  const data = await res.json();
  const isFood: number = data.answers?.is_food?.noul ?? 0;
  const item = data.answers?.item ?? {};
  const confidence: number = item.confidence ?? 0;
  const probs: Record<string, number> = item.probabilities ?? {};
  const ranked = Object.entries(probs)
    .map(([k, p]) => ({ p, c: k === NONE ? null : candidates[Number(k.slice(1))] ?? null }))
    .sort((a, b) => b.p - a.p);
  const top = ranked.slice(0, 5).map((r) => ({ id: r.c?.id ?? null, p: r.p }));

  // Variações do mesmo prato (frito/cru, TACO/IBGE) dividem a probabilidade entre si.
  // Somo as que contêm todas as palavras da linha e fico com a mais provável.
  const words = content(text);
  const covering = ranked.filter((r) => {
    if (!r.c) return false;
    const name = content(r.c.name);
    return words.every((w) => name.includes(w));
  });
  const mass = covering.reduce((a, r) => a + r.p, 0);
  const lead = ranked[0];
  // Mesmo nome vindo de tabelas diferentes ("Mamão" TACO e IBGE) também divide a probabilidade.
  const sameName = lead?.c
    ? ranked.filter((r) => r.c && fold(r.c.name).trim() === fold(lead.c!.name).trim())
    : [];
  const sameMass = sameName.reduce((a, r) => a + r.p, 0);
  let pick: Candidate | null = null;
  if (lead?.c && (lead.p >= MIN_CONFIDENCE || sameMass >= MIN_MASS)) pick = lead.c;
  else if (covering.length > 0 && mass >= MIN_MASS && mass > (probs[NONE] ?? 0)) pick = covering[0].c;

  let match: string | null = null;
  let verified = 0;
  if (pick && isFood >= MIN_FOOD) {
    verified = await verify(key, text, pick.name);
    if (verified >= MIN_VERIFY) match = pick.id;
  }

  return json({ isFood, match, choice: pick?.id ?? null, confidence, verified, top } satisfies Answer);
});
